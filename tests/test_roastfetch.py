"""Stdlib-only tests. Run with:  python3 -m unittest discover -s tests -v"""

import importlib.machinery
import importlib.util
import io
import os
import random
import tempfile
import time
import unittest
from contextlib import redirect_stdout

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_loader = importlib.machinery.SourceFileLoader("roastfetch", os.path.join(ROOT, "roastfetch"))
_spec = importlib.util.spec_from_loader("roastfetch", _loader)
rf = importlib.util.module_from_spec(_spec)
_loader.exec_module(rf)


class Collect(unittest.TestCase):
    def test_collect_never_crashes_and_is_fast(self):
        start = time.monotonic()
        facts = rf.collect()
        self.assertLess(time.monotonic() - start, 2.0)
        self.assertTrue(facts["distro"])
        self.assertTrue(facts["kernel"])

    def test_real_run_prints_a_roast(self):
        buf = io.StringIO()
        with redirect_stdout(buf):
            self.assertEqual(rf.main(["--builtin", "--no-color", "--seed", "1"]), 0)
        self.assertIn("roasted:", buf.getvalue())
        self.assertIn("Doneness:", buf.getvalue())

    def test_history_parsing(self):
        with tempfile.TemporaryDirectory() as home:
            with open(os.path.join(home, ".bash_history"), "w") as f:
                f.write("#1736000000\nsudo dnf install htop\ngti status\ngit status\ngit push\nls | grep x\n")
            old = rf.HOME
            rf.HOME = home
            try:
                h = rf.history()
            finally:
                rf.HOME = old
        self.assertEqual(h["total"], 5)
        self.assertTrue(h["timed"])
        self.assertEqual(h["sudo"], 1)
        self.assertEqual(h["top"], "git")
        self.assertEqual(h["typo"], ("gti", 1))


class Roasts(unittest.TestCase):
    def test_demo_is_deterministic_with_seed(self):
        a = [t for _, t in rf.choose(rf.roasts(dict(rf.DEMO), random.Random(4)), 5, random.Random(4))]
        b = [t for _, t in rf.choose(rf.roasts(dict(rf.DEMO), random.Random(4)), 5, random.Random(4))]
        self.assertEqual(a, b)
        self.assertEqual(len(a), 5)

    def test_every_roast_fits_a_screenshot(self):
        for seed in range(60):
            for _, text in rf.roasts(dict(rf.DEMO), random.Random(seed)):
                self.assertLessEqual(len(text), 90, text)

    def test_distro_roast_always_present(self):
        for did in ("arch", "ubuntu", "fedora", "bazzite", "nixos", "somethingnew"):
            facts = dict(rf.DEMO, distro_id=did, distro=did.title())
            texts = " ".join(t for _, t in rf.roasts(facts, random.Random(0)))
            self.assertTrue(texts)
        facts = dict(rf.DEMO, distro_id="somethingnew", distro="SomethingNew")
        self.assertIn("SomethingNew", " ".join(t for _, t in rf.roasts(facts, random.Random(0))))

    def test_handheld_beats_laptop_joke(self):
        facts = dict(rf.DEMO, model="ASUS ROG Xbox Ally X")
        texts = [t for _, t in rf.roasts(facts, random.Random(0))]
        self.assertTrue(any("Xbox handheld" in t for t in texts))
        self.assertFalse(any("RGB keyboard" in t for t in texts))

    def test_verdict_bounds(self):
        self.assertEqual(rf.verdict([(5, "x")] * 5), ("Charcoal", 10))
        self.assertEqual(rf.verdict([(1, "x")] * 5)[1], 2)

    def test_plain_render_has_no_escape_codes(self):
        chosen = rf.choose(rf.roasts(dict(rf.DEMO), random.Random(1)), 5, random.Random(1))
        out = rf.render(dict(rf.DEMO), chosen, rf.Paint(False), True, True)
        self.assertNotIn("\x1b[", out)
        self.assertIn("you@archbox", out)

    def test_pci_lookup_skips_comments(self):
        ids = ("1002  Advanced Micro Devices, Inc. [AMD/ATI]\n\t1234  Other\n"
               "# Used in the Steam Deck OLED\n\t150e  Strix [Radeon 880M / 890M]\n"
               "8086  Intel Corporation\n\t150e  Not this one\n")
        self.assertEqual(rf.pci_device_name(ids, "1002", "150e"), "Radeon 880M / 890M")
        self.assertEqual(rf.pci_device_name(ids, "1002", "ffff"), "")

    def test_claude_terminal_gets_roasted(self):
        texts = " ".join(t for _, t in rf.roasts(dict(rf.DEMO, terminal="Claude"), random.Random(0)))
        self.assertIn("AI", texts)

    def test_logo_falls_back_to_pixel_art_without_fetch_tools(self):
        real_which = rf.shutil.which
        rf.shutil.which = lambda name: None
        try:
            self.assertEqual(rf.borrowed_logo(None, False), [])
            chosen = rf.choose(rf.roasts(dict(rf.DEMO), random.Random(1)), 3, random.Random(1))
            out = rf.render(dict(rf.DEMO), chosen, rf.Paint(False), True, True)
        finally:
            rf.shutil.which = real_which
        self.assertIn("\u2588", out)  # half-block pixel art drawn
        self.assertIn("you@archbox", out)

    def test_borrowed_logo_is_cleaned(self):
        real_run, real_which = rf.run, rf.shutil.which
        rf.shutil.which = lambda name: "/usr/bin/" + name
        rf.run = lambda args, timeout=2: "\n\x1b[?25l\x1b[1m\x1b[34m  /\\\n /  \\\n/____\\\x1b[m\n\n"
        try:
            plain = rf.borrowed_logo("arch", False)
            coloured = rf.borrowed_logo("arch", True)
        finally:
            rf.run, rf.shutil.which = real_run, real_which
        self.assertEqual(plain, ["  /\\", " /  \\", "/____\\"])
        self.assertTrue(all(line.endswith("\x1b[0m") for line in coloured))
        self.assertNotIn("?25l", "".join(coloured))

    def test_finds_and_expands_the_users_fetch_alias(self):
        with tempfile.TemporaryDirectory() as root, tempfile.TemporaryDirectory() as home:
            os.makedirs(os.path.join(root, "etc/profile.d"))
            with open(os.path.join(root, "etc/profile.d/distro-fetch.sh"), "w") as f:
                f.write("alias neofetch='/usr/bin/fastfetch --color $(echo 35) -c /etc/fetch.jsonc'\n")
            with open(os.path.join(home, ".bashrc"), "w") as f:
                f.write("alias fastfetch='fastfetch --logo small'\n")
            old = rf.HOST, rf.HOME
            rf.HOST, rf.HOME = root, home
            try:
                alias = rf.find_alias("neofetch", "bash")
                argv = rf.expand_alias(alias, fish=False, via_host=False)
                self.assertEqual(rf.find_alias("fastfetch", "bash"), "fastfetch --logo small")
                self.assertIsNone(rf.find_alias("neofetch", "fish"))  # bash aliases don't apply to fish
            finally:
                rf.HOST, rf.HOME = old
        self.assertEqual(argv, ["/usr/bin/fastfetch", "--color", "35", "-c", "/etc/fetch.jsonc"])

    def test_vdf(self):
        d = rf.parse_vdf('"A" { "B" { "Playtime" "12" } }')
        self.assertEqual(d["a"]["b"]["playtime"], "12")


if __name__ == "__main__":
    unittest.main()
