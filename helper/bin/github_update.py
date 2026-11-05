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

All stdout lines are short English status lines: github_update.sh forwards
them to eips, whose built-in font does not reliably render Chinese glyphs.

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


def latest_tag_via_web(repo, timeout=15):
    """不依赖 API 的兜底：/releases/latest 会 302 到 /releases/tag/<tag>。

    匿名 GitHub API 限额为 60 次/小时，共享网络下常被耗尽（HTTP 403）。
    网页重定向不受该限额影响，可在限流时仍然拿到最新版本号。
    """
    url = 'https://github.com/%s/releases/latest' % repo

    class _NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            return None

    opener = urllib.request.build_opener(_NoRedirect)
    req = urllib.request.Request(url, headers={'User-Agent': UA})
    # 网络偶发抖动时重试一次，避免一次超时就判定更新失败。
    for _attempt in range(2):
        loc = ''
        try:
            resp = opener.open(req, timeout=timeout)
            loc = resp.headers.get('Location', '')
        except urllib.error.HTTPError as e:
            loc = e.headers.get('Location', '')   # 302 会以 HTTPError 抛出
        except Exception:
            continue
        m = re.search(r'/releases/tag/(v?[0-9]+\.[0-9]+\.[0-9]+)', loc)
        if m:
            return m.group(1)
    return None


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

    tag = ''
    assets = []
    try:
        data = json.loads(http_get(API % repo))
        tag = data.get('tag_name', '')
        assets = data.get('assets', [])
    except Exception as api_err:
        # 匿名 API 被限流 / 网络异常时，改用网页重定向兜底拿版本号。
        tag = latest_tag_via_web(repo) or ''
        if not tag:
            print('Cannot get latest version: %s' % api_err)
            return 1
        print('API unavailable - using web fallback')

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
    if not dl and tag:
        # 兜底路径没有 assets 元数据，按 GitHub Release 固定规则拼接下载地址。
        dl = 'https://github.com/%s/releases/download/%s/%s' % (repo, tag, asset)
    if not dl:
        print('Update package not found: %s' % asset)
        return 1

    cur = local_version(ext_path)
    latest = tag.lstrip('vV')
    if parse_version(latest) <= parse_version(cur):
        print('Already up-to-date: v%s' % cur)
        return 0

    print('New version found: v%s (current v%s)' % (latest, cur))
    if check_only:
        print('Run without --check to apply the update')
        return 0

    print('Downloading update package...')
    tmp = tempfile.mkdtemp(prefix='kual-upd-')
    zip_path = os.path.join(tmp, 'update.zip')
    payload = None
    last_err = None
    # 弱网 / CDN 抖动时重试一次，避免单次超时就判定更新失败。
    for _attempt in range(2):
        try:
            payload = http_get(dl, timeout=90)
            break
        except Exception as e:
            last_err = e
    if not payload:
        shutil.rmtree(tmp, ignore_errors=True)
        print('Download failed: %s (check network)' % last_err)
        return 1
    with open(zip_path, 'wb') as f:
        f.write(payload)

    extract_dir = os.path.join(tmp, 'ext')
    os.makedirs(extract_dir, exist_ok=True)
    dest_root = os.path.realpath(extract_dir)
    with zipfile.ZipFile(zip_path) as z:
        # 防 zip-slip：拒绝绝对路径与 ../ 逃逸成员。
        for info in z.infolist():
            target = os.path.realpath(os.path.join(extract_dir, info.filename))
            if target != dest_root and not target.startswith(dest_root + os.sep):
                print('Unsafe path in package, install refused: %s' % info.filename)
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
    print('Updated to v%s - please refresh KUAL menu' % latest)
    return 0


if __name__ == '__main__':
    sys.exit(main())
