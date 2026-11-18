# VCS test list and arun regression

`vcs_testlist.json` lists 15 existing UVM scenarios at seeds 1, 7, 42. The runner invokes only the owning launcher: `python3 arun.py --sim vcs --config <profile> test-testc=...-seqc=...-+n25q_csn-+ntb_random_seed=...`. It does not implement VCS compilation itself. The timeout scenario selects the timeout profile. Normal scenarios use the normal profile. No `+QSPI_DIRECTED` is supplied.

From the QSPI directory:

```bash
# Review all 45 commands without running VCS.
python3 regr/run_vcs_regression.py --dry-run

# Run all listed tests and seeds on your VCS host.
python3 regr/run_vcs_regression.py --arun /path/to/arun.py

# Optional selection and waves (requires your VCS FSDB setup).
python3 regr/run_vcs_regression.py --arun /path/to/arun.py --cases xip,polling --seeds 1 --fsdb
```

Use `--normal-config` and `--timeout-config` for the configuration files in your checkout, and `--out` for launcher logs/results. Configurations must point to that host's UVM/RTL paths. A run includes arun's compile-and-simulate flow; the default wall timeout is 1200 seconds, adjustable with `--timeout`. Each case/seed has a unique runstring and launcher log. The script requires process success, UVM summary with zero errors/fatals, and a successful test comparison summary. Missing completion is a failure. Results are saved incrementally to `results.json`.

Only command generation was validated locally; VCS simulation is left to the user. Existing DDR and abort checks remain enabled, so results are not guaranteed to pass. This list must stay outside `vectors/`, which is owned by the Verilator YAML runner.

All scenarios use the single `qspi_base_test_c` class. The runner selects the feature through `-seqc=` / `+vseq_c`; feature sequences remain separate.
