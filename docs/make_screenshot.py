#!/usr/bin/env python3
"""Render `roastfetch --demo` into docs/screenshot.png (a terminal-window image).

Extra arguments go to roastfetch, and a path ending in .png sets the output:
    python3 docs/make_screenshot.py --logo bazzite /tmp/bazzite.png

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
BASIC = ["#3b4048", "#ff5f56", "#5af78e", "#f3f99d", "#57c7ff", "#ff6ac1", "#9aedfe", "#e6e6e6",
         "#686868", "#ff6e67", "#5ffa68", "#fffc67", "#6871ff", "#ff77ff", "#60fdff", "#ffffff"]


def fonts_from_host() -> None:
    """Inside a distrobox, also use the host's fonts."""
    if os.path.isdir("/run/host/usr/share/fonts") and "FONTCONFIG_FILE" not in os.environ:
        tmp = tempfile.mkdtemp(prefix="roastfetch-fc-")
        conf = os.path.join(tmp, "fonts.conf")
        with open(conf, "w") as f:
            f.write('<?xml version="1.0"?><fontconfig><include ignore_missing="yes">/etc/fonts/fonts.conf</include>'
                    f'<dir>/run/host/usr/share/fonts</dir><cachedir>{tmp}</cachedir></fontconfig>')
        os.environ["FONTCONFIG_FILE"] = conf


def parse(line: str) -> list[tuple[str, str, str | None, bool, bool]]:
    """ANSI line -> [(text, fg, bg, bold, dim)]."""
    out, fg, bg, bold, dim, pos = [], FG, None, False, False, 0
    for m in re.finditer(r"\x1b\[([0-9;]*)m", line):
        if m.start() > pos:
            out.append((line[pos:m.start()], fg, bg, bold, dim))
        codes = [int(c) for c in m.group(1).split(";") if c] or [0]
        i = 0
        while i < len(codes):
            c = codes[i]
            if c == 0:
                fg, bg, bold, dim = FG, None, False, False
            elif c == 1:
                bold = True
            elif c == 2:
                dim = True
            elif 30 <= c <= 37 or 90 <= c <= 97:
                fg = BASIC[c - 30 if c < 90 else c - 90 + 8]
            elif c == 39:
                fg = FG
            elif c == 38 and codes[i + 1:i + 2] == [5]:
                n = codes[i + 2]
                fg = BASIC[n] if n < 16 else FG
                i += 2
            elif c in (38, 48) and codes[i + 1:i + 2] == [2]:
                colour = "#%02x%02x%02x" % tuple(codes[i + 2:i + 5])
                if c == 38:
                    fg = colour
                else:
                    bg = colour
                i += 4
            i += 1
        pos = m.end()
    if pos < len(line):
        out.append((line[pos:], fg, bg, bold, dim))
    return out


def draw_row(row, y_top: float) -> list[str]:
    """Block characters become exact rectangles (so they tile seamlessly), the rest is text."""
    els, col = [], 0
    run, run_col, run_style = "", 0, None

    def flush():
        if run.strip():
            fg, bold, dim = run_style
            w = ' font-weight="700"' if bold else ""
            o = ' fill-opacity="0.55"' if dim else ""
            els.append(f'<text x="{PAD + run_col * CW:.1f}" y="{y_top + LH * 0.74:.1f}" font-family="{FONT}" '
                       f'font-size="{SIZE}" fill="{fg}"{w}{o} xml:space="preserve">{escape(run)}</text>')

    for text, fg, bg, bold, dim in row:
        for ch in text:
            x = PAD + col * CW
            if ch in "█▀▄":
                flush()
                run = ""
                half = LH / 2
                if ch == "█":
                    els.append(f'<rect x="{x:.1f}" y="{y_top:.1f}" width="{CW + .5:.1f}" height="{LH + .5:.1f}" fill="{fg}"/>')
                else:
                    top, bottom = (fg, bg) if ch == "▀" else (bg, fg)
                    for colour, dy in ((top, 0), (bottom, half)):
                        if colour:
                            els.append(f'<rect x="{x:.1f}" y="{y_top + dy:.1f}" width="{CW + .5:.1f}" '
                                       f'height="{half + .5:.1f}" fill="{colour}"/>')
            else:
                if not run or (fg, bold, dim) != run_style:
                    flush()
                    run, run_col, run_style = "", col, (fg, bold, dim)
                run += ch
            col += 1
    flush()
    return els


def main() -> None:
    fonts_from_host()
    env = dict(os.environ, COLORTERM="truecolor", COLUMNS="100")
    extra = [a for a in sys.argv[1:] if not a.endswith(".png")]
    target = next((a for a in sys.argv[1:] if a.endswith(".png")), os.path.join(ROOT, "docs", "screenshot.png"))
    out = subprocess.run([sys.executable, os.path.join(ROOT, "roastfetch"), "--demo", "--seed", "4", "--color", *extra],
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
        svg += draw_row(row, BAR + PAD - LH * 0.74 + n * LH)
    svg.append("</svg>")

    tmp = tempfile.mkdtemp()
    svg_path = os.path.join(tmp, "shot.svg")
    with open(svg_path, "w", encoding="utf-8") as f:
        f.write("\n".join(svg))
    png = target
    if shutil.which("rsvg-convert"):
        subprocess.run(["rsvg-convert", "-o", png, svg_path], check=True)
    else:
        subprocess.run(["gdk-pixbuf-thumbnailer", "-s", str(max(w, h)), svg_path, png], check=True)
    print(png, f"{w}x{h}")


if __name__ == "__main__":
    main()
