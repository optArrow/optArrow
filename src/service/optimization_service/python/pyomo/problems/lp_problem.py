import logging
from pyomo.environ import *
import numpy as np
from pyomo.opt import SolverStatus, TerminationCondition
import pyarrow.compute as pc
import os
from collections import defaultdict
from utils.pyomo_utils import *
from service.optimization_service.python.pyomo.objects.base_problem import BaseProblem

logger = logging.getLogger("lp_problem")
class LPProblem(BaseProblem):
    def __init__(self, model=None):
        super().__init__(model)
        A = self.model_params["A"]
        b = self.model_params["b"]
        c = self.model_params["c"]
        lb = self.model_params["lb"]
        ub = self.model_params["ub"]
        osense = self.model_params["osense"]
        csense = self.model_params["csense"]
        sparse_dict_add_shape(A)
        self.S = A
        self.n_row, self.n_col = A["shape"]

        self.b = np.array(b)
        self.c = np.array(c)
        self.lb = np.array(lb)
        self.ub = np.array(ub)
        if osense == 'max' or osense == -1:
            self.osense = 1
        else:
            self.osense = -1
        self.csense = np.array(csense)
        self.model = None
        self.solution = None
        self.objective_value = None
        self.status = None

    def build(self, solver: SolverConfig):
        model = ConcreteModel()
                
        n = self.c.shape[0]
        m = self.b.shape[0]
        model.I = RangeSet(0, n - 1)
        model.J = RangeSet(0, m - 1)

        logger.info("Setting x:")
        model.x = Var(range(self.n_col), domain=Reals)

        # Bounds
        for i in list(model.I):
            model.x[i].setlb(self.lb[i])
            model.x[i].setub(self.ub[i])

        logger.info("Setting objectives:")
        # Objective
        model.obj = Objective(expr=sum(self.c[i] * model.x[i] for i in list(model.I)), sense=minimize if self.osense == -1 else maximize)

        # S is now always dense 2D array
        # Setting constraints
        logger.info("Setting constraints:")
        i = 0
        j = 0
        model.constraints = ConstraintList()
        # Build sparse row structrure: {row_idx: [(col_idx, val), ...]}
        row_exprs = defaultdict(list)
        for r, c, v in zip(self.S["row"], self.S["col"], self.S["val"]):
            row_exprs[r].append((c, v))
        
        for j in range(self.n_row):
            entries = row_exprs[j]
            if not entries:
                # Some imported benchmark models contain redundant zero rows
                # such as 0 <= 0 after presolved slack handling. Skip those
                # tautologies, but surface contradictory empty rows.
                if self.csense[j] in ['L', '<'] and self.b[j] >= 0:
                    continue
                if self.csense[j] in ['G', '>'] and self.b[j] <= 0:
                    continue
                if self.csense[j] in ['E', '='] and self.b[j] == 0:
                    continue
                raise ValueError(f"Empty constraint row {j} is not satisfiable: sense={self.csense[j]}, rhs={self.b[j]}")

            expr = sum(coeff * model.x[i] for i, coeff in entries)
            if self.csense[j] in ['E', '=']:
                model.constraints.add(expr == self.b[j])
            elif self.csense[j] in ['L', '<']:
                model.constraints.add(expr <= self.b[j])
            elif self.csense[j] in ['G', '>']:
                model.constraints.add(expr >= self.b[j])
            else:
                raise ValueError(f"Invalid constraint sense: {self.csense[j]}")
        # Write to file for debugging purpose
        # model.write("pyomo_model.lp", io_options={
        #     'symbolic_solver_labels': True,
        #     'file_deterministic': True
        #     }
        # )
        self.model = model
        self.solver = solver

    def solve(self, solver_params={}, timeout=300):
        logger.info(f"Timeout: {timeout}")
        # Add /usr/local/lib to LD_LIBRARY_PATH, for ipopt
        os.environ["LD_LIBRARY_PATH"] = "/usr/local/lib:" + os.environ.get("LD_LIBRARY_PATH", "")
        if self.model is None or self.solver is None:
            raise RuntimeError("Model not built or solver not assigned.")
        opt = SolverFactory(self.solver.name.lower())
        time_limit = timeout
        if solver_params is not None and solver_params != {}:
            for item in solver_params:
                opt.options[item] = solver_params[item]
        try:
            result = opt.solve(self.model, tee=True, timelimit=time_limit)

            if result.solver.status == SolverStatus.ok:
                logger.info("Solved.")
                self.solution = [value(self.model.x[i]) for i in self.model.I]
                self.objective_value = value(self.model.obj)
                self.status = str(result.solver.termination_condition)
            else:
                self.solution = "Solve did not complete successfully."
                self.objective_value = None
                self.solution = None
                self.status = str(result.solver.termination_condition)
        except Exception as e:
            self.solution = "Solver error"
            self.objective_value = None
            self.solution = None
            self.status = str(e)
