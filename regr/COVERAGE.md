# QSPI functional coverage

`env/qspi_coverage.svh` defines nine standard SystemVerilog covergroups in a
factory-registered UVM component, created by `qspi_env_c`. Both testplan YAML
configurations enable Verilator `--coverage-user`. The regression runner writes
`coverage.dat` into each case directory and records its path in `results.json`.

| Group | Bins / testplan relationship | Sampling evidence |
|---|---|---|
| feature_cg | 14 split tests, QSPI_0–7 and companion features | Sequence completes; verified bins require checks > 0, no checker failures, and no UVM errors |
| register_cg | 17 mapped offsets, including DLY 0x40; reserved range | Successful APB read; access coverage only, not proof of data correctness |
| read_cg | Single/dual/quad, SDR/DDR, CKMODE 0/1, sizes 1/4/8/16/32/128/256/512/1024 | Completed indirect/XIP read with checked payload and no new checker/APB errors |
| read_cg.indirect_matrix | 3 widths × 6 sizes × 2 rates × 2 clock modes = 72 | Successful individual indirect comparison |
| read_cg.xip_matrix | 3 widths × 9 sizes = 27 | Successful individual XIP comparison |
| fifo_cg | TX/RX empty, one, middle, 31, full 32 | Actual levels read from SR; observed occupancy only |
| irq_cg | Eight sources × checked high/low level; assert/clear, plus TXFTF/RXFTF reassert | IRQ pin checked over configured observation interval |
| polling_cg | Four legal lengths, OR, timeout, zero-mask AND/OR, four illegal lengths, real WIP→ready | Expected SR stop/error condition and associated data checks |
| abort_cg | Indirect, polling, memory mapped with pending AHB | Abort/flush/recovery checks; memory-mapped bin also requires pending AHB ERROR |
| frame_cg | Address/alternate lengths 1–4; dummy 0, 1–30, 31; 16 length crosses | Actual serial clock count matches expected frame length |
| delay_cg | CSS/CSH/CSIDLE 0/1/3 and other legal values | Measured setup/hold/idle checks after commands |

`result.fail` and feature result crosses are diagnostic bins. Failing comparisons
never hit verified read/IRQ/abort bins. Feature closure is deliberately conservative:
a previous failure prevents that sequence from closing its whole-feature bin.
`TESTPLAN_BIN` logs are now suppressed after a checker failure; logs are not the
functional coverage database.

Run after installing an SMT solver:

```sh
python3 regr/solver_setup.py
python3 regr/run_all.py
# Merge files from the desired completed runs (including other seeds):
verilator_coverage --write merged_coverage.dat /absolute/run1/coverage.dat /absolute/run2/coverage.dat
```

Inspect unhit bins in the merged database or use Verilator coverage annotation.
Do not interpret a total including diagnostic fail bins as a closure percentage.

## Limits and validation

The active testplan configuration uses the adapted Micron model. Macronix and
Infineon have not been verified; these covergroups do not claim vendor closure.
Frame middle dummy cycles and additional independent DLY combinations remain
open stimulus work. DMA coverage is currently whole-feature coverage of the
existing request/cancellation checks, not external DMA-engine completion.

Run the isolated sampling diagnostic with `python3 regr/check_coverage_sampling.py`.
It uses a minimal component-constructor stand-in and the unchanged production
covergroup definitions; it is not a substitute for the UVM DUT regression.

An isolated collector diagnostic compiled with Verilator and exercised passing
and failing samples. Emitted coverage counters confirmed: failed samples left
read width/length/clock, feature, IRQ, polling, frame, DLY, and pending-AHB abort passing bins at zero;
passing samples hit each once. Indirect samples left XIP crosses unhit. This
checks collection semantics, not DUT behavior or constrained-random coverage.

The full constrained-random regression remains blocked by the missing SMT solver;
no DUT coverage percentage is claimed. Historical directed results predate this
instrumentation and cannot populate these covergroups retroactively.
