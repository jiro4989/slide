#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys, re

def main():
    target_file = sys.argv[1]

    with open(target_file, "r") as f:
        body = f.read()

        # 見出し行のみ取得
        headings = [re.search(r'^##.*', l) for l in body.split("\n")]
        headings = [l.group(0) for l in headings if l != None]

        # 目次要素の取得
        contents = []
        for head in headings:
            # 見出しレベルは ## なので 2段階引く
            indent_level = len(re.search(r"^#+", head).group(0)) - 2
            indent = "  " * indent_level

            # Markdownのリスト記法に置換
            head = re.sub(r"#+\s*", indent + "* ", head)
            contents.append(head)

        s = "\n".join(contents)
        new_content = body.replace("[:contents]", s)

    with open(target_file, "w") as f:
        f.write(new_content)

if __name__ == '__main__':
    main()
