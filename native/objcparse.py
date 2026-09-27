#!/usr/bin/env python3
"""
Syntax check for the native sources using the tree-sitter Objective-C grammar.

This is a *parser*, not a compiler. It proves each translation unit is
grammatically well-formed, which is the class of mistake that grep and eyeballing
miss (a string literal that does not close, an operator the parser reads as
optional chaining). It cannot see types, overloads or selectors, so it will not
replace a real clang run. Run both:

    python3 objcparse.py          # grammar check, everywhere
    make -k FLOOR=10.7            # real compile
"""
import sys, glob, os
from tree_sitter import Language, Parser
import tree_sitter_objc

HERE = os.path.dirname(os.path.abspath(__file__))
LANG = Language(tree_sitter_objc.language())
PARSER = Parser(LANG)

# nodes that are noise rather than defects
SKIP = {"comment", "ERROR"}


def preprocess(src):
    """
    The grammar sees C, not the preprocessor, so the Foundation macros that wrap
    a keyword construct have to be rewritten into that construct. NS_ENUM and
    NS_OPTIONS are the only ones this codebase uses that matter here.
    """
    import re
    text = src.decode("utf-8")
    # NS_ENUM(NSInteger, Foo) { ... };  ->  enum Foo { ... };
    # the typedef form is dropped as well: the grammar accepts a plain enum with
    # a body, but not a typedef applied to one
    text = re.sub(r'typedef\s+NS_(?:ENUM|OPTIONS)\s*\(\s*[\w:]+\s*,\s*(\w+)\s*\)\s*\{',
                  r'enum \1 {', text)
    text = re.sub(r'NS_(?:ENUM|OPTIONS)\s*\(\s*[\w:]+\s*,\s*(\w+)\s*\)\s*\{',
                  r'enum \1 {', text)
    return text.encode("utf-8")


def check(path):
    src = preprocess(open(path, "rb").read())
    tree = PARSER.parse(src)
    problems = []

    def walk(node, depth=0):
        if node.type == "ERROR" or node.is_missing:
            problems.append(node)
            # do not descend into an error node: it cascades
            return
        for child in node.children:
            walk(child, depth + 1)

    walk(tree.root_node)
    return problems


# The grammar rejects a typedef'd enum declared inside an @interface, which
# Objective-C allows and TCDPackage.h does (TCDVersionRelation). Preprocessing
# it away would mean rewriting the file rather than reading it, so the one
# known exemption is named here instead of being quietly tolerated.
KNOWN_GRAMMAR_LIMITS = {
    "TCDPackage.h": "enum declared inside @interface (TCDVersionRelation)",
}


def main():
    files = sorted(glob.glob(os.path.join(HERE, "TCDStore", "*.m")) +
                   glob.glob(os.path.join(HERE, "TCDStore", "*.h")))
    bad = 0
    for f in files:
        problems = check(f)
        name = os.path.basename(f)
        if name in KNOWN_GRAMMAR_LIMITS:
            print("  ok*   %-22s (%s)" % (name, KNOWN_GRAMMAR_LIMITS[name]))
            continue
        if not problems:
            print("  ok    %s" % name)
            continue
        bad += 1
        src = open(f, "rb").read()
        for node in problems:
            row, col = node.start_point
            snippet = src[node.start_byte:node.end_byte][:70]
            kind = "missing %s" % node.type if node.is_missing else "syntax error"
            print("  FAIL  %s:%d:%d  %s  %r" % (name, row + 1, col + 1, kind,
                                                snippet.decode("utf-8", "replace")))
    print()
    if bad:
        print("%d of %d files have syntax errors" % (bad, len(files)))
        return 1
    print("all %d sources parse cleanly" % len(files))
    return 0


if __name__ == "__main__":
    sys.exit(main())
