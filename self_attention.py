# ============================================================
# self_attention.py
# Fixed-point self-attention Python model
# 5 example test cases
# Run: python3 self_attention.py
# ============================================================

import math

# ── Q8.8 fixed-point helpers ─────────────────────────────────

def to_q88(v):
    """Float to Q8.8 (16-bit signed, stored as unsigned hex)"""
    r = int(round(v * 256))
    return max(-32768, min(32767, r)) & 0xFFFF

def from_q88(v):
    """Q8.8 hex back to float"""
    if v >= 0x8000: v -= 0x10000
    return v / 256.0


# ── Step 1: Matrix multiply A x B in Q8.8 ───────────────────

def matmul_q88(A, B):
    N  = len(A)
    DK = len(A[0])
    M  = len(B[0])
    C  = [[0]*M for _ in range(N)]
    for i in range(N):
        for j in range(M):
            acc = 0
            for k in range(DK):
                a = A[i][k] if A[i][k] < 0x8000 else A[i][k] - 0x10000
                b = B[k][j] if B[k][j] < 0x8000 else B[k][j] - 0x10000
                acc += a * b
            # acc[23:8] gives Q8.8 output (same as hardware)
            C[i][j] = (acc >> 8) & 0xFFFF
    return C


# ── Step 2: Scale each element by 1/sqrt(dk) ────────────────

RECIP_LUT = {   # precomputed 1/sqrt(dk) in Q1.15 format
    1: 0x8000,  2: 0x5A82,  3: 0x49E7,  4: 0x4000,
    5: 0x393E,  6: 0x3441,  7: 0x3061,  8: 0x2D41,
}

def scale_q88(matrix, dk):
    recip = RECIP_LUT[dk]
    out = []
    for row in matrix:
        r = []
        for v in row:
            s = v if v < 0x8000 else v - 0x10000
            # Q8.8 x Q1.15 = Q9.23 -> take [30:15] = Q8.8
            r.append((s * recip >> 15) & 0xFFFF)
        out.append(r)
    return out


# ── Step 3: Softmax using exp LUT + restoring division ───────

# 256-entry exp LUT: EXP_LUT[i] = exp(-i*8/256) in Q8.8
EXP_LUT = [
    min(int(round(math.exp(-(i * 8.0 / 256.0)) * 256)), 0xFFFF)
    for i in range(256)
]

def softmax_row(row8):
    """
    Hardware softmax for one row of 8 Q8.8 values.
    Numerically stable: subtracts row max before exp.
    """
    # find row maximum
    signed  = [r if r < 0x8000 else r - 0x10000 for r in row8]
    row_max = max(signed)

    # compute exp(x - max) via LUT for each element
    exp_vals = []
    for sv in signed:
        diff     = sv - row_max           # always <= 0
        abs_diff = (-diff) & 0xFFFF
        idx      = (abs_diff >> 3) & 0xFF # scale to 8-bit index
        exp_vals.append(EXP_LUT[idx])

    # sum of exp values
    exp_sum = sum(exp_vals) or 1

    # divide each exp by sum using 17-cycle restoring division
    # weight[i] = (exp[i] * 256) / exp_sum  -> Q8.8 result
    weights = []
    for e in exp_vals:
        dividend = e * 256
        rem = quot = 0
        for bit in range(17):
            d_bit = (dividend >> (16 - bit)) & 1
            rem   = (rem << 1) | d_bit
            if rem >= exp_sum:
                rem -= exp_sum
                quot = (quot << 1) | 1
            else:
                quot = quot << 1
        weights.append(quot & 0xFF)
    return weights


# ── Full attention pipeline ───────────────────────────────────

def self_attention(Q_float, K_float, V_float, dk):
    """
    Compute self-attention in Q8.8 fixed point.
    Output = softmax(Q x Kt / sqrt(dk)) x V

    Args:
        Q_float, K_float, V_float : N x DK lists of floats
        dk                        : head dimension (int)

    Returns:
        dict with all intermediate results in Q8.8 hex
    """
    n = len(Q_float)

    # Quantise inputs to Q8.8
    Q  = [[to_q88(v) for v in row] for row in Q_float]
    K  = [[to_q88(v) for v in row] for row in K_float]
    V  = [[to_q88(v) for v in row] for row in V_float]

    # Step 1: scores = Q x Kt
    KT     = [[K[j][k] for j in range(n)] for k in range(dk)]
    scores = matmul_q88(Q, KT)

    # Step 2: scale = scores / sqrt(dk)
    scaled = scale_q88(scores, dk)

    # Step 3: softmax row by row
    # Hardware always processes 8 elements; pad rows to length 8
    def pad_to_8(row):
        return row + [0] * (8 - len(row))

    attn_pad = []
    for i in range(8):
        row = scaled[i] if i < n else [0] * n
        attn_pad.append(softmax_row(pad_to_8(row)))

    # Take only the first n weights per row for the multiply
    attn_n = [attn_pad[i][:n] for i in range(n)]

    # Step 4: output = attn x V
    output = matmul_q88(attn_n, V)

    return {
        'Q_q88'  : Q,
        'K_q88'  : K,
        'V_q88'  : V,
        'scores' : scores,
        'scaled' : scaled,
        'attn'   : attn_n,
        'output' : output,
    }


# ── Print helper ─────────────────────────────────────────────

def print_matrix(mat, label, n_rows, n_cols):
    print(f"\n  {label}")
    hdr = "        " + "  ".join(f"  col{j}  " for j in range(n_cols))
    print("  " + hdr)
    print("  " + "-" * (len(hdr) + 4))
    for i in range(n_rows):
        vals = "   ".join(
            f"0x{mat[i][j]:04X}({from_q88(mat[i][j]):+.3f})"
            for j in range(n_cols)
        )
        print(f"  row{i}  |  {vals}")


# ════════════════════════════════════════════════════════════
# 5 TEST CASES
# ════════════════════════════════════════════════════════════

tests = [

    # ── Test 1: Professor's slide  N=3  DK=2 ─────────────────
    {
        'name' : "Test 1 — Professor slide  (N=3, DK=2)",
        'Q'    : [[1, 0],
                  [0, 1],
                  [1, 1]],
        'K'    : [[1, 0],
                  [0, 1],
                  [1, 1]],
        'V'    : [[1, 0],
                  [0, 1],
                  [1, 1]],
        'dk'   : 2,
    },

    # ── Test 2: Identity  N=4  DK=4 ──────────────────────────
    {
        'name' : "Test 2 — Identity Q=K=V  (N=4, DK=4)",
        'Q'    : [[1, 0, 0, 0],
                  [0, 1, 0, 0],
                  [0, 0, 1, 0],
                  [0, 0, 0, 1]],
        'K'    : [[1, 0, 0, 0],
                  [0, 1, 0, 0],
                  [0, 0, 1, 0],
                  [0, 0, 0, 1]],
        'V'    : [[1, 0, 0, 0],
                  [0, 1, 0, 0],
                  [0, 0, 1, 0],
                  [0, 0, 0, 1]],
        'dk'   : 4,
    },

    # ── Test 3: Uniform  N=4  DK=4 ───────────────────────────
    {
        'name' : "Test 3 — Uniform Q=K  (N=4, DK=4)",
        'Q'    : [[0.5, 0.5, 0.5, 0.5]] * 4,
        'K'    : [[0.5, 0.5, 0.5, 0.5]] * 4,
        'V'    : [[1, 0, 0, 0],
                  [0, 1, 0, 0],
                  [0, 0, 1, 0],
                  [0, 0, 0, 1]],
        'dk'   : 4,
    },

    # ── Test 4: Mixed values  N=4  DK=4 ──────────────────────
    {
        'name' : "Test 4 — Mixed  (N=4, DK=4)",
        'Q'    : [[ 0.75, -0.50,  0.25, -0.75],
                  [-0.50,  0.75, -0.25,  0.50],
                  [ 0.25, -0.25,  0.75, -0.50],
                  [-0.75,  0.50, -0.50,  0.75]],
        'K'    : [[ 0.50,  0.25, -0.50,  0.75],
                  [-0.25,  0.50,  0.75, -0.50],
                  [ 0.75, -0.50,  0.25,  0.25],
                  [-0.50,  0.75, -0.25, -0.50]],
        'V'    : [[1, 0, 0, 0],
                  [0, 1, 0, 0],
                  [0, 0, 1, 0],
                  [0, 0, 0, 1]],
        'dk'   : 4,
    },

    # ── Test 5: Full 8x8  N=8  DK=8 ──────────────────────────
    {
        'name' : "Test 5 — Full 8x8  (N=8, DK=8)",
        'Q'    : [[0.5 if i == j else (-0.3 if (i+j) % 3 == 0 else 0.1)
                   for j in range(8)] for i in range(8)],
        'K'    : [[0.5 if i == j else (-0.3 if (i+j) % 3 == 0 else 0.1)
                   for j in range(8)] for i in range(8)],
        'V'    : [[1 if i == j else 0 for j in range(8)] for i in range(8)],
        'dk'   : 8,
    },
]

SEP = "=" * 65

for t in tests:
    n   = len(t['Q'])
    dk  = t['dk']
    res = self_attention(t['Q'], t['K'], t['V'], dk)

    print(f"\n{SEP}")
    print(f"  {t['name']}")
    print(SEP)

    print_matrix(res['scores'],
                 f"Step 1  Scores = Q x Kt  [{n}x{n}]  Q8.8",
                 n, n)
    print_matrix(res['scaled'],
                 f"Step 2  Scaled = Scores / sqrt({dk})  [{n}x{n}]  Q8.8",
                 n, n)
    print_matrix(res['attn'],
                 f"Step 3  Attn weights (softmax)  [{n}x{n}]  Q8.8",
                 n, n)
    print_matrix(res['output'],
                 f"Step 4  OUTPUT = Attn x V  [{n}x{dk}]  Q8.8  ← compare with hardware",
                 n, dk)

print(f"\n{SEP}")
print("  Done. Compare OUTPUT rows with Vivado simulation output.")
print(SEP)
