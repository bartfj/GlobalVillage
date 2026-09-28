#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""在内网以 HTTP 共享 build/ 目录下的 APK（双 fork 守护进程，不随终端退出）。"""
import http.server
import os
import socket
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SERVE_DIR = ROOT / 'build'
PID_FILE = Path('/tmp/gv-http.pid')
LOG_FILE = Path('/tmp/gv-http.log')
PORT = 8080


def lan_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('8.8.8.8', 80))
        return s.getsockname()[0]
    except OSError:
        return '127.0.0.1'
    finally:
        s.close()


def already_running():
    if not PID_FILE.exists():
        return False
    try:
        pid = int(PID_FILE.read_text().strip())
        os.kill(pid, 0)
        return True
    except (ValueError, OSError, ProcessLookupError):
        return False


def daemonize():
    if os.fork() > 0:
        sys.exit(0)
    os.setsid()
    if os.fork() > 0:
        sys.exit(0)
    sys.stdin = open(os.devnull, 'r')
    sys.stdout = open(LOG_FILE, 'a', buffering=1)
    sys.stderr = sys.stdout
    os.chdir(SERVE_DIR)


def main():
    if not SERVE_DIR.is_dir():
        print('missing build dir:', SERVE_DIR, file=sys.stderr)
        sys.exit(1)

    if already_running():
        print(f'already running pid={PID_FILE.read_text().strip()}')
        print(f'http://{lan_ip()}:{PORT}/earthvillage-latest.apk')
        return

    daemonize()
    PID_FILE.write_text(str(os.getpid()))
    handler = http.server.SimpleHTTPRequestHandler
    httpd = http.server.ThreadingHTTPServer(('0.0.0.0', PORT), handler)
    print(f'serving {SERVE_DIR} on :{PORT} pid={os.getpid()}')
    try:
        httpd.serve_forever()
    finally:
        try:
            PID_FILE.unlink()
        except OSError:
            pass


if __name__ == '__main__':
    main()
