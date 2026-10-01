#!/usr/bin/env python3
"""Build the my-* Neovim tutorials from tutor/src/*.tutor.src.

Exercise lines in a source file are written as
    {{start text ||| expected text}}
on a line of their own (keep any leading spaces outside the braces). The build
writes tutor/en/<name>.tutor with just "start text" on that line, and
tutor/en/<name>.tutor.json mapping its line number to "expected text"; Neovim's
:Tutor then shows ✗ until the line matches, and ✓ after.

Run after editing a lesson:  python3 ~/.config/nvim/tutor/build.py
"""
import json, pathlib, re

here = pathlib.Path(__file__).resolve().parent
pat = re.compile(r"^(\s*)\{\{(.*?) \|\|\| (.*?)\}\}\s*$")
for src in sorted((here / "src").glob("*.tutor.src")):
    name = src.name[: -len(".tutor.src")]
    out, expect = [], {}
    for n, line in enumerate(src.read_text().splitlines(), start=1):
        m = pat.match(line)
        if m:
            out.append(m.group(1) + m.group(2))
            expect[str(n)] = m.group(1) + m.group(3)
        else:
            out.append(line)
    (here / "en" / f"{name}.tutor").write_text("\n".join(out) + "\n")
    (here / "en" / f"{name}.tutor.json").write_text(json.dumps({"expect": expect}, indent=2) + "\n")
    print(f"{name}: {len(out)} lines, {len(expect)} exercises")
