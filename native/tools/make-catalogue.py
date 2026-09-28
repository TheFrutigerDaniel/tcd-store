#!/usr/bin/env python3
"""
Turn the bundled demo package index into the catalogue.json that
TCDCatalogueManager loads at launch.

TCDCatalogueManager reads `catalogue.json` out of the main bundle and builds
TCDAppItem rows from it. Nothing in the tcd-store-beta base ever wrote that
file, so the grid came up empty on every launch and the only way to populate it
was to type entries into the catalogue editor by hand.

This script derives that file from demo-index.txt, so the grid shows the same
packages the install pipeline can already parse. One source of truth: the
Debian-style index.

Run it after editing demo-index.txt:

    python3 native/tools/make-catalogue.py

and commit the regenerated native/TCDStore/catalogue.json alongside it.

Note on downloadURL: it is emitted as an empty string. The demo index points
every Filename at a `demo/` directory that does not exist, so there is nothing
real to fetch. Populating the grid and performing an install are separate
pieces of work -- see TCDInstaller for the second.
"""

import json
import os
import re
import sys
from collections import OrderedDict

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
INDEX = os.path.join(ROOT, "TCDStore", "demo-index.txt")
OUT = os.path.join(ROOT, "TCDStore", "catalogue.json")

# Stands in for artwork. The demo source ships no icons, and inventing a
# per-package tint gives the grid some rhythm without pretending to have art.
PALETTE = [
    [0x4A, 0x90, 0xE2], [0x6F, 0xB2, 0xD6], [0x5D, 0xA5, 0xBC],
    [0x7F, 0xA8, 0xC9], [0x4B, 0x87, 0xA8], [0x8C, 0xB4, 0xCE],
    [0x5A, 0x93, 0xB0], [0x6B, 0xA3, 0xC1], [0x44, 0x7D, 0xA8],
]


def parse(path):
    """Group the index into one entry per package, collecting every version.

    The index carries one stanza per package/version pair, so a package with
    three versions appears three times. The version list is what the card's
    popup offers, so the entries have to be merged, not deduped by name.
    """
    order = []
    packages = OrderedDict()

    stanza = {}
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.rstrip("\n")
            if not line.strip():
                if stanza.get("Package"):
                    _absorb(packages, order, stanza)
                stanza = {}
                continue
            if line.startswith("#"):
                continue
            if ":" not in line:
                continue
            key, _, value = line.partition(":")
            stanza[key.strip()] = value.strip()
    if stanza.get("Package"):
        _absorb(packages, order, stanza)

    return [packages[k] for k in order]


def _absorb(packages, order, stanza):
    ident = stanza["Package"]
    if ident not in packages:
        packages[ident] = {
            "name": stanza.get("TCD-Name", ident),
            "developer": stanza.get("TCD-Developer", ""),
            "category": stanza.get("TCD-Section", "Other"),
            "versions": [],
        }
        order.append(ident)
    version = stanza.get("Version")
    if version and version not in packages[ident]["versions"]:
        packages[ident]["versions"].append(version)


def accent_for(ident):
    h = sum(ord(c) * (i + 1) for i, c in enumerate(ident))
    return PALETTE[h % len(PALETTE)]


def main():
    if not os.path.exists(INDEX):
        sys.exit("missing index: %s" % INDEX)

    entries = parse(INDEX)
    out = []
    for entry in entries:
        entries_with_accent = dict(entry)
        entries_with_accent["accentColor"] = accent_for(entry["name"])
        entries_with_accent["icon"] = ""
        entries_with_accent["downloadURL"] = ""
        out.append(entries_with_accent)

    ordered_keys = ["name", "developer", "category", "accentColor",
                    "versions", "downloadURL", "icon"]
    out = [OrderedDict((k, item[k]) for k in ordered_keys) for item in out]

    with open(OUT, "w", encoding="utf-8") as fh:
        json.dump(out, fh, indent=2, ensure_ascii=False)
        fh.write("\n")

    multi = sum(1 for i in out if len(i["versions"]) > 1)
    print("wrote %s: %d packages (%d with more than one version), %d categories"
          % (os.path.relpath(OUT, ROOT), len(out), multi,
             len({i["category"] for i in out})))


if __name__ == "__main__":
    main()
