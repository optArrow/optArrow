"""
This module implements a Pyomo-based solver for LP and QP optimization problems.
"""
from service.optimization_service.python.pyomo.objects.problem_factory import ProblemFactory
from service.optimization_service.python.pyomo.problems.qp_problem import create_solver_config, QPProblem
from service.optimization_service.python.pyomo.objects.solver import BaseSolver
import time
class PyomoSolver(BaseSolver):
    """Solver for LP and QP optimization problems using Pyomo."""
    def __init__(self):
        super().__init__()


    def run(self, params:dict) -> dict:
        # Convert the data into an model acceptable format
        self.model = {}
        for k, v in params.items():
            self.model[k] = v
        # Send the data to model
        # Get results, using custom solver
        model_conf = dict(self.model.get("solver"))

        # Adapt to new solver names
        if model_conf.get("solver_name").lower() == "gurobi_persistent" or model_conf.get("solver_name").lower() == "gurobi":
            model_conf["solver_name"] = "gurobi_persistent_v2"
        if model_conf.get("solver_name").lower() == "gurobi_direct":
            model_conf["solver_name"] = "gurobi_direct_v2"

        solver_params = {}
        if "solver_params" in model_conf:
            solver_params = model_conf["solver_params"]
        solver = create_solver_config(model_conf.get("solver_name") or "glpk")
        problem_factory = ProblemFactory(model_conf["solver_type"], self.model)
        problem = problem_factory.problem
        timeout = 300
        if "time_limit" in self.model:
            timeout = self.model["time_limit"]
        if problem:
            try:
                time_start = time.time()
                problem.build(solver)
                problem.solve(solver_params, timeout)
                time_end = time.time()
                status_str = (problem.status or "").lower()
                if "optimal" in status_str:
                    stat = 1
                elif "infeasible" in status_str:
                    stat = 0
                elif "unbounded" in status_str:
                    stat = 2
                else:
                    stat = -1
                return {
                    "success": True,
                    "solution": problem.solution,
                    "status": status_str,
                    "stat": stat,
                    "obj_val": problem.objective_value,
                    # "run_time": time_end - time_start # Benchmark only
                }
            except Exception as e:
                return {
                    "success": False,
                    "error_message": str(e)
                }
        return {
                    "success": False,
                    "error_message": "Failed to set problem and determine solver."
                }
        
