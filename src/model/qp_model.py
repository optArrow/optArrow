"""
QPModel: Quadratic Programming Model Representation using PyArrow
"""

import logging
import pyarrow as pa
from model.base_model import ArrowModel
from utils.model_sanity_check import check_arrow_coo_matrix, check_variable_bounds, check_objective_sense


logger = logging.getLogger("QPModel")
class QPModel(ArrowModel):
    """
    QPModel: Quadratic Programming Model Representation using PyArrow

    Standard QP form:
        minimize     1/2 xᵀ Q x + cᵀ x
        subject to   A x = b            (equality constraints)
                    G x <= h           (inequality constraints)
                    lb <= x <= ub      (bounds)

    Components:
        - Q: Quadratic coefficient matrix (symmetric, sparse COO format)
        - c: Linear coefficient vector
        - A, b: Equality constraint matrix and RHS (optional)
        - G, h: Inequality constraint matrix and RHS (optional)
        - lb, ub: Variable bounds (optional)
        - osense: Objective sense, e.g., "min" or "max" (optional, defaults to "min")

    All components are stored using PyArrow for efficient in-memory processing
    and IPC serialization.
    """

    def __init__(self, model_dict: dict):
        """
        Initialize QP model.


        Args:
            model_dict: Dict including model info. Parameters listed as below.
                Required:
                    - Q (RecordBatch): Sparse quadratic coefficient matrix in COO format with "row", "col", "val"
                    - c (Array): Linear coefficients
                Optional:
                    - A (RecordBatch): Sparse equality constraint matrix in COO format with "row", "col", "val"
                    - b (Array): Right-hand side vector for equality constraints
                    - G (RecordBatch): Sparse inequality constraint matrix in COO format with "row", "col", "val"
                    - h (Array): Right-hand side vector for inequality constraints
                    - lb (Array): Lower bounds for variables (default: None, treated as unbounded)
                    - ub (Array): Upper bounds for variables (default: None, treated as unbounded)
                    - osense (Scalar): "min" or "max" (default: "min")
        """
        Q = pa.RecordBatch.from_pydict(model_dict.get("Q"))
        c = model_dict.get("c")
        A = pa.RecordBatch.from_pydict(model_dict.get("A")) if model_dict.get("A", None) is not None else None
        b = model_dict.get("b", None)
        G = pa.RecordBatch.from_pydict(model_dict.get("G")) if model_dict.get("G", None) is not None else None
        h = model_dict.get("h", None)
        lb = model_dict["lb"] if model_dict.get("lb") is not None else [-float("inf")] * len(c)
        ub = model_dict["ub"] if model_dict.get("ub") is not None else [float("inf")] * len(c)
        raw_osense = model_dict.get("osense", "min")
        if isinstance(raw_osense, (int, float)):
            raw_osense = "max" if raw_osense == -1 else "min"
        osense = pa.scalar(str(raw_osense).lower(), type=pa.string())

        mats = [("Q", Q)]
        if A is not None:
            mats.append(("A", A))
        if G is not None:
            mats.append(("G", G))
        for name, mat in mats:
            if not isinstance(mat, pa.RecordBatch):
                raise TypeError(f"{name} must be a pyarrow.RecordBatch")
            if not all(col in mat.schema.names for col in ["row", "col", "val"]):
                raise ValueError(f"{name} must contain columns 'row', 'col', 'val'")

        self.Q = Q
        self.c = c
        self.A = A
        self.b = b
        self.G = G
        self.h = h
        self.lb = lb
        self.ub = ub
        self.osense = osense if osense is not None else pa.scalar("min", type=pa.string())
        logger.info("Initialized QPModel with components:")

    def sanity_check(self):
        """
        Sanity checks for QP model consistency.

        - Q matrix should not reference out-of-bound variables
        - A, G matrices' row/col should be in valid range
        - Vector dimensions must match (c, b, h, lb, ub)
        - osense must be "min" or "max"
        """
        n_vars = len(self.c)
        n_eqs = len(self.b) if self.b is not None else 0
        n_ineqs = len(self.h) if self.h is not None else 0

        check_arrow_coo_matrix("Q", self.Q, n_vars, n_vars)
        if self.A is not None:
            check_arrow_coo_matrix("A", self.A, n_eqs, n_vars)
        if self.G is not None:
            check_arrow_coo_matrix("G", self.G, n_ineqs, n_vars)       

        # Bounds
        check_variable_bounds(self.lb, self.ub, n_vars)

        # osense
        check_objective_sense(self.osense)
