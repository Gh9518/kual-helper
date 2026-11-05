#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Fetch ebook cover images from online providers.

Design goals:
  * Multiple providers as alternatives (so a single dead source won't break it).
  * Ordered fallback: the first provider that returns a valid image wins.
  * Optional speed probe: measure each provider's latency once and reorder
    the list so the fastest source is tried first ("选用最快的网络").
  * Pure standard library (urllib) so it runs on the Kindle's Python 3.

Default provider order (sensible for global + CN users):
  Open Library  -> Google Books -> Amazon -> Douban(豆瓣)
"""

import json
import re
import urllib.request
import urllib.parse

USER_AGENT = (
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
)

# Each provider:
#   name     : human label
#   build    : function(asin, isbn) -> url  (returns None if it can't serve)
#   kind     : 'image'  -> url directly returns image bytes
#              'json'   -> url returns JSON; then 'pick' extracts image url
#              'html'   -> url returns HTML; then 'pick' extracts image url (regex)
#   pick     : function(body_bytes) -> image_url or None
PROVIDERS = [
    {
        'name': 'OpenLibrary',
        'kind': 'image',
        'build': lambda asin, isbn: (
            'https://covers.openlibrary.org/isbn/%s-L.jpg' % isbn
            if isbn else None),
    },
    {
        'name': 'GoogleBooks',
        'kind': 'json',
        'build': lambda asin, isbn: (
            'https://www.googleapis.com/books/v1/volumes?q=isbn:%s' % isbn
            if isbn else None),
        'pick': lambda body: _pick_google(body),
    },
    {
        'name': 'Amazon',
        'kind': 'image',
        'build': lambda asin, isbn: (
            'https://images.amazon.com/images/P/%s.jpg' % asin
            if asin else None),
    },
    {
        'name': 'Douban',
        'kind': 'html',
        'build': lambda asin, isbn: (
            'https://book.douban.com/subject_search?search_text=%s'
            % urllib.parse.quote(isbn) if isbn else None),
        'pick': lambda body: _pick_douban(body),
    },
]


def _pick_google(body):
    try:
        data = json.loads(body.decode('utf-8', 'ignore'))
        for item in data.get('items', []):
            links = item.get('volumeInfo', {}).get('imageLinks', {})
            url = links.get('thumbnail') or links.get('smallThumbnail')
            if url:
                # enlarge: remove curl edge and bump zoom
                url = url.replace('&edge=curl', '').replace('zoom=1', 'zoom=3')
                if 'zoom=' not in url:
                    url += '&zoom=3'
                return url
    except Exception:
        pass
    return None


def _pick_douban(body):
    try:
        text = body.decode('utf-8', 'ignore')
        m = re.search(r'<img[^>]+src="([^"]+?subject/[0-9]+/cover[^"]+?)"', text)
        if m:
            return m.group(1)
        m = re.search(r'og:image"\s+content="([^"]+)"', text)
        if m:
            return m.group(1)
    except Exception:
        pass
    return None


def _is_image(data):
    if not data or len(data) < 200:
        return False
    sig = data[:8]
    if sig.startswith(b'\xff\xd8\xff'):      # JPEG
        return True
    if sig.startswith(b'\x89PNG\r\n\x1a\n'):  # PNG
        return True
    if sig.startswith(b'GIF8'):              # GIF (reject OpenLibrary 1x1 placeholder)
        return len(data) > 600
    return False


def _http_get(url, timeout=8):
    req = urllib.request.Request(url, headers={'User-Agent': USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def fetch_image(url, timeout=8):
    """Return image bytes if `url` yields a valid image, else None."""
    try:
        data = _http_get(url, timeout=timeout)
        if _is_image(data):
            return data
    except Exception:
        pass
    return None


def fetch_cover(asin=None, isbn=None, timeout=8, providers=None):
    """Try providers in order; return (provider_name, image_bytes) or (None, None)."""
    providers = providers or PROVIDERS
    for p in providers:
        url = p['build'](asin, isbn)
        if not url:
            continue
        if p['kind'] == 'image':
            data = fetch_image(url, timeout=timeout)
            if data:
                return (p['name'], data)
        else:
            try:
                body = _http_get(url, timeout=timeout)
                img_url = p['pick'](body) if p.get('pick') else None
                if img_url:
                    data = fetch_image(img_url, timeout=timeout)
                    if data:
                        return (p['name'], data)
            except Exception:
                continue
    return (None, None)


def speed_rank(timeout=4, providers=None):
    """Probe each provider once and return a reordered list (fastest first)."""
    providers = providers or PROVIDERS
    scored = []
    for p in providers:
        # use a universally available ASIN/ISBN probe
        url = p['build']('B000000000', '9787111111111') or p['build']('B000000000', None)
        t0 = __import__('time').time()
        try:
            _http_get(url, timeout=timeout)
            dt = __import__('time').time() - t0
        except Exception:
            dt = timeout + 1  # unreachable sorts last
        scored.append((dt, p))
    scored.sort(key=lambda x: x[0])
    return [p for _dt, p in scored]


if __name__ == '__main__':
    # quick self-test
    name, data = fetch_cover(isbn='9787111111111')
    print('provider=%s bytes=%s' % (name, len(data) if data else 0))
