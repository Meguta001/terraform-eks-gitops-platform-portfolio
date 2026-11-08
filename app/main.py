
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class AppHandler(BaseHTTPRequestHandler):

    def send_json(self, status_code, payload):
        body = (json.dumps(payload) + "\n").encode("utf-8")

        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()

        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/":
            self.send_json(200, {
                "application": "eks-gitops-platform",
                "message": "Hello from Kubernetes!",
                "version": "v2",
                "status": "running"
            })

        elif self.path == "/health":
            self.send_json(200, {
                "status": "ok"
            })

        else:
            self.send_json(404, {
                "error": "not found"
            })


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))

    server = ThreadingHTTPServer(
        ("0.0.0.0", port),
        AppHandler
    )

    print(f"Application listening on port {port}", flush=True)

    server.serve_forever()
