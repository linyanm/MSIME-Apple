#!/usr/bin/env python3
"""Print the -only-testing arguments for one slice of the enumerated interface suite.

Reads the JSON produced by `xcodebuild -enumerate-tests -test-enumeration-format json` and deals
the cases out one runner at a time in identifier order. Neighbouring identifiers share a prefix and
usually exercise the same screen, so dealing them to different runners keeps the expensive screens
away from a single slice.

The target is filtered here rather than trusted to `-only-testing`. Xcode 26.3 enumerates the whole
scheme regardless of that flag, which handed every slice a mix of interface and unit cases.
"""

import json
import os
import sys


def identifiers(payload, target):
    prefix = target + "/"
    found = []

    def walk(node):
        if isinstance(node, dict):
            identifier = node.get("identifier")
            if isinstance(identifier, str) and identifier.endswith("()") and identifier.startswith(prefix):
                found.append(identifier)
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)

    walk(payload)
    return sorted(set(found))


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: select_ui_test_shard.py <enumeration.json> <test-target>")

    index = int(os.environ.get("MSIME_UI_SHARD_INDEX", "1"))
    count = int(os.environ.get("MSIME_UI_SHARD_COUNT", "1"))
    if count < 1 or not 1 <= index <= count:
        raise SystemExit(f"Slice {index}/{count} is out of range")

    with open(sys.argv[1], encoding="utf-8") as handle:
        payload = json.load(handle)

    target = sys.argv[2]
    cases = identifiers(payload, target)
    if not cases:
        raise SystemExit(f"The enumeration listed no {target} cases; the slice would run empty")
    if len(cases) < count:
        raise SystemExit(f"{len(cases)} cases cannot fill {count} slices")

    for position, case in enumerate(cases):
        if position % count == index - 1:
            print("-only-testing:" + case.removesuffix("()"))


if __name__ == "__main__":
    main()
