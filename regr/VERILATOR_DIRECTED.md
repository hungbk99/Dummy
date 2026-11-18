# Directed Verilator regression

Run from the QSPI directory:

```bash
python3 regr/run_yaml_regression.py --vectors regr/vectors/verilator_directed.yaml
```

This separate 15-case list selects `+QSPI_DIRECTED` at seed 1. It requires no Z3/CVC5. It is directed scenario coverage, not constrained-random coverage. Existing `full.yaml` retains randomized stimulus for solver-equipped Verilator and VCS sequence execution.

Common inputs: flash offset 0x10000, expected-data seed 0x13572468, two repeats, idle/poll interval zero. Scenario hooks explicitly select legal fields. The indirect matrix still sweeps lengths 1/4/8/16/32/128, lanes 1/2/4, both clock modes and SDR/DDR. Frame and delay sweeps retain their existing bins. Abort delays are 2 then 3 core clocks.

XIP uses lengths 512 (low), 204 (high, ending at 0x30ffffff), and 648 (middle at 0x30073034), in all three lane modes. The middle/high starts exercise page splits. Register pattern is 0xa5a55a5a; reserved offset 0x44; polling timeout 64; clock observation 32; mixed transfer 16 bytes; IRQ observation 8; DMA clear pulse 4; timeout settling 8; SIOO continuation 256 bytes. The existing legacy smoke retains its own deterministic setup.

Payload oracles, protocol/error checks, and recovery checks remain enabled. Known DDR/abort findings are not waived. PASS requires completed simulation, zero failed checks, and zero UVM errors/fatals. Fixed scenarios do not replace randomized coverage.

All scenarios use the single `qspi_base_test_c` class. The runner selects the feature through `-seqc=` / `+vseq_c`; feature sequences remain separate.
