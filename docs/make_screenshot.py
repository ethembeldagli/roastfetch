#!/usr/bin/env python3
"""Render `roastfetch --demo` into docs/screenshot.png (a terminal-window image).

Needs rsvg-convert or gdk-pixbuf-thumbnailer (librsvg). Run: python3 docs/make_screenshot.py
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = "'Fira Code', 'JetBrains Mono', 'DejaVu Sans Mono', monospace"
SIZE, CW, LH, PAD, BAR = 18, 10.8, 25, 28, 44
BG, FG = "#0f1117", "#e6e6e6"


def fonts_from_host() -> None:
    """Inside a distrobox, also use the host's fonts."""
    if os.path.isdir("/run/host/usr/share/fonts") and "FONTCONFIG_FILE" not in os.environ:
        tmp = tempfile.mkdtemp(prefix="roastfetch-fc-")
        conf = os.path.join(tmp, "fonts.conf")
        with open(conf, "w") as f:
            f.write('<?xml version="1.0"?><fontconfig><include ignore_missing="yes">/etc/fonts/fonts.conf</include>'
                    f'<dir>/run/host/usr/share/fonts</dir><cachedir>{tmp}</cachedir></fontconfig>')
        os.environ["FONTCONFIG_FILE"] = conf


def parse(line: str) -> list[tuple[str, str, bool, bool]]:
    """ANSI line -> [(text, colour, bold, dim)]."""
    out, colour, bold, dim, pos = [], FG, False, False, 0
    for m in re.finditer(r"\x1b\[([0-9;]*)m", line):
        if m.start() > pos:
            out.append((line[pos:m.start()], colour, bold, dim))
        codes = [int(c) for c in m.group(1).split(";") if c] or [0]
        i = 0
        while i < len(codes):
            c = codes[i]
            if c == 0:
                colour, bold, dim = FG, False, False
            elif c == 1:
                bold = True
            elif c == 2:
                dim = True
            elif c == 38 and codes[i + 1:i + 2] == [2]:
                colour = "#%02x%02x%02x" % tuple(codes[i + 2:i + 5])
                i += 4
            i += 1
        pos = m.end()
    if pos < len(line):
        out.append((line[pos:], colour, bold, dim))
    return out


def main() -> None:
    fonts_from_host()
    env = dict(os.environ, COLORTERM="truecolor", COLUMNS="100")
    out = subprocess.run([sys.executable, os.path.join(ROOT, "roastfetch"), "--demo", "--seed", "4", "--color"],
                         capture_output=True, text=True, env=env, check=True).stdout.rstrip("\n").split("\n")
    rows = [parse(line) for line in out]
    cols = max(sum(len(t) for t, *_ in r) for r in rows)
    w = int(PAD * 2 + cols * CW + 24)
    h = int(BAR + PAD + len(rows) * LH + PAD - 6)

    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">',
           f'<rect width="{w}" height="{h}" rx="14" fill="{BG}"/>',
           f'<rect width="{w}" height="{BAR}" rx="14" fill="#1a1d27"/>',
           f'<rect y="{BAR - 14}" width="{w}" height="14" fill="#1a1d27"/>']
    for i, c in enumerate(("#ff5f57", "#febc2e", "#28c840")):
        svg.append(f'<circle cx="{24 + i * 22}" cy="{BAR / 2}" r="7" fill="{c}"/>')
    svg.append(f'<text x="{w / 2}" y="{BAR / 2 + 5}" font-family="{FONT}" font-size="14" fill="#8a8f9e" '
               f'text-anchor="middle">~ roastfetch</text>')
    for n, row in enumerate(rows):
        y = BAR + PAD + n * LH
        spans = "".join(
            f'<tspan fill="{c}"{" font-weight=\"700\"" if b else ""}{" fill-opacity=\"0.55\"" if d else ""}>'
            f'{escape(t)}</tspan>' for t, c, b, d in row)
        svg.append(f'<text x="{PAD}" y="{y}" font-family="{FONT}" font-size="{SIZE}" xml:space="preserve">{spans}</text>')
    svg.append("</svg>")

    tmp = tempfile.mkdtemp()
    svg_path = os.path.join(tmp, "shot.svg")
    with open(svg_path, "w", encoding="utf-8") as f:
        f.write("\n".join(svg))
    png = os.path.join(ROOT, "docs", "screenshot.png")
    if shutil.which("rsvg-convert"):
        subprocess.run(["rsvg-convert", "-o", png, svg_path], check=True)
    else:
        subprocess.run(["gdk-pixbuf-thumbnailer", "-s", str(max(w, h)), svg_path, png], check=True)
    print(png, f"{w}x{h}")


if __name__ == "__main__":
    main()
