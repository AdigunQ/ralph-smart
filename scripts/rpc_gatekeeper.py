#!/usr/bin/env python3
"""
Minimal JSON-RPC gatekeeper.

Blocks dangerous development-only RPC methods (e.g. anvil_*, hardhat_*)
and forwards allowed requests to an upstream RPC endpoint.
"""

import argparse
import json
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


DEFAULT_DENY_PREFIXES = (
    "anvil_",
    "hardhat_",
    "debug_",
    "trace_",
    "txpool_",
    "personal_",
)

DEFAULT_DENY_EXACT = {
    "evm_setNextBlockTimestamp",
    "evm_setTime",
    "evm_mine",
    "evm_increaseTime",
    "eth_sendUnsignedTransaction",
}


def method_block_reason(method: str):
    if method in DEFAULT_DENY_EXACT:
        return f"method '{method}' is blocked"
    for prefix in DEFAULT_DENY_PREFIXES:
        if method.startswith(prefix):
            return f"method '{method}' is blocked by prefix '{prefix}'"
    return None


def make_error(rpc_id, code, message):
    return {"jsonrpc": "2.0", "id": rpc_id, "error": {"code": code, "message": message}}


class Handler(BaseHTTPRequestHandler):
    upstream = None

    def do_POST(self):
        length = int(self.headers.get("content-length", "0"))
        body = self.rfile.read(length)

        try:
            payload = json.loads(body.decode("utf-8"))
        except Exception:
            self._send_json(make_error(None, -32700, "Invalid JSON"))
            return

        reqs = payload if isinstance(payload, list) else [payload]
        errors = []
        allowed = []

        for req in reqs:
            method = req.get("method", "")
            reason = method_block_reason(method)
            if reason:
                errors.append(make_error(req.get("id"), -32000, reason))
            else:
                allowed.append(req)

        upstream_results = []
        if allowed:
            forward_payload = allowed if isinstance(payload, list) else allowed[0]
            req = urllib.request.Request(
                self.upstream,
                data=json.dumps(forward_payload).encode("utf-8"),
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            try:
                with urllib.request.urlopen(req, timeout=30) as resp:
                    forwarded = json.loads(resp.read().decode("utf-8"))
            except Exception as exc:
                self._send_json(make_error(None, -32001, f"upstream error: {exc}"))
                return

            if isinstance(forwarded, list):
                upstream_results.extend(forwarded)
            else:
                upstream_results.append(forwarded)

        response_items = upstream_results + errors
        if isinstance(payload, list):
            self._send_json(response_items)
        else:
            if response_items:
                self._send_json(response_items[0])
            else:
                self._send_json(make_error(None, -32600, "Invalid Request"))

    def log_message(self, fmt, *args):
        return

    def _send_json(self, data):
        raw = json.dumps(data).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)


def main():
    parser = argparse.ArgumentParser(description="JSON-RPC method gatekeeper proxy")
    parser.add_argument("--listen-host", default="127.0.0.1")
    parser.add_argument("--listen-port", type=int, default=8546)
    parser.add_argument("--upstream", required=True, help="Upstream RPC URL")
    args = parser.parse_args()

    Handler.upstream = args.upstream
    server = ThreadingHTTPServer((args.listen_host, args.listen_port), Handler)
    print(
        f"RPC gatekeeper listening on http://{args.listen_host}:{args.listen_port} -> {args.upstream}"
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
