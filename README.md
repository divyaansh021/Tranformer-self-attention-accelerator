# Transformer Attention Block Accelerator

A fully synthesisable Verilog RTL implementation of single-head self-attention, the core computation inside every transformer model (BERT, GPT, ViT). All arithmetic is performed in **Q8.8 signed fixed-point** — no floating-point hardware required.

$$\text{Output} = \text{softmax}\!\left(\frac{\mathbf{Q}\mathbf{K}^\top}{\sqrt{d_k}}\right)\mathbf{V}$$

Verified in **Vivado XSim** behavioural simulation. All 214 unit and integration tests pass.

---

## Why this exists

Running transformer attention on a CPU or GPU works fine at scale, but is impractical on edge devices — microcontrollers, FPGAs, and custom ASICs that have no floating-point unit, limited memory bandwidth, and strict power budgets. This accelerator solves that by:

- Replacing float32 with **Q8.8 fixed-point** — 85% fewer logic gates per multiplier
- Computing 64 multiply-accumulate operations **in parallel** using a systolic array
- Implementing softmax entirely in hardware using a **256-entry exp LUT** and restoring division — no math library needed
- Using **zero-skip operand gating** to suppress DSP switching activity when inputs are sparse, saving ~50% multiplier dynamic power
- Exposing a simple **start/done interface** — the CPU fires one pulse and the hardware delivers the result in a deterministic 1381 cycles

---

## Architecture overview

```
Q, K, V inputs
     │
     ▼
┌─────────────────────────────────────────────────────────┐
│                   attention_top FSM                     │
│         IDLE → MAC1 → SCALE → SOFTMAX → MAC2 → DONE    │
└────┬──────────┬─────────────┬──────────────┬────────────┘
     │          │             │              │
     ▼          ▼             ▼              ▼
┌─────────┐ ┌────────┐  ┌──────────┐  ┌─────────┐
│Systolic │ │ Scale  │  │ Softmax  │  │Systolic │
│ Array   │ │  Unit  │  │  Unit    │  │ Array   │
│ MAC1    │ │÷√dk LUT│  │exp LUT + │  │  MAC2   │
│ Q×Kᵀ   │ │1 cycle │  │restoring │  │ Attn×V  │
│ 8×8 PEs │ │        │  │  div     │  │ 8×8 PEs │
└────┬────┘ └───┬────┘  └────┬─────┘  └────┬────┘
     │          │             │              │
  Score buf  Scaled buf   Attn buf       Output
  [8×8 Q8.8] [8×8 Q8.8]  [8×8 Q8.8]   [N×DK Q8.8]
```

**Key design decision:** The same 8×8 systolic array is reused for both matrix multiplications. The top-level FSM sequences them in time — no duplicate hardware.

---

## Module hierarchy

```
attention_top.v                 ← top-level FSM and datapath sequencer
├── systolic_array.v            ← 8×8 PE grid (shared for MAC1 and MAC2)
│   ├── systolic_pe.v           ← single MAC unit with zero-skip gating
│   ├── skew_chain.v            ← input alignment delay registers
│   └── matmul_ctrl.v           ← 4-state FSM: IDLE→CLEAR→RUN→DONE
├── scale.v                     ← 1-cycle Q1.15 multiply + bit extract
├── scale_ctrl.v                ← serialises 64 C_out ports through scale unit
├── softmax.v                   ← 6-state FSMD: max→exp→sum→div→done
│   └── exp_lut.v               ← 256-entry combinational exp table
├── softmax_ctrl.v              ← runs softmax N times, one row per ~158 cycles
└── lib/
    ├── adder.v
    ├── multiplier.v
    ├── mux2.v
    ├── register.v
    └── zero_detector.v
```

---

## Q8.8 fixed-point format

Every value in the pipeline is stored as a 16-bit signed integer where the lower 8 bits are the fractional part.

```
 bit 15        bit 8   bit 7        bit 0
 ┌──────────────────┬──────────────────┐
 │   8 integer bits │ 8 fractional bits│
 └──────────────────┴──────────────────┘

Resolution:  1/256 = 0.00390625  (1 LSB)
Range:       −128 to +127
Conversion:  float → Q8.8 : multiply by 256
             Q8.8 → float : divide by 256

Examples:
  1.0   →  0x0100  (256)
  0.5   →  0x0080  (128)
 −0.5   →  0xFF80  (signed)
  0.707 →  0x005A  (90 → 90/256 = 0.352... actually 0x00B5 = 181 → 0.707)
```

---

## Systolic array

The 8×8 PE grid computes matrix multiplication by feeding one column of operands per clock cycle. On cycle k:

- **A inputs** (8 wires): column k of Q (or Attn for MAC2)
- **B inputs** (8 wires): column k of K (or row k of V for MAC2)

All 64 PEs accumulate their partial products simultaneously. After DK cycles all outputs are ready.

**Skew chain:** Lane i is delayed by i register stages before reaching the PE grid. This staggers the data so each PE receives the correct operands at the correct time despite the grid propagation delay.

**Latency:** $2N + d_k - 2$ cycles. For N=8, DK=8: **22 cycles**.

**Zero-skip operand gating:** A zero-detector checks both operands before the multiplier. If either is zero, a MUX forces both inputs to 0x0000 — preventing any bit transitions inside the DSP48. This saves ~50% of multiplier dynamic power at typical sparsity with zero latency cost.

```
a_in ──► MUX ──► ×  ──► +  ──► ACC (32-bit)
              ↑      ↑                │
b_in ──► MUX ─┘   feedback           │
              ↑                  C_out[23:8] → Q8.8
skip ─────────┘
(forces 0x0000 when either operand is zero)
```

---

## Scale unit

Divides each score by √dk using a multiply-instead-of-divide trick:

$$\frac{x}{\sqrt{d_k}} = x \times \frac{1}{\sqrt{d_k}}$$

The reciprocals are precomputed at design time and stored in a Q1.15 lookup table (8 entries, one per dk value):

| dk | 1/√dk | Q1.15 hex |
|----|-------|-----------|
| 1  | 1.0000 | 0x8000 |
| 2  | 0.7071 | 0x5A82 |
| 4  | 0.5000 | 0x4000 |
| 8  | 0.3536 | 0x2D41 |

The 16×16 multiplier produces a 32-bit Q9.23 product. Extracting bits [30:15] gives the Q8.8 result — equivalent to right-shifting by 15 to remove the extra 15 fractional bits. **Total latency: 1 cycle.**

`scale_ctrl` serialises all 64 MAC1 outputs through this unit one per cycle, storing results in `scaled_buf[8][8]`. **Total: 65 cycles.**

---

## Softmax unit

Implements numerically stable softmax entirely in hardware:

$$w_i = \frac{e^{x_i - x_{\max}}}{\sum_j e^{x_j - x_{\max}}}$$

Subtracting the row maximum before exp keeps all inputs in [−8, 0], preventing overflow.

**Datapath — 5 stages:**

| Stage | Operation | Latency |
|-------|-----------|---------|
| MAX_FIND | 7-comparator tree → row_max | 1 cycle |
| EXP | 8× subtractors + abs + SHR3 → LUT index → exp value | 1 cycle |
| SUM | 7-adder tree → exp_sum | 1 cycle |
| DIV | 17-cycle restoring division × 8 elements | 136 cycles |
| DONE | assert done, weights valid | 1 cycle |

**exp LUT:** 256-entry combinational ROM. Index = |x − x_max| >> 3, covering [−8, 0] in steps of 1/32. Purely combinational — zero latency.

**Restoring division:** Computes weight_i = (exp_i × 256) / exp_sum using 17 iterations of shift-subtract. The ×256 pre-shift ensures the quotient lands in Q8.8 format.

`softmax_ctrl` runs the softmax unit N times (once per row), collecting all 64 weights into `attn_buf[8][8]`. **Total: ~1264 cycles.**

---

## Quantisation error

The only source of error in the pipeline is **truncation of the remainder** after 17 bits of restoring division inside the softmax unit.

| Stage | Error introduced |
|-------|-----------------|
| MAC1, MAC2 | Zero (pure integer) |
| Scale | Zero (LUT + shift) |
| exp LUT | Zero (table lookup) |
| **Restoring division** | **±1 LSB = ±0.004** |

---

## Pipeline latency

| Stage | Cycles | % of total |
|-------|--------|------------|
| MAC1 (Q×Kᵀ) | 22 | 1.6% |
| Scale (÷√dk) | 65 | 4.7% |
| Softmax (8 rows) | 1264 | 91.5% |
| MAC2 (Attn×V) | 30 | 2.2% |
| **Total** | **1381** | **100%** |

At 10ns clock period: **13.81 µs per inference**.

Softmax dominates at 91.5%. The single biggest optimisation would be parallelising all 8 softmax rows simultaneously, reducing total latency from 1381 to ~280 cycles (4.9× speedup) at the cost of 8× the softmax hardware area.

---

## Verification

### Unit tests

Every module was tested independently before integration:

| Module | Tests | Result |
|--------|-------|--------|
| systolic_pe | 11/11 | PASS |
| skew_chain | 12/12 | PASS |
| matmul_ctrl | 20/20 | PASS |
| systolic_array | 76/76 | PASS |
| scale | 30/30 | PASS |
| scale_ctrl | 19/19 | PASS |
| softmax | 15/15 | PASS |
| softmax_ctrl | 23/23 | PASS |
| attention_top | 8/8 | PASS |
| **Total** | **214/214** | **PASS** |

### End-to-end tests (Vivado XSim)

Five named test cases verified hardware output against the Python fixed-point reference model:

| Test | Config | Cycles | Max error | Result |
|------|--------|--------|-----------|--------|
| Sentence tokens | N=3, DK=2 | 1420 | 0.0047 | PASS |
| Opposite vectors | N=4, DK=4 | 1427 | 0.0048 | PASS |
| Dominant token | N=4, DK=4 | 1427 | 0.0041 | PASS |
| Unit circle | N=4, DK=2 | 1425 | 0.0040 | PASS |
| Full 8×8 | N=8, DK=8 | 1451 | 0.0047 | PASS |

---

## Python reference model

`python/self_attention.py` implements the complete fixed-point pipeline in Python — bit-for-bit identical to the hardware. Useful for:

- Generating expected outputs before running simulation
- Debugging discrepancies between hardware and reference
- Generating random test cases with `gen_test.py`

```bash
# Print all 4 pipeline steps for 5 named examples
python3 python/self_attention.py

# Generate random Q,K,V and matching Verilog testbench
python3 python/gen_test.py --seed 42 --n 8 --dk 8

# Verify generated testbench (iverilog)
iverilog -o sim_rand \
    rtl/lib/register.v rtl/lib/zero_detector.v \
    rtl/lib/multiplier.v rtl/lib/mux2.v rtl/lib/adder.v \
    rtl/systolic_pe.v rtl/skew_chain.v \
    rtl/matmul_ctrl.v rtl/systolic_array.v \
    rtl/scale.v rtl/scale_ctrl.v \
    rtl/exp_lut.v rtl/softmax.v rtl/softmax_ctrl.v \
    rtl/attention_top.v tb_random_test.v && vvp sim_rand
```

---

## Hardware resource estimate

| Resource | Count | Notes |
|----------|-------|-------|
| DSP48 blocks | 64 | One per PE — maps directly, zero LUTs |
| Flip-flops | ~8989 | Dominated by PE accumulators and data buffers |
| BRAM | 1 | 256-entry exp LUT (4 KB) |
| LUTs | ~1500 | FSM logic, skew chains, adder trees |
| Total registers | ~1.1 KB | Accumulators + scaled_buf + attn_buf |

---

## Future improvements

| Improvement | Benefit | Cost |
|-------------|---------|------|
| Parallel softmax rows | 4.9× speedup (1381 → 280 cycles) | 8× softmax area |
| Round-to-nearest in division | Error halved to ≤ 0.5 LSB | Zero — one comparator |
| Pipelined division | ~30% softmax saving | Control complexity |
| 16×16 systolic array | Supports N=16 | 4× PE area |
| Q16.16 format | Near-zero quantisation error | 4× multiplier area |

---

## File reference

| File | Description |
|------|-------------|
| `rtl/attention_top.v` | Top-level module — start/done interface |
| `rtl/systolic_array.v` | 8×8 PE grid with skew chains |
| `rtl/systolic_pe.v` | Single MAC unit with zero-skip gating |
| `rtl/skew_chain.v` | Input alignment delay registers |
| `rtl/matmul_ctrl.v` | Matrix multiply sequencer FSM |
| `rtl/scale.v` | Q1.15 reciprocal multiply, 1-cycle pipeline |
| `rtl/scale_ctrl.v` | Serialises 64 scores through scale unit |
| `rtl/softmax.v` | 6-state softmax FSMD |
| `rtl/exp_lut.v` | 256-entry combinational exp table |
| `rtl/softmax_ctrl.v` | Row iterator for softmax |
| `tb/tb_5tests.v` | 5 named test cases, hw vs python side by side |
| `tb/tb_attention_top.v` | End-to-end attention_top verification |
| `python/self_attention.py` | Fixed-point reference model, 5 examples |
| `python/gen_test.py` | Random test vector generator |
| `python/attention_verify.py` | Detailed verification and error analysis |

---

## Licence

MIT — free to use, modify, and distribute with attribution.
