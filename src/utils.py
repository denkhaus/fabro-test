"""Small utilities for the fabro-test mini task line."""


def add(a: int, b: int) -> int:
    """return the sum"""
    return a + b


def clamp(value: float, low: float, high: float) -> float:
    """restrict value to the inclusive range [low, high]"""
    return min(max(value, low), high)
