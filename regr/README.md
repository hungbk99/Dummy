# QSPI UVM constrained-random tests

The testplan is split into independent UVM tests and sequences. Each test is factory registered and starts a typed sequence with phase objections. There is no `+QSPI_CASE` dispatcher.

| Testplan ID | UVM test | Sequence |
|---|---|---|
| QSPI_0 | `qspi_register_test_c` | `qspi_register_access_seq_c` |
| QSPI_1 (workbook WAIVE) | `qspi_clock_reset_test_c` | `qspi_clock_reset_seq_c` |
| QSPI_2 | `qspi_indirect_test_c` | `qspi_indirect_matrix_seq_c` |
| QSPI_3 | `qspi_polling_test_c` | `qspi_polling_seq_c` |
| QSPI_4 | `qspi_xip_test_c` | `qspi_xip_seq_c` |
| QSPI_5 | `qspi_mode_switch_test_c` | `qspi_mode_switch_seq_c` |
| QSPI_6 | `qspi_interrupt_test_c` | `qspi_interrupt_seq_c` |
| QSPI_7 | `qspi_abort_test_c` | `qspi_abort_seq_c` |
| QSPI_2 | `qspi_frame_format_test_c` | `qspi_frame_format_seq_c` |
| QSPI_2 | `qspi_fifo_test_c` | `qspi_fifo_seq_c` |
| QSPI_2 | `qspi_delay_test_c` | `qspi_delay_seq_c` |
| QSPI_2 / QSPI_7 | `qspi_dma_test_c` | `qspi_dma_seq_c` |
| QSPI_4 | `qspi_sioo_test_c` | `qspi_sioo_seq_c` |
| QSPI_4 | `qspi_ahb_timeout_test_c` | `qspi_ahb_timeout_seq_c` |

## Bus connections

The active AHB master agent `m_ahb_agent` drives memory-mapped/XIP requests through
its sequencer and returns read data and HRESP to the checks. Sequential reads use
INCR bursts split at 1 KiB boundaries. The DUT provides the slave responses.
`connect/qspi_connect.svh` owns the AHB wiring, virtual-interface registration,
and `qspi_test_if` instance. The latter observes clocks, resets, IRQ, serial/APB
activity and drives DMA clear signals; it does not drive AHB transactions.

## Sequence structure

- `qspi_transfer_base_seq.svh`: shared register/flash transactions extracted from the reference sequence.
- `qspi_feature_base_seq.svh`: common constrained flash context, setup, checks, and result reporting; no concrete feature body.
- One file/class per feature, with `extern` declarations and named out-of-class implementations.
- `rand int unsigned` fields and named constraints drive addresses, data patterns, lengths, lanes, clock/rate selections, delays, observation windows, and repeat counts.
- Required matrix/boundary bins remain directed through inline constraints; other legal fields remain randomized.
- The flash context is randomized once per sequence and frozen while its individual scenarios randomize, so programmed memory and expected data stay consistent.
- No `localparam` in sequence/test source. Verilator XIP uses a deterministic size/lane matrix; other split tests require a solver.
- The original `qspi_indirect_seq_c` factory name remains as a directed compatibility check; new testplan tests do not inherit its concrete test body.

## Verilator XIP

`VERILATOR` selects deterministic XIP stimulus: address `0x10000`, data seed
`0x13572468`, and every size/lane combination in the existing matrix. No solver
is required for this test. Other simulators retain constrained randomization.
This run checks directed behavior and does not establish random coverage.

```sh
python3 regr/run_regression.py --binary /absolute/path/to/Vtop --cases xip --seed 1
```

## Solver requirement and running

Verilator constrained randomization requires an external SMT solver. Z3, CVC5, and their libraries are not currently installed/discoverable in this environment. Isolated Python installation found no distribution; APT download failed DNS resolution. The runner fails early with an actionable setup message instead of bypassing constraints.

Once a solver is available:

```sh
export VERILATOR_SOLVER='z3 -in -smt2'
python3 regr/solver_setup.py
python3 regr/run_all.py
```

Run a specific factory-selected UVM test from `dv/qspi`:

```sh
python3 /home/hungle/workspace/AlterDV/Common/script/arun.py \
  --config qspi_testplan.yaml --sim verilator --quiet \
  'test-testc=qspi_polling_test_c-Plusarg=verilator+seed+17'
```

Reuse a compiled executable with a reproducible seed:

```sh
python3 regr/run_regression.py --binary /absolute/path/to/Vtop \
  --cases polling,xip --seed 17
```

`test_map.json` and `sequence_map.json` map regression/report labels to actual UVM classes. Labels are not an HDL test selector.

## Verification evidence and limits

The earlier 15-case directed baseline is preserved in `TESTPLAN_REPORT.md`: 13 pass and two fail (DDR interoperability and XIP abort). Those counts are not results for the new constrained-random tests. Randomized execution is blocked until an SMT solver is provided. Compilation/reference compatibility checks are recorded separately in `REFACTOR_STATUS.md`.

The original testplan is extracted from `FU3_IP_Testplan (2).xlsx` with row numbers and a SHA-256 in `qspi_testplan.json`. Historical spreadsheet PASS labels are not evidence for the current RTL. The workbook and QSPI RTL were not modified.

Micron is the selected vendor model; Macronix/Infineon bins remain uncovered. CKMODE covers the documented modes 0/3; independent CPHA is not exposed. Polling lengths >4 bytes are negative cases. DMA tests do not model an external DMA engine. The testplan configuration includes an explicit 5 ns DUT data/OE pad delay and zero added SCLK delay; this is not timing signoff. Model and remaining failure details are in `FINDINGS.md` and `connect/flash/n25q256a/VERILATOR_NOTES.md`.

Functional coverage definitions, sampling rules, and merge commands: [COVERAGE.md](COVERAGE.md).

YAML-driven runnable vectors and commands: [YAML_REGRESSION.md](YAML_REGRESSION.md).
