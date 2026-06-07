#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, HTTPServer
import sys


class CaptivePortalHandler(BaseHTTPRequestHandler):
    def do_HEAD(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()

    def do_GET(self):
        self.do_HEAD()
        self.wfile.write(b"hi")

    def do_POST(self):
        self.do_GET()

    def do_PUT(self):
        self.do_GET()

    def do_DELETE(self):
        self.do_GET()

    def do_PATCH(self):
        self.do_GET()

    def do_OPTIONS(self):
        self.do_GET()


if __name__ == "__main__":
    server_address = ("0.0.0.0", 8080)
    print("Starting Captive Portal on http://0.0.0.0:8080")
    try:
        httpd = HTTPServer(server_address, CaptivePortalHandler)
        httpd.serve_forever()
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
