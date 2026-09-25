"""Small utilities for the fabro-test mini task line."""

import re


def add(a: int, b: int) -> int:
    """Returns the sum of a and b."""
    return a + b


def clamp(value: float, low: float, high: float) -> float:
    """restrict value to the inclusive range [low, high]"""
    return min(max(value, low), high)


def slugify(text: str) -> str:
    """lowercase text and join alphanumeric runs with single hyphens"""
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
