# UVM constrained-random refactor status

Implemented:

- 14 independent factory-registered UVM tests and 14 concrete feature sequences,
  mapped to QSPI_0 through QSPI_7 and their companion cases.
- Shared flash/register operations extracted to qspi_transfer_base_seq_c.
  The original qspi_indirect_seq_c remains runnable with its existing factory
  name and behavior; new tests do not inherit its concrete body.
- Shared random flash context and reporting in qspi_feature_base_seq_c.
- Named constraints and rand int unsigned stimulus fields used by actual
  transfers/configuration. Directed boundary bins are retained with inline
  constraints; the rest of the legal stimulus remains randomized.
- No localparam in sequence or test source. No +QSPI_CASE dispatcher.
- Typed sequences started from each UVM test main_phase with objections.
- Runner maps actual UVM test names and preserves reproducible simulator seeds.

Validation completed:

- Full Verilator C++ build includes all split sequences and UVM tests.
- Current saved-source Verilator lint passed (exit 0).
- Original qspi_indirect_seq_c ran after operation extraction: 24 compared words,
  zero data mismatches, zero UVM errors and zero fatals. This is a directed
  compatibility check, not a constrained-random regression result.
- Python runner scripts compile; solver preflight correctly fails when the
  required executable is unavailable.
- uvm-sequence-authoring skill passes the skill validator and is linked under
  Project/IPTrial_V0/.agents/skills for project discovery.

Runtime limitation:

No Z3/CVC5 executable or Z3 library is discoverable here. An isolated Python
install found no z3-solver distribution; a user-local APT download of Z3 and
libz3 failed because archive.ubuntu.com cannot be resolved. No system Python
packages were overwritten. The new constrained-random tests have not been
executed. They deliberately have no fixed-stimulus fallback.

Provide an available solver command through VERILATOR_SOLVER, validate it with
`python3 regr/solver_setup.py`, then run `python3 regr/run_all.py`.
The earlier 13-PASS/2-FAIL directed baseline remains historical evidence only.

Validation logs:

- SIM/qspi_testplan/refactor_validation/compile_dv.log
- SIM/qspi_testplan/test-testc=qspi_base_test_c-seqc=qspi_indirect_seq_c/compile.log
- SIM/qspi_testplan/test-testc=qspi_base_test_c-seqc=qspi_indirect_seq_c/run.log

Functional coverage has been added; see [COVERAGE.md](COVERAGE.md). Task implementations in seq/ and test/ use the requested `//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=` separator.

Coverage validation (2026-11-12):

- Verilator C++ build with --coverage-user passed.
- Final saved-source lint passed.
- Collector diagnostic passed nine positive/negative sampling checks and checked
  that an indirect read cannot hit the XIP cross.
- Coverage-enabled original indirect smoke passed: 24 compared words, zero
  mismatches, zero UVM errors/fatals; coverage.dat export produced a file.
- Logs: SIM/qspi_testplan/coverage_validation/. The original smoke is a
  compatibility check; it does not establish split-test functional coverage.
