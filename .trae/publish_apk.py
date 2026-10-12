#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 release APK 复制为带版本号的文件名，生成二维码并启动局域网共享。"""
from __future__ import annotations

import re
import shutil
import socket
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PUBSPEC = ROOT / 'pubspec.yaml'
SRC = ROOT / 'build' / 'app' / 'outputs' / 'flutter-apk' / 'app-release.apk'
BUILD_DIR = ROOT / 'build'
TRAE_DIR = ROOT / '.trae'
PORT = 8080


def app_version() -> str:
    text = PUBSPEC.read_text(encoding='utf-8')
    match = re.search(r'^version:\s*([0-9]+(?:\.[0-9]+)*)', text, re.M)
    if not match:
        raise SystemExit('version not found in pubspec.yaml')
    return match.group(1)


def lan_ip() -> str:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.connect(('8.8.8.8', 80))
        return sock.getsockname()[0]
    except OSError:
        return '127.0.0.1'
    finally:
        sock.close()


def main() -> None:
    if not SRC.is_file():
        raise SystemExit(f'missing release apk: {SRC}')

    version = app_version()
    name = f'earthvillage-{version}.apk'
    dest_build = BUILD_DIR / name
    dest_trae = TRAE_DIR / name
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy2(SRC, dest_build)
    shutil.copy2(SRC, dest_trae)
    # 兼容旧链接
    shutil.copy2(SRC, BUILD_DIR / 'earthvillage-latest.apk')

    url = f'http://{lan_ip()}:{PORT}/{name}'
    try:
        import qrcode
    except ImportError:
        sys.path.insert(0, str(TRAE_DIR / 'sdk' / 'pylibs'))
        import qrcode

    qr_path = TRAE_DIR / 'apk_qr.png'
    qrcode.make(url).save(qr_path)
    (TRAE_DIR / 'gen_qr.py').write_text(
        "from pathlib import Path\n\nimport qrcode\n\n"
        f"url = '{url}'\n"
        "out = Path(__file__).with_name('apk_qr.png')\n"
        "qrcode.make(url).save(out)\n"
        "print('QR SAVED', out, url)\n",
        encoding='utf-8',
    )

    subprocess.run([sys.executable, str(TRAE_DIR / 'serve_apk.py')], check=False)
    print(f'APK {dest_build} ({dest_build.stat().st_size // (1024 * 1024)} MB)')
    print(f'URL {url}')
    print(f'QR  {qr_path}')


if __name__ == '__main__':
    main()
