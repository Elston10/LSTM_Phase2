from math import exp

# /d:/Github/SOC_LSTM/PHASE_2/tanh/tanh.py
"""Very simple hyperbolic tangent implementation for a scalar input."""


def tanh(x: float) -> float:
    """Return the hyperbolic tangent of x (scalar)."""
    e_pos = exp(x)
    e_neg = exp(-x)
    return (e_pos - e_neg) / (e_pos + e_neg)


if __name__ == "__main__":
    # quick check
    for v in [0.2657]:
        print(v, tanh(v))