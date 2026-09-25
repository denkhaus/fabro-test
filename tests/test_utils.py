import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from utils import add, clamp, slugify  # noqa: E402


class AddTests(unittest.TestCase):
    def test_add_positive(self):
        self.assertEqual(add(2, 3), 5)

    def test_add_zero(self):
        self.assertEqual(add(0, 0), 0)


class ClampTests(unittest.TestCase):
    def test_clamp_inside_range(self):
        self.assertEqual(clamp(5, 0, 10), 5)

    def test_clamp_below_low(self):
        self.assertEqual(clamp(-3, 0, 10), 0)

    def test_clamp_above_high(self):
        self.assertEqual(clamp(15, 0, 10), 10)

    def test_clamp_low_equals_high(self):
        self.assertEqual(clamp(7, 5, 5), 5)


class SlugifyTests(unittest.TestCase):
    def test_normal_phrase(self):
        self.assertEqual(slugify("Hello World"), "hello-world")

    def test_punctuation_runs_collapse_to_one_hyphen(self):
        self.assertEqual(slugify("Hello,   World!!!"), "hello-world")

    def test_leading_trailing_separators_stripped(self):
        self.assertEqual(slugify("--Hello World!!"), "hello-world")

    def test_all_separators_yield_empty_string(self):
        self.assertEqual(slugify(" -- !! -- "), "")


if __name__ == "__main__":
    unittest.main()
