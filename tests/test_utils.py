import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from utils import add  # noqa: E402


class AddTests(unittest.TestCase):
    def test_add_positive(self):
        self.assertEqual(add(2, 3), 5)

    def test_add_zero(self):
        self.assertEqual(add(0, 0), 0)


if __name__ == "__main__":
    unittest.main()
