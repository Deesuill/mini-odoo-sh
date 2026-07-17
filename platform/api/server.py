#!/usr/bin/env python3

import json
import os
import re
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlparse


MINI_ODOO_HOME = Path(
    os.environ.get("MINI_ODOO_HOME", "/opt/mini-odoo-sh")
)

MINI_ODOO_CLI = Path(
    os.environ.get(
        "MINI_ODOO_CLI",
        str(MINI_ODOO_HOME / "platform" / "mini-odoo"),
    )
)

REGISTRY_FILE = Path(
    os.environ.get(
        "MINI_ODOO_REGISTRY",
        str(MINI_ODOO_HOME / "instances.json"),
    )
)

WEB_ROOT = Path(
    os.environ.get(
        "MINI_ODOO_WEB_ROOT",
        str(MINI_ODOO_HOME / "platform" / "web"),
    )
).resolve()

API_HOST = os.environ.get("MINI_ODOO_API_HOST", "127.0.0.1")
API_PORT = int(os.environ.get("MINI_ODOO_API_PORT", "8088"))
CLI_TIMEOUT_SECONDS = int(
    os.environ.get("MINI_ODOO_CLI_TIMEOUT", "15")
)

INSTANCE_NAME_PATTERN = re.compile(
    r"^[A-Za-z0-9][A-Za-z0-9._-]*$"
)


class ApiError(Exception):
    def __init__(
        self,
        status_code: int,
        message: str,
        details: str | None = None,
    ) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.message = message
        self.details = details


def load_registry() -> dict[str, Any]:
    if not REGISTRY_FILE.is_file():
        raise ApiError(
            500,
            "Registry file does not exist.",
            str(REGISTRY_FILE),
        )

    try:
        with REGISTRY_FILE.open("r", encoding="utf-8") as file:
            registry = json.load(file)
    except json.JSONDecodeError as error:
        raise ApiError(
            500,
            "Registry contains invalid JSON.",
            str(error),
        ) from error
    except OSError as error:
        raise ApiError(
            500,
            "Registry could not be read.",
            str(error),
        ) from error

    if not isinstance(registry, dict):
        raise ApiError(
            500,
            "Registry root must be a JSON object.",
        )

    return registry


def validate_instance_name(instance_name: str) -> None:
    if not INSTANCE_NAME_PATTERN.fullmatch(instance_name):
        raise ApiError(
            400,
            "Invalid instance name.",
        )


def run_instance_info(instance_name: str) -> dict[str, Any]:
    validate_instance_name(instance_name)

    if not MINI_ODOO_CLI.is_file():
        raise ApiError(
            500,
            "Mini Odoo CLI does not exist.",
            str(MINI_ODOO_CLI),
        )

    if not os.access(MINI_ODOO_CLI, os.X_OK):
        raise ApiError(
            500,
            "Mini Odoo CLI is not executable.",
            str(MINI_ODOO_CLI),
        )

    try:
        result = subprocess.run(
            [
                str(MINI_ODOO_CLI),
                "info",
                instance_name,
            ],
            capture_output=True,
            text=True,
            timeout=CLI_TIMEOUT_SECONDS,
            check=False,
            env={
                **os.environ,
                "MINI_ODOO_HOME": str(MINI_ODOO_HOME),
            },
        )
    except subprocess.TimeoutExpired as error:
        raise ApiError(
            504,
            "Instance status command timed out.",
            instance_name,
        ) from error
    except OSError as error:
        raise ApiError(
            500,
            "Instance status command could not be executed.",
            str(error),
        ) from error

    output = result.stdout.strip()

    if not output:
        details = result.stderr.strip() or None

        raise ApiError(
            500,
            "Instance status command returned no JSON.",
            details,
        )

    try:
        status_data = json.loads(output)
    except json.JSONDecodeError as error:
        raise ApiError(
            500,
            "Instance status command returned invalid JSON.",
            output[:500],
        ) from error

    if not isinstance(status_data, dict):
        raise ApiError(
            500,
            "Instance status response must be a JSON object.",
        )

    return status_data

ALLOWED_INSTANCE_ACTIONS = {
    "start",
    "stop",
    "restart",
}


def run_instance_action(
    instance_name: str,
    action: str,
) -> dict[str, Any]:
    validate_instance_name(instance_name)

    registry = load_registry()

    if instance_name not in registry:
        raise ApiError(
            404,
            "Instance is not registered.",
            instance_name,
        )

    if action not in ALLOWED_INSTANCE_ACTIONS:
        raise ApiError(
            400,
            "Unsupported instance action.",
            action,
        )

    if not MINI_ODOO_CLI.is_file():
        raise ApiError(
            500,
            "Mini Odoo CLI does not exist.",
            str(MINI_ODOO_CLI),
        )

    if not os.access(MINI_ODOO_CLI, os.X_OK):
        raise ApiError(
            500,
            "Mini Odoo CLI is not executable.",
            str(MINI_ODOO_CLI),
        )

    try:
        result = subprocess.run(
            [
                str(MINI_ODOO_CLI),
                action,
                instance_name,
            ],
            capture_output=True,
            text=True,
            timeout=CLI_TIMEOUT_SECONDS,
            check=False,
            env={
                **os.environ,
                "MINI_ODOO_HOME": str(MINI_ODOO_HOME),
            },
        )
    except subprocess.TimeoutExpired as error:
        raise ApiError(
            504,
            "Instance action timed out.",
            f"{action}: {instance_name}",
        ) from error
    except OSError as error:
        raise ApiError(
            500,
            "Instance action could not be executed.",
            str(error),
        ) from error

    if result.returncode != 0:
        error_output = (
            result.stderr.strip()
            or result.stdout.strip()
            or "Command failed without output."
        )

        raise ApiError(
            500,
            "Instance action failed.",
            error_output[:1000],
        )

    return {
        "instance": instance_name,
        "action": action,
        "success": True,
        "output": result.stdout.strip() or None,
    }

def get_instance(instance_name: str) -> dict[str, Any]:
    registry = load_registry()

    if instance_name not in registry:
        raise ApiError(
            404,
            "Instance is not registered.",
            instance_name,
        )

    return run_instance_info(instance_name)


def get_all_instances() -> list[dict[str, Any]]:
    registry = load_registry()
    instances = []

    for instance_name in sorted(registry):
        try:
            instance_data = run_instance_info(instance_name)
        except ApiError as error:
            instance_data = {
                "name": instance_name,
                "status": "error",
                "error": error.message,
            }

            if error.details:
                instance_data["details"] = error.details

        instances.append(instance_data)

    return instances


class MiniOdooApiHandler(BaseHTTPRequestHandler):
    server_version = "MiniOdooAPI/0.1.0"

    def send_json(
        self,
        status_code: int,
        payload: Any,
    ) -> None:
        response = json.dumps(
            payload,
            ensure_ascii=False,
            indent=2,
        ).encode("utf-8")

        self.send_response(status_code)
        self.send_header(
            "Content-Type",
            "application/json; charset=utf-8",
        )
        self.send_header(
            "Content-Length",
            str(len(response)),
        )
        self.send_header(
            "Cache-Control",
            "no-store",
        )
        self.end_headers()
        self.wfile.write(response)

    def send_error_json(self, error: ApiError) -> None:
        payload = {
            "error": error.message,
        }

        if error.details:
            payload["details"] = error.details

        self.send_json(error.status_code, payload)

    def do_HEAD(self) -> None:
        parsed_url = urlparse(self.path)
        path = parsed_url.path.rstrip("/") or "/"

        content_types = {
            "/": "text/html; charset=utf-8",
            "/styles.css": "text/css; charset=utf-8",
            "/app.js": "application/javascript; charset=utf-8",
        }

        if path in content_types:
            self.send_response(200)
            self.send_header(
                "Content-Type",
                content_types[path],
            )
            self.send_header(
                "Cache-Control",
                "no-cache",
            )
            self.end_headers()
            return

        self.send_response(404)
        self.send_header(
            "Content-Type",
            "application/json; charset=utf-8",
        )
        self.end_headers()

    def read_json_body(self) -> dict[str, Any]:
        content_type = self.headers.get(
            "Content-Type",
            "",
        )

        if "application/json" not in content_type.lower():
            raise ApiError(
                415,
                "Content-Type must be application/json.",
            )

        content_length_value = self.headers.get(
            "Content-Length"
        )

        if not content_length_value:
            raise ApiError(
                400,
                "Request body is required.",
            )

        try:
            content_length = int(content_length_value)
        except ValueError as error:
            raise ApiError(
                400,
                "Invalid Content-Length header.",
            ) from error

        if content_length <= 0:
            raise ApiError(
                400,
                "Request body is required.",
            )

        if content_length > 4096:
            raise ApiError(
                413,
                "Request body is too large.",
            )

        raw_body = self.rfile.read(content_length)

        try:
            payload = json.loads(
                raw_body.decode("utf-8")
            )
        except (
            UnicodeDecodeError,
            json.JSONDecodeError,
        ) as error:
            raise ApiError(
                400,
                "Request body contains invalid JSON.",
            ) from error

        if not isinstance(payload, dict):
            raise ApiError(
                400,
                "Request body must be a JSON object.",
            )

        return payload

    def do_GET(self) -> None:
        parsed_url = urlparse(self.path)
        path = parsed_url.path.rstrip("/") or "/"

        try:
            if path == "/":
                self.serve_web_file(
                    "index.html",
                    "text/html; charset=utf-8",
                )
                return

            if path == "/styles.css":
                self.serve_web_file(
                    "styles.css",
                    "text/css; charset=utf-8",
                )
                return

            if path == "/app.js":
                self.serve_web_file(
                    "app.js",
                    "application/javascript; charset=utf-8",
                )
                return

            if path == "/api/health":
                self.send_json(
                    200,
                    {
                        "status": "ok",
                        "service": "mini-odoo-api",
                        "version": "0.1.0",
                    },
                )
                return

            if path == "/api/instances":
                instances = get_all_instances()

                self.send_json(
                    200,
                    {
                        "count": len(instances),
                        "instances": instances,
                    },
                )
                return

            prefix = "/api/instances/"

            if path.startswith(prefix):
                instance_name = unquote(
                    path[len(prefix):]
                )

                if not instance_name:
                    raise ApiError(
                        400,
                        "Instance name is required.",
                    )

                instance_data = get_instance(instance_name)
                self.send_json(200, instance_data)
                return

            raise ApiError(
                404,
                "Endpoint not found.",
            )

        except ApiError as error:
            self.send_error_json(error)
        except Exception:
            self.send_json(
                500,
                {
                    "error": "Unexpected API error.",
                },
            )

    def do_POST(self) -> None:
        parsed_url = urlparse(self.path)
        path = parsed_url.path.rstrip("/") or "/"

        try:
            prefix = "/api/instances/"
            suffix = "/actions"

            if (
                path.startswith(prefix)
                and path.endswith(suffix)
            ):
                encoded_instance_name = path[
                    len(prefix):-len(suffix)
                ].rstrip("/")

                instance_name = unquote(
                    encoded_instance_name
                )

                if not instance_name:
                    raise ApiError(
                        400,
                        "Instance name is required.",
                    )

                payload = self.read_json_body()

                action = payload.get("action")

                if not isinstance(action, str):
                    raise ApiError(
                        400,
                        "Action must be a string.",
                    )

                action = action.strip().lower()

                action_result = run_instance_action(
                    instance_name,
                    action,
                )

                try:
                    instance_data = run_instance_info(
                        instance_name
                    )
                except ApiError:
                    instance_data = None

                self.send_json(
                    200,
                    {
                        **action_result,
                        "instance_data": instance_data,
                    },
                )
                return

            raise ApiError(
                404,
                "Endpoint not found.",
            )

        except ApiError as error:
            self.send_error_json(error)
        except Exception:
            self.send_json(
                500,
                {
                    "error": "Unexpected API error.",
                },
            )

    def do_PUT(self) -> None:
        self.send_json(
            405,
            {
                "error": "Method not allowed.",
            },
        )

    def do_DELETE(self) -> None:
        self.send_json(
            405,
            {
                "error": "Method not allowed.",
            },
        )

    def send_file(
        self,
        file_path: Path,
        content_type: str,
    ) -> None:
        try:
            content = file_path.read_bytes()
        except FileNotFoundError as error:
            raise ApiError(
                404,
                "Web file not found.",
                str(file_path),
            ) from error
        except OSError as error:
            raise ApiError(
                500,
                "Web file could not be read.",
                str(error),
            ) from error

        self.send_response(200)
        self.send_header(
            "Content-Type",
            content_type,
        )
        self.send_header(
            "Content-Length",
            str(len(content)),
        )
        self.send_header(
            "Cache-Control",
            "no-cache",
        )
        self.end_headers()
        self.wfile.write(content)

    def serve_web_file(
        self,
        relative_path: str,
        content_type: str,
    ) -> None:
        file_path = (
            WEB_ROOT / relative_path
        ).resolve()

        try:
            file_path.relative_to(WEB_ROOT)
        except ValueError as error:
            raise ApiError(
                403,
                "Invalid web file path.",
            ) from error

        self.send_file(
            file_path,
            content_type,
        )

    def log_message(
        self,
        format_string: str,
        *args: Any,
    ) -> None:
        message = format_string % args
        print(
            f"{self.client_address[0]} - {message}",
            flush=True,
        )


def main() -> None:
    server = ThreadingHTTPServer(
        (API_HOST, API_PORT),
        MiniOdooApiHandler,
    )

    print(
        f"Mini Odoo API listening on "
        f"http://{API_HOST}:{API_PORT}",
        flush=True,
    )

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
