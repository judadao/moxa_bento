#!/usr/bin/env python3
"""Register the native host for the current OS user, without admin."""
import argparse
import json
import os
from pathlib import Path
import shlex

from companion.native import EXTENSION_ID, HOST
from companion.runtime import data_directory


def install(root, config_root=None, host_dir=None):
    root = Path(root).resolve()
    folder = Path(host_dir) if host_dir else data_directory() / "native-host"
    folder.mkdir(parents=True, exist_ok=True, mode=0o700)
    python = root / (".venv/Scripts/python.exe" if os.name == "nt" else ".venv/bin/python")
    if not python.exists():
        raise SystemExit("Run setup-windows.bat / setup-linux.sh first to create .venv.")
    entry = root / 'native_host.py'
    launcher = folder / ('launch-host.bat' if os.name == 'nt' else 'launch-host.sh')
    if os.name == 'nt':
        quoted_python = str(python).replace('%', '%%')
        quoted_entry = str(entry).replace('%', '%%')
        launcher.write_text(f'@echo off\nchcp 65001 >nul\nsetlocal DisableDelayedExpansion\n"{quoted_python}" "{quoted_entry}" %*\n', encoding='utf-8')
    else:
        launcher.write_text('#!/bin/sh\nexec ' + shlex.quote(str(python)) + ' ' + shlex.quote(str(entry)) + ' "$@"\n')
        launcher.chmod(0o700)
    manifest = {'name': HOST, 'description': 'Bento Buddy local order bridge', 'path': str(launcher),
                'type': 'stdio', 'allowed_origins': [f'chrome-extension://{EXTENSION_ID}/']}
    manifest_file = folder / (HOST + '.json')
    manifest_file.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    if os.name == 'nt':
        import winreg
        for browser in ('Google\\Chrome', 'Microsoft\\Edge', 'Chromium'):
            with winreg.CreateKey(winreg.HKEY_CURRENT_USER, 'Software\\' + browser + '\\NativeMessagingHosts\\' + HOST) as key:
                winreg.SetValueEx(key, '', 0, winreg.REG_SZ, str(manifest_file))
    else:
        base = Path(config_root) if config_root else Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config'))
        for browser in ('google-chrome', 'google-chrome-for-testing', 'chromium', 'microsoft-edge'):
            target = base / browser / 'NativeMessagingHosts' / (HOST + '.json')
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(manifest_file.read_text(encoding='utf-8'), encoding='utf-8')
    return manifest_file


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--config-root', type=Path, help='Testing: isolated Linux browser config root')
    parser.add_argument('--host-dir', type=Path, help='Testing: isolated host launcher directory')
    args = parser.parse_args()
    install(Path(__file__).resolve().parent, args.config_root, args.host_dir)
    print('Native host registered. Load extension/ in chrome://extensions or edge://extensions.')
    print('Extension ID:', EXTENSION_ID)
