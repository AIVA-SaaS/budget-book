"""Simple SPA-aware HTTP server for Flutter Web.
All non-file routes fall back to index.html.
"""
import http.server
import os
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 3050
DIRECTORY = sys.argv[2] if len(sys.argv) > 2 else "build/web"


class SPAHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def do_GET(self):
        # If the file exists, serve it. Otherwise, serve index.html (SPA fallback).
        file_path = os.path.join(DIRECTORY, self.path.lstrip("/").split("?")[0])
        if os.path.isfile(file_path):
            super().do_GET()
        else:
            self.path = "/index.html"
            super().do_GET()

    def log_message(self, format, *args):
        # Quiet logging — only errors
        if "404" in str(args) or "500" in str(args):
            super().log_message(format, *args)


if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)) + "/..")
    with http.server.HTTPServer(("", PORT), SPAHandler) as httpd:
        print(f"SPA server: http://localhost:{PORT} (dir: {DIRECTORY})")
        httpd.serve_forever()
