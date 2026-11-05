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

    fix_cover = FixCover(logger=None, net=args.net, speed=args.speed,
                         missing_only=args.missing_only)
    fix_cover.handle(args.action, args.path)

if __name__ == '__main__':
    main()
