import logging
from pyomo.environ import *
import numpy as np
import scipy.sparse as spa
from pyomo.opt import SolverStatus, TerminationCondition
import pyarrow.compute as pc
import highspy
import os
import gc
import time
from utils.pyomo_utils import *
from service.optimization_service.python.pyomo.objects.base_problem import BaseProblem
import shutil
from collections import defaultdict

highs_param_map = {
    -1: "off",
    0: "choose",
    1: "on"
}

logger = logging.getLogger("qp_problem")
class QPProblem(BaseProblem):
    def __init__(self, model=None):
        super().__init__(model)
        A = self.model_params.get("A", None)
        G = self.model_params.get("G", None)
        Q = self.model_params.get("Q", None)
        b = self.model_params.get("b", None)
        c = self.model_params.get("c", None)
        h = self.model_params.get("h", None)
        lb = self.model_params.get("lb", None)
        ub = self.model_params.get("ub", None)
        osense = self.model_params["osense"]
        self.A = {"row":[], "col":[], "val":[]}
        self.G = {"row":[], "col":[], "val":[]}
        self.Q = {"row":[], "col":[], "val":[]}
        # add shape
        if A is not None and isinstance(A, dict) and all(k in A for k in ("row", "col", "val")):
            self.A = sparse_dict_add_shape(A)
        else:
            self.A = sparse_dict_add_shape(self.A)
        if G is not None and isinstance(G, dict) and all(k in G for k in ("row", "col", "val")):
            self.G = sparse_dict_add_shape(G)
        else:
            self.G = sparse_dict_add_shape(self.G)
        if Q is not None and isinstance(Q, dict) and all(k in Q for k in ("row", "col", "val")):
            self.Q = sparse_dict_add_shape(Q)
        else:
            self.Q = sparse_dict_add_shape(self.Q)
        self.b = np.array(b)
        self.c = np.array(c)
        self.h = np.array(h)
        self.lb = np.array(lb)
        self.ub = np.array(ub)
        self.n = None
        self.meq = None
        self.mieq = None
        if self.c is not None:
            self.n = self.c.shape[0]
        if self.A is not None:
            self.meq = self.A["shape"][0]
        if self.G is not None:
            self.mieq = self.G["shape"][0]
        if osense == 'max' or osense == -1:
            self.osense = 1
        else:
            self.osense = -1
        self.model = None
        self.solution = None
        self.objective_value = None
        self.status = None

    def build(self, solver: SolverConfig):
        model = ConcreteModel()
                
        n = self.c.shape[0]
        model.I = RangeSet(0, n - 1)

        logger.info("Setting x:")
        model.x = Var(model.I, within=Reals)

        # Bounds
        for i in model.I:
            model.x[i].setlb(self.lb[i] if self.lb is not None else None)
            model.x[i].setub(self.ub[i] if self.ub is not None else None)

        logger.info("Setting objectives:")
        # Objective
    
        qsym = defaultdict(float)
        for r, c, v in zip(self.Q["row"], self.Q["col"], self.Q["val"]):
            if r <= c:
                qsym[(r, c)] += v
            else:
                qsym[(c, r)] += v
                
        # Sparse to row based dicts
        def rows_from_triplet(T):
            m = T['shape'][0]
            rows = [list() for _ in range(m)]
            for r, c, v in zip(T['row'], T['col'], T['val']):
                rows[r].append((c, v))
            return rows
        
        Arows = rows_from_triplet(self.A) if self.A and len(self.A['row']) else []
        Grows = rows_from_triplet(self.G) if self.G and len(self.G['row']) else []
            
        quad_expr = sum(v * model.x[i] * model.x[j] for (i, j), v in qsym.items())
        lin_expr = sum(self.c[j] * model.x[j] for j in range(n))
        
        
        model.obj = Objective(expr=0.5 * quad_expr + lin_expr,
                            sense=minimize if self.osense == -1 else maximize)

        # S is now always dense 2D array
        # Setting constraints
        logger.info("Setting constraints:")
        # Ax = b
        if Arows:
            model.eq = ConstraintList()
            for i, terms in enumerate(Arows):
                expr = sum(v * model.x[j] for j, v in terms)
                model.eq.add(expr == self.b[i])

        # Gx <= h
        if Grows:
            model.ineq = ConstraintList()
            for i, terms in enumerate(Grows):
                expr = sum(v * model.x[j] for j, v in terms)
                model.ineq.add(expr <= self.h[i])
                
        self.model = model
        self.solver = solver

    def solve(self, solver_params={}, timeout=300):
        logger.info(f"Timeout: {timeout}")
        # Add /usr/local/lib to LD_LIBRARY_PATH, for ipopt
        os.environ["LD_LIBRARY_PATH"] = "/usr/local/lib:" + os.environ.get("LD_LIBRARY_PATH", "")
        if self.model is None or self.solver is None:
            raise RuntimeError("Model not built or solver not assigned.")
        time_limit = timeout
        if "highs" in self.solver.name.lower(): 
            try:
                self._solve_with_highspy(solver_params, time_limit)
            except Exception as e:
                raise RuntimeError("HiGHS solve failed via highspy backend.") from e
        else:
            opt = SolverFactory(self.solver.name.lower())
            if solver_params is not None and solver_params != {}:
                for item in solver_params:
                    opt.options[item] = solver_params[item]
            result = opt.solve(self.model, tee=True, timelimit=time_limit)

        if "highs" in self.solver.name.lower(): 
            return
        else:
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

    def _solve_with_highspy(self, solver_params=None, timeout=300):
        solver_params = solver_params or {}
        highs = highspy.Highs()
        highs.setOptionValue("output_flag", False)
        highs.setOptionValue("time_limit", float(timeout))

        for key, value in solver_params.items():
            mapped = highs_param_map.get(value, value)
            try:
                highs.setOptionValue(key, mapped)
            except Exception:
                logger.warning("Ignoring unsupported HiGHS parameter %s=%s", key, value)

        model = highspy.HighsModel()
        model.lp_ = self._build_highs_lp()
        model.hessian_ = self._build_highs_hessian()

        status = highs.passModel(model)
        if status != highspy.HighsStatus.kOk:
            raise RuntimeError(f"Failed to pass QP model to highspy: {status}")

        status = highs.run()
        if status != highspy.HighsStatus.kOk:
            raise RuntimeError(f"highspy run failed: {status}")

        self.status = highs.modelStatusToString(highs.getModelStatus()).lower()
        if self.status == "optimal":
            solution = highs.getSolution().col_value
            self.solution = list(solution)
            self.objective_value = float(highs.getObjectiveValue())
        else:
            self.solution = None
            self.objective_value = None

    def _build_highs_lp(self):
        rows = []
        cols = []
        vals = []
        row_lower = []
        row_upper = []

        if self.A is not None and len(self.A["row"]):
            rows.extend(int(r) for r in self.A["row"])
            cols.extend(int(c) for c in self.A["col"])
            vals.extend(float(v) for v in self.A["val"])
            row_lower.extend(float(v) for v in self.b.tolist())
            row_upper.extend(float(v) for v in self.b.tolist())

        if self.G is not None and len(self.G["row"]):
            offset = len(row_lower)
            rows.extend(offset + int(r) for r in self.G["row"])
            cols.extend(int(c) for c in self.G["col"])
            vals.extend(float(v) for v in self.G["val"])
            row_lower.extend([-highspy.kHighsInf] * len(self.h))
            row_upper.extend(float(v) for v in self.h.tolist())

        n_row = len(row_lower)
        A_csc = spa.coo_matrix((vals, (rows, cols)), shape=(n_row, self.n)).tocsc()

        lp = highspy.HighsLp()
        lp.num_col_ = int(self.n)
        lp.num_row_ = int(n_row)
        lp.col_cost_ = np.array(self.c if self.osense == -1 else -self.c, dtype=np.float64)
        lp.col_lower_ = np.array(self.lb, dtype=np.float64)
        lp.col_upper_ = np.array(self.ub, dtype=np.float64)
        lp.row_lower_ = np.array(row_lower, dtype=np.float64)
        lp.row_upper_ = np.array(row_upper, dtype=np.float64)
        lp.offset_ = 0.0
        lp.sense_ = highspy.ObjSense.kMinimize
        lp.a_matrix_.format_ = highspy.MatrixFormat.kColwise
        lp.a_matrix_.num_col_ = int(self.n)
        lp.a_matrix_.num_row_ = int(n_row)
        lp.a_matrix_.start_ = A_csc.indptr.astype(np.int32)
        lp.a_matrix_.index_ = A_csc.indices.astype(np.int32)
        lp.a_matrix_.value_ = A_csc.data.astype(np.float64)
        return lp

    def _build_highs_hessian(self):
        entries = defaultdict(float)
        for r, c, v in zip(self.Q["row"], self.Q["col"], self.Q["val"]):
            row = int(r)
            col = int(c)
            value = float(v if self.osense == -1 else -v)
            if row >= col:
                entries[(row, col)] += value
            else:
                entries[(col, row)] += value

        if entries:
            h_rows = []
            h_cols = []
            h_vals = []
            for (row, col), value in sorted(entries.items(), key=lambda item: (item[0][1], item[0][0])):
                h_rows.append(row)
                h_cols.append(col)
                h_vals.append(value)
            H_csc = spa.coo_matrix((h_vals, (h_rows, h_cols)), shape=(self.n, self.n)).tocsc()
        else:
            H_csc = spa.csc_matrix((self.n, self.n), dtype=np.float64)

        hessian = highspy.HighsHessian()
        hessian.dim_ = int(self.n)
        hessian.format_ = highspy.HessianFormat.kTriangular
        hessian.start_ = H_csc.indptr.astype(np.int32)
        hessian.index_ = H_csc.indices.astype(np.int32)
        hessian.value_ = H_csc.data.astype(np.float64)
        return hessian
