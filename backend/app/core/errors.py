"""Consistent JSON error shape for every 4xx/5xx response.

Every error the API returns looks like:

    { "error": { "code": "not_found", "message": "...", "details": null } }

so the Flutter side (or any client) can branch on `error.code` without
string-matching `error.message`.
"""
import logging
from typing import Any, Optional

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from starlette.exceptions import HTTPException as StarletteHTTPException

logger = logging.getLogger("memorymitra")


class ErrorDetail(BaseModel):
    code: str
    message: str
    details: Optional[Any] = None


class ErrorResponse(BaseModel):
    error: ErrorDetail


class ApiError(Exception):
    """Raise this from services/repositories for a typed, coded error.

    Routers don't need to know HTTP status codes — `code` maps to one in
    `_STATUS_BY_CODE`, defaulting to 400 for anything unrecognised.
    """

    def __init__(self, code: str, message: str, *, details: Any = None, status_code: Optional[int] = None):
        super().__init__(message)
        self.code = code
        self.message = message
        self.details = details
        self.status_code = status_code


_STATUS_BY_CODE = {
    "not_found": status.HTTP_404_NOT_FOUND,
    "already_exists": status.HTTP_409_CONFLICT,
    "unauthorized": status.HTTP_401_UNAUTHORIZED,
    "forbidden": status.HTTP_403_FORBIDDEN,
    "not_implemented": status.HTTP_501_NOT_IMPLEMENTED,
    "validation_error": status.HTTP_422_UNPROCESSABLE_CONTENT,
}


def _error_response(status_code: int, code: str, message: str, details: Any = None) -> JSONResponse:
    body = ErrorResponse(error=ErrorDetail(code=code, message=message, details=details))
    return JSONResponse(status_code=status_code, content=body.model_dump(mode="json"))


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(ApiError)
    async def api_error_handler(request: Request, exc: ApiError) -> JSONResponse:
        status_code = exc.status_code or _STATUS_BY_CODE.get(exc.code, status.HTTP_400_BAD_REQUEST)
        return _error_response(status_code, exc.code, exc.message, exc.details)

    @app.exception_handler(StarletteHTTPException)
    async def http_exception_handler(request: Request, exc: StarletteHTTPException) -> JSONResponse:
        return _error_response(exc.status_code, "http_error", str(exc.detail))

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
        return _error_response(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            "validation_error",
            "Request failed validation.",
            details=exc.errors(),
        )

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
        logger.exception("Unhandled error on %s %s", request.method, request.url.path)
        return _error_response(
            status.HTTP_500_INTERNAL_SERVER_ERROR,
            "internal_error",
            "Something went wrong. Please try again.",
        )
