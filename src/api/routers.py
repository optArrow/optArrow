"""
FastAPI RESTful API for OptArrow
This module defines the FastAPI application and its endpoints for handling computation requests.
"""
import logging
import time
import pyarrow as pa
from fastapi import Request
from fastapi import FastAPI, status
from fastapi.responses import Response, JSONResponse
from fastapi.encoders import jsonable_encoder
from api.controllers import Controller
from api.flat_arrow_schema import decode_request, encode_response, encode_error
from utils.api_utils import write_table_to_ipc_bytes

app = FastAPI()
controller = Controller()
logger = logging.getLogger("optarrow.api")

@app.post("/computeJSON")
async def compute_json(request: Request) -> Response:
    """Execute computation using a model and data, entry and return in JSON format.

    Args:
        request (Request): request object with model info.

    Returns:
        Response: response object with results and/or messages.
    """
    try:
        raw = await request.json()
        success, return_data = _compute_json_payload(raw)
        if success:
            return JSONResponse(
                content = jsonable_encoder(return_data),
                status_code = status.HTTP_200_OK,
                media_type= "application/json"
            )
        logger.error(
            "computeJSON failed: %s",
            return_data.get("error_message", return_data)
            if isinstance(return_data, dict)
            else return_data,
        )
        return JSONResponse(
            content = jsonable_encoder(return_data),
            status_code = status.HTTP_500_INTERNAL_SERVER_ERROR,
            media_type= "application/json"
        )
    except Exception as e:
        logger.exception("computeJSON request failed before compute")
        return JSONResponse(
            content = jsonable_encoder({
                "error_message": f"{type(e).__name__}: {str(e)}"
            }),
            status_code = status.HTTP_400_BAD_REQUEST,
            media_type= "application/json"
        )

def _compute_json_payload(raw: dict) -> tuple[bool, dict]:
    """Compute a JSON payload without the gateway-to-gRPC Arrow Flight hop."""
    if str(raw.get("engine", "")).lower() == "python":
        from service.optimization_service.python.pyomo.service.opt_solver import PyomoSolver

        params = dict(raw.get("model") or {})
        params["solver"] = raw.get("solver")
        if raw.get("time_limit") is not None:
            params["time_limit"] = raw.get("time_limit")
        result = PyomoSolver().run(params)
        return bool(result.get("success")), result

    return controller.compute_dict(payload=raw)

@app.post("/cobra/compute")
async def cobra_compute(request: Request) -> Response:
    """Solve a COBRA optimization problem via the flat Arrow IPC protocol.

    Accepts an Arrow IPC stream with the flat COBRA request schema (see
    cobra_arrow_schema.py) and returns an Arrow IPC stream with the flat
    response schema. No nested structs, no JSON — pure Arrow on both sides.
    """
    t0 = time.perf_counter()
    try:
        raw = await request.body()
        reader = pa.ipc.open_stream(raw)
        table = reader.read_all()

        payload = decode_request(table)
        success, result_dict = controller.compute_dict(payload)
        elapsed = time.perf_counter() - t0

        result_dict["time"] = elapsed
        response_table = encode_response(result_dict, elapsed=elapsed)
        ipc_bytes = write_table_to_ipc_bytes(response_table)

        http_status = status.HTTP_200_OK if success else status.HTTP_500_INTERNAL_SERVER_ERROR
        return Response(
            content=ipc_bytes,
            status_code=http_status,
            media_type="application/vnd.apache.arrow.stream",
        )
    except (ValueError, KeyError) as e:
        error_table = encode_error(f"{type(e).__name__}: {e}")
        return Response(
            content=write_table_to_ipc_bytes(error_table),
            status_code=status.HTTP_400_BAD_REQUEST,
            media_type="application/vnd.apache.arrow.stream",
        )
    except Exception as e:
        error_table = encode_error(f"{type(e).__name__}: {e}")
        return Response(
            content=write_table_to_ipc_bytes(error_table),
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            media_type="application/vnd.apache.arrow.stream",
        )


@app.post("/compute")
async def compute(request: Request) -> Response:
    """Execute computation using a model and data.

    Args:
        request (Request): request object with model info.

    Returns:
        Response: response object with results and/or messages.
    """
    try:
        raw = await request.body()
        reader = pa.ipc.open_stream(raw)
        table = reader.read_all()
        success, result = controller.compute(payload=table)
        ipc_bytes = write_table_to_ipc_bytes(result)
        if success:
            return Response(
                content = ipc_bytes,
                status_code = status.HTTP_200_OK,
                media_type= "application/vnd.apache.arrow.stream"
            )
        return Response(
            content = ipc_bytes,
            status_code = status.HTTP_500_INTERNAL_SERVER_ERROR,
            media_type= "application/vnd.apache.arrow.stream"
        )
    except (ValueError, KeyError) as e:
        response = pa.RecordBatch.from_pydict({
                "error_message": [f"{type(e).__name__}: {str(e)}"]
            })
        ipc_bytes = write_table_to_ipc_bytes(response)
        return Response(
            content = ipc_bytes,
            status_code = status.HTTP_400_BAD_REQUEST,
            media_type= "application/vnd.apache.arrow.stream"
        )
