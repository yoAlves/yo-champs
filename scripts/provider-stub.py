#!/usr/bin/env python3
"""Minimal OpenAI-compatible SSE stub used by `make provider-check`.

Prints its chosen port on stdout, then serves chat completions on 127.0.0.1.
No real key, credential or provider payload is involved.
"""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        try:
            payload = json.loads(self.rfile.read(length))
        except ValueError:
            self.send_response(400)
            self.end_headers()
            return
        if not payload.get("stream"):
            self.send_response(400)
            self.end_headers()
            return

        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.end_headers()
        for text in ["Hello ", "from stub"]:
            chunk = {"choices": [{"delta": {"content": text}, "finish_reason": None}]}
            self.wfile.write(f"data: {json.dumps(chunk)}\n\n".encode())
            self.wfile.flush()
        self.wfile.write(b"data: [DONE]\n\n")
        self.wfile.flush()

    def log_message(self, *_args):
        pass


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
print(server.server_address[1], flush=True)
server.serve_forever()
