#!/usr/bin/env python
# -*- coding:utf-8 -*-
"""清理无用 SDR 文件夹 / 截图（不带日志）。

用法：
    sdr_cleaner.py [--sdr] [--no-sdr] [--shot]

    --sdr      清理无对应书籍的 .sdr / .dir 文件夹（默认）
    --no-sdr   不清理 SDR 文件夹
    --shot     清理根目录截图（screenshot*.png / wininfo_screenshot*.txt）

通过 SDRCLEANER_BASE 环境变量可覆盖 Kindle 根目录（仅供离线测试）。
兼容 Python 2.7 / 3.5+。
"""

import os
import sys
import glob
import shutil

if sys.version_info.major < 3:
    reload(sys)
    sys.setdefaultencoding('utf-8')


# 视为「电子书」的扩展名（含点、全小写）
BOOK_EXTS = frozenset((
    '.azw', '.azw3', '.azw4', '.mobi', '.prc', '.pobi',
    '.pdf', '.txt', '.epub', '.kfx',
))


def parse_args(argv):
    opts = {'sdr': True, 'shot': False}
    i = 1
    while i < len(argv):
        a = argv[i]
        if a == '--sdr':
            opts['sdr'] = True
        elif a == '--no-sdr':
            opts['sdr'] = False
        elif a == '--shot':
            opts['shot'] = True
        i += 1
    return opts


def _has_book(stem, books):
    """stem 是否有对应的电子书文件。books 为该目录下所有书籍文件名集合。"""
    for name in books:
        base, ext = os.path.splitext(name)
        if ext.lower() in BOOK_EXTS and base == stem:
            return True
    return False


def clean_shots(kindle_path):
    """清理根目录下的截图文件。"""
    for name in os.listdir(kindle_path):
        p = os.path.join(kindle_path, name)
        if not os.path.isfile(p):
            continue
        if (name.startswith('screenshot') and name.lower().endswith('.png')) or \
           (name.startswith('wininfo_screenshot') and name.lower().endswith('.txt')):
            try:
                os.remove(p)
            except OSError:
                pass


def clean_sdr(documents_path):
    """删除没有对应电子书的 .sdr / .sdr.dir 文件夹。"""
    for root, _dirs, files in os.walk(documents_path):
        books = set(files)
        for name in list(_dirs):
            low = name.lower()
            if low.endswith('.sdr'):
                stem = name[:-4]
            elif low.endswith('.sdr.dir'):
                stem = name[:-8]
            else:
                continue
            if not _has_book(stem, books):
                try:
                    shutil.rmtree(os.path.join(root, name))
                except OSError:
                    pass


def onProcess(kindlePath, opts):
    documentsPath = os.path.join(kindlePath, 'documents')
    if not os.path.isdir(documentsPath):
        return
    if opts.get('shot'):
        clean_shots(kindlePath)
    if opts.get('sdr'):
        clean_sdr(documentsPath)


if __name__ == '__main__':
    base = os.environ.get('SDRCLEANER_BASE', '/mnt/us/')
    onProcess(base, parse_args(sys.argv))
