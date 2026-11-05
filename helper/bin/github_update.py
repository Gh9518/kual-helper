#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Update helper from a GitHub release.

Usage:
    github_update.py <owner/repo> <asset_name> <ext_path> [--check]

  * Queries the GitHub API for the latest release of <owner/repo>.
  * Compares its tag with the local VERSION file.
  * If a newer version exists, downloads the matching release asset and
    extracts it over <ext_path> (overwrite only, no deletion).
  * With --check it only reports the version difference and exits.

Pure standard library (urllib/zipfile/shutil) so it runs on the Kindle's
Python 3 without extra packages.
"""

import os
import re
import sys
import json
import shutil
import tempfile
import zipfile
import urllib.request
import urllib.error

UA = 'kual-helper-updater'
API = 'https://api.github.com/repos/%s/releases/latest'


def http_get(url, timeout=15):
    req = urllib.request.Request(
        url,
        headers={'User-Agent': UA,
                 'Accept': 'application/vnd.github+json'})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def parse_version(s):
    """Turn 'v1.2.3' into (1, 2, 3) for comparison."""
    s = (s or '').lstrip('vV').strip()
    parts = []
    for seg in s.split('.'):
        num = ''
        for ch in seg:
            if ch.isdigit():
                num += ch
            else:
                break
        parts.append(int(num) if num else 0)
    return tuple(parts)


def local_version(ext_path):
    try:
        with open(os.path.join(ext_path, 'VERSION')) as f:
            txt = f.read()
        m = re.search(r'v?\d+\.\d+\.\d+', txt)
        return m.group(0).lstrip('vV') if m else '0'
    except Exception:
        return '0'


def main():
    if len(sys.argv) < 4:
        print('Usage: github_update.py <owner/repo> <asset> <ext_path> [--check]')
        return 2

    repo, asset, ext_path = sys.argv[1], sys.argv[2], sys.argv[3]
    check_only = '--check' in sys.argv[4:]

    try:
        data = json.loads(http_get(API % repo))
    except Exception as e:
        print('获取最新版本失败: %s' % e)
        return 1

    tag = data.get('tag_name', '')
    assets = data.get('assets', [])
    dl = None
    for a in assets:
        if a.get('name') == asset:
            dl = a.get('browser_download_url')
            break
    if dl is None:
        for a in assets:
            if (a.get('name') or '').endswith('.zip'):
                dl = a.get('browser_download_url')
                break
    if not dl:
        print('发布中没有找到更新包（%s）' % asset)
        return 1

    cur = local_version(ext_path)
    latest = tag.lstrip('vV')
    if parse_version(latest) <= parse_version(cur):
        print('已是最新版本 v%s' % cur)
        return 0

    print('发现新版本 v%s（当前 v%s）' % (latest, cur))
    if check_only:
        print('去掉 --check 参数即可执行更新')
        return 0

    tmp = tempfile.mkdtemp(prefix='kual-upd-')
    zip_path = os.path.join(tmp, 'update.zip')
    try:
        with open(zip_path, 'wb') as f:
            f.write(http_get(dl, timeout=120))
    except Exception as e:
        print('下载失败: %s' % e)
        return 1

    extract_dir = os.path.join(tmp, 'ext')
    os.makedirs(extract_dir, exist_ok=True)
    dest_root = os.path.realpath(extract_dir)
    with zipfile.ZipFile(zip_path) as z:
        # 防 zip-slip：拒绝绝对路径与 ../ 逃逸成员。
        for info in z.infolist():
            target = os.path.realpath(os.path.join(extract_dir, info.filename))
            if target != dest_root and not target.startswith(dest_root + os.sep):
                print('更新包含非法路径，已拒绝安装: %s' % info.filename)
                shutil.rmtree(tmp, ignore_errors=True)
                return 1
        z.extractall(extract_dir)

    entries = os.listdir(extract_dir)
    src = extract_dir
    if len(entries) == 1 and os.path.isdir(os.path.join(extract_dir, entries[0])):
        src = os.path.join(extract_dir, entries[0])

    for root, _dirs, files in os.walk(src):
        rel = os.path.relpath(root, src)
        dest_root = ext_path if rel == '.' else os.path.join(ext_path, rel)
        os.makedirs(dest_root, exist_ok=True)
        for fn in files:
            shutil.copy2(os.path.join(root, fn), os.path.join(dest_root, fn))

    shutil.rmtree(tmp, ignore_errors=True)
    print('已更新到 v%s，请在 KUAL 中刷新菜单' % latest)
    return 0


if __name__ == '__main__':
    sys.exit(main())
