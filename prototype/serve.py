#!/usr/bin/env python3
"""
Dev server for the TCD Store prototype.

Same job as `python3 -m http.server`, with one difference that matters:
it tells the browser never to cache anything.

`http.server` sends `Last-Modified` and no `Cache-Control`, so browsers apply
heuristic freshness and will happily reuse a cached stylesheet or script
without revalidating it. When you edit app.css and reload, you get the old
version, the page looks unchanged, and you conclude nothing happened. That is
exactly the trap this file exists to remove.

    python3 serve.py [port]      # default 8080

A plain reload then always shows the current build. If you ever need to
compare a previous revision, check it out from git and reload.
"""

import http.server
import socketserver
import sys
import os

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
ROOT = os.path.dirname(os.path.abspath(__file__))


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        # no-store is the strong one: do not keep a copy at all.
        # no-cache would still allow a conditional request, which is a 304
        # and another chance for a stale body to look like a fresh one.
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def send_header(self, key, value):
        # Suppress the validator that makes the browser confident it has a
        # current copy, so a conditional request never becomes a 304.
        if key == "Last-Modified":
            return
        super().send_header(key, value)

    def log_message(self, fmt, *args):
        # Mark the source address so a human can tell their own reloads
        # apart from anything else hitting the port.
        sys.stderr.write("  %s  %s\n" % (self.client_address[0], fmt % args))


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    with Server(("0.0.0.0", PORT), NoCacheHandler) as httpd:
        print(f"TCD Store prototype — http://localhost:{PORT}  (caching disabled)")
        sys.stderr.flush()
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass
