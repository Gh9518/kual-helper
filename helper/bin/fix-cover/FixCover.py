#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re
import sys
import time
import glob
import imghdr
import string
import tempfile
import sqlite3
from pathlib import Path

from File import MOBIFile
from EPUBFile import EPUBFile
import CoverNet


class FixCover:
    name = 'Fix Kindle Ebook Cover'
    version = '1.3'
    feedback = 'https://bookfere.com/post/994.html'
    description = '%s - v%s\nA tool to fix damaged Kindle ebook covers.\n \
Feedback: %s' % (name, version, feedback)


    def __init__(self, logger=None, progress=None, db=None, net=False,
                 net_timeout=6, speed=False, missing_only=False):
        self.logger = logger
        self.progress = progress
        self.net = net
        self.net_timeout = net_timeout
        # 仅处理「没有封面」的电子书（联网修复封面时使用）
        self.missing_only = missing_only
        # Optional: probe providers once and try the fastest first.
        if net and speed:
            try:
                CoverNet.PROVIDERS[:] = CoverNet.speed_rank(
                    timeout=min(4, net_timeout))
                self.log('Network providers reordered by speed.')
            except Exception:
                pass

        # Only for KUAL extention
        self.db_access = False
        db_path = db if db is not None else '/var/local/cc.db'
        if (os.path.exists(db_path)):
            self.db_access = True
            self.db_connection = sqlite3.connect(
                db_path,
                check_same_thread=False
            )
            self.db_cursor = self.db_connection.cursor()

        self.log('Time: %s' % time.strftime('%Y-%m-%d %H:%M:%S'))
        self.log(self.description, True)


    def log(self, text, sep=False):
        if self.logger is not None:
            divider = '-------------------------------------------'
            text =  '%s\n%s\n%s' % (divider, text, divider) \
                if sep is True else text
            self.logger(text)


    def print_progress(self, factor):
        if self.progress is not None:
            self.progress(factor)


    def get_filepath_list(self, path):
        return glob.glob('%s%s**' % (path, os.sep), recursive=True)


    def get_ebook_thumbnails_via_path(self, path):
        thumbnails = dict()
        for thumbnail in self.get_filepath_list(path):
            asin = re.match(
                rf'.*{re.escape(os.sep)}thumbnail_(.+?)[_\.].+',
                thumbnail
            )
            if asin is not None:
                thumbnails[asin.group(1)] = thumbnail
        return thumbnails


    def get_ebook_thumbnails_via_db(self):
        thumbnails = self.db_cursor.execute(' \
            SELECT p_thumbnail FROM Entries \
            WHERE p_thumbnail IS NOT NULL \
            AND p_location IS NOT NULL')
        return [row[0] for row in thumbnails.fetchall()]


    def is_damaged_thumbnail(self, path):
        try:
            return os.path.getsize(path) < 2000
        except:
            return False


    def get_damaged_thumbnails(self, path):
        thumbnails = self.get_ebook_thumbnails_via_path(path)
        for thumbnail in thumbnails.copy():
            thumbnail_path = thumbnails[thumbnail]
            if not self.is_damaged_thumbnail(thumbnail_path):
                del thumbnails[thumbnail]
        return thumbnails


    def has_valid_thumbnail(self, asin, thumbnails_path):
        """该 ASIN 是否已存在一张正常（非损坏/占位）的封面缩略图。"""
        if not asin:
            return False
        for p in glob.glob(os.path.join(thumbnails_path,
                                        'thumbnail_%s_*' % asin)):
            try:
                if os.path.isfile(p) and not self.is_damaged_thumbnail(p):
                    return True
            except Exception:
                pass
        return False


    def is_valid_ebook_file(self, filename):
        for ext in ['.mobi', '.azw', '.azw3', '.azw4', '.epub', '.pdf']:
            if filename.lower().endswith(ext):
                return True
        return False


    def get_ebook_list_via_path(self, path):
        ebook_list = []
        for filename in self.get_filepath_list(path):
            if not self.is_valid_ebook_file(filename):
                continue
            ebook_list.append(filename)
        return ebook_list


    def get_ebook_list_via_db(self):
        ebook_list = self.db_cursor.execute(" \
            SELECT p_uuid, p_location, p_thumbnail, p_cdeType FROM Entries \
            WHERE p_cdeType IN ('PDOC', 'EBOK') \
            AND p_location IS NOT NULL")
        return ebook_list.fetchall()


    def store_ebook_thumbnail(self, path, data):
        with open(path, 'wb') as file:
            file.write(data)


    def get_ebook_metadata(self, path):
        """仅解析电子书文件内嵌的元数据与封面，不联网。"""
        ebook_asin = None
        ebook_type = None
        ebook_cover = None

        ext = os.path.splitext(path)[1].lower()
        if ext in ('.mobi', '.azw', '.azw3', '.azw4'):
            try:
                mobi_file = MOBIFile(path)
                ebook_asin = mobi_file.get_metadata('ASIN')
                ebook_type = mobi_file.get_metadata('Document Type')
                ebook_cover = mobi_file.get_cover_image()
            except:
                pass
        elif ext == '.epub':
            try:
                epub_file = EPUBFile(path)
                ebook_asin = epub_file.get_metadata('ASIN') \
                    or epub_file.get_metadata('ISBN')
                ebook_type = 'EBOK'
                ebook_cover = epub_file.get_cover_image()
            except:
                pass
        elif ext == '.pdf':
            try:
                ebook_asin, ebook_type, ebook_cover = \
                    self.get_pdf_metadata(path)
            except:
                pass

        return (ebook_asin, ebook_type, ebook_cover)


    def fetch_cover_online(self, path, ext, asin):
        """仅在确认缺封面后调用：按 ISBN / ASIN 从多源联网获取封面。

        返回 (cover_data, asin)。若原 ASIN 为空但拿到 ISBN，则用 ISBN
        作为缩略图命名依据，避免生成的封面无处可归。
        """
        isbn = self._get_isbn(path, ext)
        if not (asin or isbn):
            return (None, asin)
        try:
            name, data = CoverNet.fetch_cover(
                asin=asin, isbn=isbn, timeout=self.net_timeout)
        except Exception:
            return (None, asin)
        if data:
            self.log('✓ Fetched cover from network: %s\n  └─ %s' %
                     (name, Path(path).name))
            return (data, asin or isbn)
        return (None, asin)


    def _get_isbn(self, path, ext):
        """Best-effort ISBN from sidecar file (esp. for PDF without metadata)."""
        stem, _ = os.path.splitext(path)
        for cand in (path + '.isbn', stem + '.isbn'):
            try:
                with open(cand, 'r') as f:
                    v = re.sub(r'[^0-9Xx]', '', f.read().strip())
                    if len(v) in (10, 13):
                        return v
            except Exception:
                pass
        if ext == '.epub':
            try:
                return EPUBFile(path).get_metadata('ISBN')
            except Exception:
                pass
        return None


    def get_pdf_metadata(self, path):
        """PDF sideloaded books have no embedded MOBI-style cover.

        Strategy:
          * Manual cover association: a sibling image file named like
            '<book>.cover.jpg' / '<book>.pdf.cover.png' / 'cover.jpg'.
          * Optional sidecar '<book>.isbn' (or '<book>.pdf.isbn') carrying an
            ISBN, so a network cover can be fetched.
        Document type for sideloaded PDF on Kindle is usually 'PDOC'.
        """
        cover = self._find_pdf_manual_cover(path)
        asin = None
        isbn = self._get_isbn(path, '.pdf')
        if isbn:
            asin = isbn
        return (asin, 'PDOC', cover)


    def _find_pdf_manual_cover(self, path):
        stem, _ = os.path.splitext(path)
        d = os.path.dirname(path)
        candidates = [
            path + '.cover.jpg', path + '.cover.png',
            stem + '.cover.jpg', stem + '.cover.png',
            os.path.join(d, 'cover.jpg'), os.path.join(d, 'cover.png'),
        ]
        for c in candidates:
            try:
                if os.path.isfile(c):
                    return open(c, 'rb').read()
            except Exception:
                pass
        return None


    def get_thumbnail_name(self, asin, cdetype):
        return 'thumbnail_%s_%s_portrait.jpg' % (asin, cdetype)


    def fix_via_db(self, thumbnails_path):
        for row in self.get_ebook_list_via_db():
            p_uuid, p_location, p_thumbnail, p_cde = row
            if not os.path.exists(p_location):
                continue

            if p_location.endswith('KUAL.kual'):
                cover = Path(os.path.join(os.path.dirname(__file__),
                    'kual.jpg')).read_bytes()
                asin, cde = None, p_cde
            elif not self.is_valid_ebook_file(p_location):
                continue
            else:
                asin, cde, cover = self.get_ebook_metadata(p_location)

                # 「仅无封面」：已有正常缩略图的书直接跳过（不联网、不改写）
                if self.missing_only and p_thumbnail \
                        and os.path.exists(p_thumbnail) \
                        and not self.is_damaged_thumbnail(p_thumbnail):
                    continue

                # 联网补齐：只有本地确实没找到内嵌封面时才联网
                if cover is None and self.net:
                    cover, asin = self.fetch_cover_online(
                        p_location,
                        os.path.splitext(p_location)[1].lower(), asin)

            if cover is None:
                self.failure_jobs['ebook_errors'].append('%s\n  └─[%s] %s' %
                    ('No cover was found.', p_cde, Path(p_location).name))
                continue

            if p_thumbnail is None and p_cde in ('EBOK', 'PDOC'):
                asin = asin if asin is not None else p_uuid
                cde = cde if cde is not None else p_cde
                thumbnail_path = os.path.join(thumbnails_path,
                    self.get_thumbnail_name(asin, cde))
                self.store_ebook_thumbnail(thumbnail_path, cover)
                self.db_cursor.execute('UPDATE Entries SET p_thumbnail = ? \
                    WHERE p_location = ?', (thumbnail_path, p_location))
                self.conquest_jobs += 1
                self.log('✓ Generated: %s\n  └─[%s] %s' %
                        (Path(thumbnail_path).name, p_cde, Path(p_location).name))
            elif p_thumbnail is not None and (not os.path.exists(p_thumbnail)
                or self.is_damaged_thumbnail(p_thumbnail)):
                    self.store_ebook_thumbnail(p_thumbnail, cover)
                    self.conquest_jobs += 1
                    self.log('✓ Fixed: %s\n  └─[%s] %s' %
                        (Path(p_thumbnail).name, p_cde, Path(p_location).name))


    def fix_via_path(self, thumbnails, documents_path, thumbnails_path):
        ebook_list = self.get_ebook_list_via_path(documents_path)
        for ebook in ebook_list:
            self.print_progress(len(ebook_list))

            ext = os.path.splitext(str(ebook))[1].lower()
            ebook_asin, ebook_type, ebook_cover = self.get_ebook_metadata(str(ebook))

            # 「仅无封面」：已有正常缩略图的书跳过，避免无谓联网
            if self.missing_only and self.has_valid_thumbnail(
                    ebook_asin, thumbnails_path):
                continue

            ebook = Path(ebook)

            # 联网补齐：仅当本地没有内嵌封面时才尝试
            if ebook_cover is None and self.net:
                ebook_cover, ebook_asin = self.fetch_cover_online(
                    str(ebook), ext, ebook_asin)

            if ebook_cover is None:
                self.failure_jobs['ebook_errors'].append('%s\n  └─[%s] %s' %
                    ('No cover was found.', ebook_type, ebook.name))
                continue

            if ebook_type == 'EBOK' and ebook_asin in thumbnails.keys():
                thumbnail_path = thumbnails[ebook_asin]
                thumbnail_name = Path(thumbnail_path).name
                self.store_ebook_thumbnail(thumbnail_path, ebook_cover)
                self.log('✓ Fixed: %s\n  └─[%s] %s' %
                    (thumbnail_name, ebook_type, ebook.name))
                self.conquest_jobs += 1
                del thumbnails[ebook_asin]
            elif ebook_type == 'EBOK' and ebook_asin is not None:
                thumbnail_name = self.get_thumbnail_name(ebook_asin, ebook_type)
                thumbnail_path = os.path.join(thumbnails_path, thumbnail_name)
                if not os.path.exists(thumbnail_path):
                    self.store_ebook_thumbnail(thumbnail_path, ebook_cover)
                    self.log('✓ Generated: %s\n  └─[%s] %s' %
                        (thumbnail_name, ebook_type, ebook.name))
                    self.conquest_jobs += 1

        self.failure_jobs['cover_errors'] = [Path(thumbnail).name for
            thumbnail in thumbnails.values()]

        self.print_progress(0)


    def fix_ebook_thumbnails(self, documents_path, thumbnails_path):
        self.log('Checking damaged ebook covers:', True)
        thumbnails = self.get_damaged_thumbnails(thumbnails_path)

        if len(thumbnails) > 1:
            for thumbnail in thumbnails:
                self.log('- %s' % Path(thumbnail).name)
        else:
            self.log('- No damaged ebook cover detected.')

        self.log('Fixing damaged or missing ebook covers:', True)

        self.conquest_jobs = 0
        self.failure_jobs = {
            'cover_errors': [],
            'ebook_errors': [],
        }

        # Only for KUAL extention
        if self.db_access:
            self.fix_via_db(thumbnails_path)
        else:
            self.fix_via_path(thumbnails, documents_path, thumbnails_path)

        if self.failure_jobs is None:
            self.log('- No ebook cover to fix.')
            return

        if any(len(job) > 0 for job in self.failure_jobs.values()):
            if len(self.failure_jobs['cover_errors']) > 0:
                self.log('- These damaged covers have no corresponding ebook.')
                for job in self.failure_jobs['cover_errors']:
                    self.log('* %s' % job)

            if len(self.failure_jobs['ebook_errors']) > 0:
                self.log(
                    '- These ebooks have no covers.'
                )
                for job in self.failure_jobs['ebook_errors']:
                    self.log('! %s' % job)
        elif self.conquest_jobs > 0:
            self.log('✓ All ebook covers were fixed.')
        else:
            self.log('- No ebook cover need to fix.')


    def clean_orphan_thumbnails(self, documents_path, thumbnails_path):
        """清理所有无效封面：孤立封面（无对应电子书）+ 损坏/占位封面。"""
        self.log('Analysing invalid ebook covers:', True)

        thumbnails = self.get_ebook_thumbnails_via_path(thumbnails_path)

        if self.db_access:
            thumbnails = set(thumbnails.values()) \
                - set(self.get_ebook_thumbnails_via_db())
        else:
            ebook_list = self.get_ebook_list_via_path(documents_path)
            for ebook in ebook_list:
                self.print_progress(len(ebook_list))
                ebook_asin, ebook_type, ebook_cover = \
                    self.get_ebook_metadata(ebook)
                if ebook_type == 'EBOK' and ebook_asin in thumbnails.keys():
                    del thumbnails[ebook_asin]
            thumbnails = thumbnails.values()

        self.print_progress(0)

        def safe_delete(p):
            """兼容 Python 3.5+ 的删除（missing_ok 参数直到 3.8 才有）。"""
            try:
                os.remove(p)
                return True
            except OSError:
                return False

        deleted = 0
        for thumbnail in thumbnails:
            thumbnail_path = Path(thumbnail)
            if safe_delete(str(thumbnail_path)):
                self.log('✓ Delete orphan: %s' % thumbnail_path.name)
                deleted += 1

        # 损坏 / 占位（小于 2KB）的封面同样属于无效封面文件
        for asin, p in self.get_damaged_thumbnails(thumbnails_path).items():
            if safe_delete(p):
                self.log('✓ Delete damaged: %s' % Path(p).name)
                deleted += 1

        if deleted > 0:
            self.log('✓ %s invalid cover file(s) deleted.' % deleted)
        else:
            self.log('- No invalid cover detected.')


    def get_kindle_path(self, path):
        return (
            os.path.join(path, 'documents'),
            os.path.join(path, 'system', 'thumbnails')
        )


    def is_kindle_root(self, path):
        for path in self.get_kindle_path(path):
            if os.path.exists(path) is False:
                return False
        return True


    def get_kindle_root_automatically(self):
        drives = []
        roots = []

        if sys.platform.startswith('win'):
            drives = ['%s:\\' % s.upper() for s in string.ascii_lowercase[:26]]
            drives.reverse()
        elif sys.platform.startswith('darwin'):
            drives = glob.glob('/Volumes/*')
        elif sys.platform.startswith('linux'):
            # Kindle 本身运行 Linux：U 盘可见区挂载在 /mnt/us。
            # 旧版未覆盖 linux，导致不带路径参数时自动探测永远返回空。
            drives = ['/mnt/us', '/mnt/base-us']

        for drive in drives:
            path = os.path.join('%s' % drive)
            if self.is_kindle_root(path):
                roots.append(path)

        return roots


    # fix|clean
    def handle(self, action='fix', roots=None):
        if not sys.version_info >= (3, 5):
            self.log(
                'Required Python version >= 3.5\n' +
                'You can download here: https://www.python.org/downloads/'
            )
            return

        # roots 支持 None / 字符串 / 字符串列表；None 或空则自动探测。
        # 旧版用可变默认参数 roots=[]，且传入 None 时会被包成 [None]，
        # 随后 os.path.join(None, ...) 抛 TypeError。这里统一归一化。
        if roots is None:
            roots = []
        elif isinstance(roots, str):
            roots = [roots]
        else:
            roots = [r for r in roots if r]

        if len(roots) < 1:
            roots = self.get_kindle_root_automatically()

        if len(roots) < 1:
            self.log('You need choose a Kindle root directory first.')
            return

        for root in roots:
            if not root or not isinstance(root, str):
                self.log('Kindle root directory can not be empty.')
                continue

            if not self.is_kindle_root(root):
                self.log('%s is not a kindle root directory.' % root)
                continue

            self.log('Processing Kindle device: %s' % root)

            documents_path, thumbnails_path = self.get_kindle_path(root)

            if action == 'fix':
                self.fix_ebook_thumbnails(documents_path, thumbnails_path)
            elif action == 'clean':
                self.clean_orphan_thumbnails(documents_path, thumbnails_path)
            else:
                self.log('Wrong action.')
                return

            self.log('All jobs done.', True)
            self.log('\n')


    def __del__(self):
        if (self.db_access):
            self.db_connection.commit()
            self.db_connection.close()
