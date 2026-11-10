"""Standard-library tests for the Python reference. No PostgreSQL connection needed."""
import unittest
from decimal import Decimal
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from reference.billing_reference import calculate_invoice_total  # noqa: E402


class BillingReferenceTests(unittest.TestCase):
    def test_ten_percent(self):
        self.assertEqual(calculate_invoice_total("200", "10"), Decimal("180.00"))

    def test_zero_percent(self):
        self.assertEqual(calculate_invoice_total("200", "0"), Decimal("200.00"))

    def test_full_discount(self):
        self.assertEqual(calculate_invoice_total("200", "100"), Decimal("0.00"))

    def test_fractional_percent(self):
        self.assertEqual(calculate_invoice_total("149.95", "12.5"), Decimal("131.21"))

    def test_final_rounding(self):
        self.assertEqual(calculate_invoice_total("19.99", "15"), Decimal("16.99"))

    def test_small_half_cent_rounding(self):
        self.assertEqual(calculate_invoice_total("0.05", "10"), Decimal("0.05"))

    def test_invalid_inputs(self):
        for subtotal, discount in [
            ("-1", "10"), ("200", "-1"), ("200", "101"),
            ("1000001", "10"), ("NaN", "10"), ("200", "Infinity"),
            (None, "10"),
        ]:
            with self.subTest(subtotal=subtotal, discount=discount):
                with self.assertRaises(ValueError):
                    calculate_invoice_total(subtotal, discount)


if __name__ == "__main__":
    unittest.main()
