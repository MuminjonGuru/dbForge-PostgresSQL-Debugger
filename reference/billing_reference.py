"""Independent Python reference for the PostgreSQL billing demonstration.

No external dependencies or database access. Use as context for AI review and as
an independent check of the business rule. Percentages are expressed on 0-100 scale.
"""
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP

CENT = Decimal("0.01")
MAX_SUBTOTAL = Decimal("1000000")
HUNDRED = Decimal("100")


def calculate_invoice_total(subtotal: str | Decimal,
                            discount_pct: str | Decimal) -> Decimal:
    """Return an invoice total rounded to cents using exact decimal arithmetic.

    Examples:
        >>> calculate_invoice_total("200", "10")
        Decimal('180.00')
        >>> calculate_invoice_total("149.95", "12.5")
        Decimal('131.21')
    """
    try:
        amount = Decimal(str(subtotal))
        percentage = Decimal(str(discount_pct))
    except (InvalidOperation, ValueError) as exc:
        raise ValueError("Subtotal and discount must be numeric.") from exc

    if not amount.is_finite() or not percentage.is_finite():
        raise ValueError("Subtotal and discount must be finite.")
    if not (Decimal("0") <= amount <= MAX_SUBTOTAL):
        raise ValueError("Subtotal must be between 0 and 1,000,000.")
    if not (Decimal("0") <= percentage <= HUNDRED):
        raise ValueError("Discount must be between 0 and 100 percent.")

    discount_amount = amount * percentage / HUNDRED
    return (amount - discount_amount).quantize(CENT, rounding=ROUND_HALF_UP)


if __name__ == "__main__":
    samples = [("200", "10"), ("200", "0"), ("200", "100"), ("149.95", "12.5")]
    for amount, discount in samples:
        print(f"subtotal={amount}, discount={discount}%, total={calculate_invoice_total(amount, discount)}")
