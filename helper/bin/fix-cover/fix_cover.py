#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import argparse

from FixCover import FixCover

def main():
    parser = argparse.ArgumentParser(description=FixCover.description,
        formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument('path', nargs='?', default=None,
        help='Kindle root directories (optional)')
    parser.add_argument('-a', '--action', dest='action',
        default='fix', choices=['fix', 'clean'],
        help='Specify an action to process ebook cover (default: fix)')
    parser.add_argument('--net', dest='net', default=False,
        action='store_true',
        help='Fetch missing covers from online providers (Open Library, '
             'Google Books, Amazon, Douban).')
    parser.add_argument('--missing-only', dest='missing_only', default=False,
        action='store_true',
        help='With --net: only try ebooks whose cover is missing or damaged; '
             'skip books that already have a valid thumbnail.')
    parser.add_argument('--speed', dest='speed', default=False,
        action='store_true',
        help='With --net: probe providers and try the fastest source first.')

    args = parser.parse_args()

    def _progress_logger(text):
        """Emit progress to stdout so the caller can capture it.

        The KUAL shell wrapper keeps this in a temp file and only surfaces
        the last lines when the process is killed (rc=137), which tells us
        exactly which ebook exhausted the device's memory.
        """
        try:
            print(text)
            sys.stdout.flush()
        except Exception:
            pass

    fix_cover = FixCover(logger=_progress_logger, net=args.net,
                         speed=args.speed, missing_only=args.missing_only)
    fix_cover.handle(args.action, args.path)

if __name__ == '__main__':
    main()
