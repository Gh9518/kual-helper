#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Extract embedded cover image and metadata from EPUB files.

EPUB is a ZIP container. The OPF manifest (found via META-INF/container.xml)
declares the cover image either through:
  * <meta name="cover" content="cover-id"/>  (legacy EPUB 2)
  * an <item> with properties="cover-image"   (EPUB 3)
  * or by convention an <item> whose id/href contains "cover"
"""

import os
import re
import zipfile
import xml.etree.ElementTree as ET


def _strip_ns(tag):
    return tag.split('}')[-1] if '}' in tag else tag


def _parse_opf(zf, opf_path):
    try:
        data = zf.read(opf_path)
        root = ET.fromstring(data)
    except (KeyError, ET.ParseError):
        return None

    metadata = {'identifiers': []}
    cover_meta_id = None
    manifest_items = []  # (id, href, properties, media_type)
    opf_dir = os.path.dirname(opf_path)

    for child in root:
        tag = _strip_ns(child.tag)
        if tag == 'metadata':
            for m in child:
                t = _strip_ns(m.tag)
                if t == 'identifier':
                    metadata['identifiers'].append((
                        m.get('id'),
                        (m.get('scheme') or '').upper(),
                        (m.text or '').strip(),
                    ))
                elif t == 'meta' and (m.get('name') or '').lower() == 'cover':
                    cover_meta_id = m.get('content')
                elif t in ('title', 'creator', 'language'):
                    metadata[t] = (m.text or '').strip()
        elif tag == 'manifest':
            for item in child:
                if _strip_ns(item.tag) == 'item':
                    manifest_items.append((
                        item.get('id'),
                        item.get('href'),
                        item.get('properties', ''),
                        item.get('media-type', ''),
                    ))
    return metadata, manifest_items, opf_dir, cover_meta_id


def _resolve_path(opf_dir, href):
    href = (href or '').split('#')[0]
    try:
        from urllib.parse import unquote
        href = unquote(href)
    except Exception:
        pass
    return os.path.normpath(os.path.join(opf_dir, href)).lstrip('./')


class EPUBFile:
    def __init__(self, path):
        if not os.path.isfile(path):
            raise OSError('The specified file does not exist!')
        if not path.lower().endswith('.epub'):
            raise OSError('The specified file is not an EPUB!')
        try:
            self.zf = zipfile.ZipFile(path)
        except zipfile.BadZipFile:
            raise OSError('The specified file is not a valid EPUB!')
        self._parsed = None

    def _ensure_parsed(self):
        if self._parsed is None:
            opf_path = None
            try:
                opf_path = self.zf.read('META-INF/container.xml')
                croot = ET.fromstring(opf_path)
                for rf in croot.iter():
                    if _strip_ns(rf.tag) == 'rootfile' and rf.get('full-path'):
                        opf_path = rf.get('full-path')
                        break
            except (KeyError, ET.ParseError):
                opf_path = None
            self._parsed = _parse_opf(self.zf, opf_path) if opf_path else None
        return self._parsed

    def get_metadata(self, key):
        parsed = self._ensure_parsed()
        if parsed is None:
            return None
        metadata, _items, _dir, _cid = parsed

        if key == 'ASIN':
            for _id, scheme, val in metadata.get('identifiers', []):
                if scheme in ('MOBI-ASIN', 'ASIN'):
                    return val
                if re.match(r'^[A-Z0-9]{10}$', val) or re.match(r'^[0-9]{13}$', val):
                    return val
            if metadata.get('identifiers'):
                return metadata['identifiers'][0][2]
            return None
        if key == 'ISBN':
            for _id, scheme, val in metadata.get('identifiers', []):
                v = re.sub(r'[^0-9Xx]', '', val)
                if len(v) in (10, 13):
                    return v
            return None
        if key == 'Document Type':
            return 'EBOK'
        if key in metadata:
            return metadata[key]
        return None

    def get_cover_image(self):
        parsed = self._ensure_parsed()
        if parsed is None:
            return None
        _metadata, items, opf_dir, cover_meta_id = parsed

        cover_id = cover_meta_id
        if not cover_id:
            for _id, href, props, mt in items:
                if 'cover-image' in (props or '').split():
                    cover_id = _id
                    break
        if not cover_id:
            for _id, href, props, mt in items:
                if href and href.lower().endswith(
                        ('.jpg', '.jpeg', '.png', '.gif')) and 'cover' in _id.lower():
                    cover_id = _id
                    break
        if not cover_id:
            return None

        href = None
        for _id, h, props, mt in items:
            if _id == cover_id:
                href = h
                break
        if not href:
            return None

        rel = _resolve_path(opf_dir, href)
        for candidate in (rel, href):
            try:
                return self.zf.read(candidate)
            except KeyError:
                continue
        return None

    def close(self):
        try:
            self.zf.close()
        except Exception:
            pass
