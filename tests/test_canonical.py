import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "bench"))

from canonical import canonical_mark  # noqa: E402


class CanonicalMarkTests(unittest.TestCase):
    def test_returns_required_value(self):
        self.assertEqual(canonical_mark(), "canonical-ok-9004")


if __name__ == "__main__":
    unittest.main()
