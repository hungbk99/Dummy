#!/usr/bin/env python3
"""Run UVM cases and keep missing prerequisites distinct from simulation failures."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time

from solver_setup import require_solver

ROOT = Path(__file__).resolve().parents[1]
CASES = {
    "registers": ["QSPI_0"], "clocks": ["QSPI_1"],
    "indirect_smoke": ["QSPI_2"], "indirect": ["QSPI_2"],
    "frames": ["QSPI_2"], "fifo": ["QSPI_2"],
    "polling": ["QSPI_3", "QSPI_6"], "xip": ["QSPI_4"],
    "timeout": ["QSPI_4"], "sioo": ["QSPI_4"], "delays": ["QSPI_2"],
    "mixed": ["QSPI_5"], "irq": ["QSPI_6"], "abort": ["QSPI_7"],
    "dma": ["QSPI_2", "QSPI_7"],
}
NO_SOLVER_CASES = {"indirect_smoke", "xip"}


def severity_count(log, severity):
    matches = re.findall(r"^" + severity + r"\s*:\s*(\d+)\s*$", log, re.M)
    return int(matches[-1]) if matches else None


def run_case(binary, name, seed, folder, timeout, plusargs, solver_error=None):
    tests = json.loads((ROOT / "regr/test_map.json").read_text())
    sequences = json.loads((ROOT / "regr/sequence_map.json").read_text())
    folder.mkdir(parents=True, exist_ok=True)
    coverage = folder / "coverage.dat"
    coverage.unlink(missing_ok=True)
    log_path = folder / "run.log"
    result = {
        "case": name, "sequence": sequences[name], "test": tests[name],
        "seed": seed, "ids": CASES[name], "status": "BLOCKED",
        "returncode": None, "timeout": False, "seconds": 0,
        "uvm_errors": None, "uvm_fatals": None, "uvm_warnings": None,
        "completed": False, "checks": None, "check_failures": None,
        "read_bytes": None, "log": str(log_path), "coverage_file": None,
        "bins": [], "errors": [],
    }
    if solver_error and name not in NO_SOLVER_CASES:
        result["blocked_reason"] = solver_error
        log_path.write_text("PREREQUISITE_BLOCKED: " + solver_error + "\nSimulation not launched.\n")
        return result

    command = [str(binary), f"+verilator+coverage+file+{coverage.resolve()}",
               f"+UVM_TESTNAME={tests[name]}", f"+verilator+seed+{seed}", *plusargs]
    if name == "indirect_smoke":
        command.append(f"+vseq_c={sequences[name]}")
    result["command"] = command
    start = time.monotonic()
    with log_path.open("w") as log_file:
        try:
            process = subprocess.run(command, cwd=folder, stdout=log_file,
                                     stderr=subprocess.STDOUT, timeout=timeout)
            result["returncode"] = process.returncode
        except subprocess.TimeoutExpired:
            result["returncode"] = -1
            result["timeout"] = True
    result["seconds"] = round(time.monotonic() - start, 3)
    log = log_path.read_text(errors="replace")
    for key, severity in [("uvm_errors", "UVM_ERROR"), ("uvm_fatals", "UVM_FATAL"),
                          ("uvm_warnings", "UVM_WARNING")]:
        result[key] = severity_count(log, severity)
    summary = re.search(r"\[TESTPLAN_RESULT\] case=(\S+) checks=(\d+) failures=(\d+) read_bytes=(\d+)", log)
    if name == "indirect_smoke":
        smoke = re.search(r"\[QSPI_COMPARE_SUMMARY\] Compared (\d+) words .*mismatches=(\d+)", log)
        if smoke:
            result.update(completed=True, checks=int(smoke[1]),
                          check_failures=int(smoke[2]), read_bytes=int(smoke[1])*4)
    elif summary:
        result.update(completed=True, checks=int(summary[2]),
                      check_failures=int(summary[3]), read_bytes=int(summary[4]))
    passed = (result["returncode"] == 0 and result["uvm_errors"] == 0 and
              result["uvm_fatals"] == 0 and result["completed"] and result["check_failures"] == 0)
    result["status"] = "TIMEOUT" if result["timeout"] else ("PASS" if passed else "FAIL")
    result["coverage_file"] = str(coverage) if coverage.exists() else None
    result["bins"] = re.findall(r"\[TESTPLAN_BIN\] (.*)", log)
    result["errors"] = [line for line in log.splitlines()
                        if re.match(r"^(?:UVM_ERROR|UVM_FATAL)\s+(?!:)", line)
                        or line.startswith(("%Error", "%Fatal"))][:25]
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--cases", default=",".join(x for x in CASES if x not in {"timeout", "indirect_smoke"}))
    parser.add_argument("--out", type=Path, default=(ROOT / "../../../../SIM/qspi_regr/regression").resolve())
    parser.add_argument("--timeout", type=int, default=240)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--plusarg", action="append", default=[])
    parser.add_argument("--no-default-plusargs", action="store_true")
    args = parser.parse_args()
    binary = args.binary.resolve()
    names = args.cases.split(",")
    if not binary.is_file() or any(name not in CASES for name in names):
        parser.error("A valid binary and known case names are required")
    if args.timeout <= 0 or args.seed <= 0:
        parser.error("Timeout and seed must be positive")
    solver_error = None
    directed = "+QSPI_DIRECTED" in args.plusarg
    if not directed and any(name not in NO_SOLVER_CASES for name in names):
        try:
            require_solver()
        except SystemExit as error:
            solver_error = str(error)
    plusargs = args.plusarg
    if not args.no_default_plusargs:
        plusargs = ["+UVM_MAX_QUIT_COUNT=0", "+QSPI_WATCHDOG_US=100000", *plusargs]
    args.out.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((ROOT / "regr/qspi_testplan.json").read_text())
    report = {"stimulus_mode": "directed" if directed else "default", "workbook": manifest["workbook"], "workbook_sha256": manifest["sha256"],
              "binary": str(binary), "binary_sha256": hashlib.sha256(binary.read_bytes()).hexdigest(),
              "cases": [], "scope": "Local RTL and adapted N25Q model. No SoC CPU or timing signoff claimed."}
    for name in names:
        result = run_case(binary, name, args.seed, args.out/name, args.timeout, plusargs, solver_error)
        report["cases"].append(result)
        (args.out/"results.json").write_text(json.dumps(report, indent=2)+"\n")
        print(f"{name}: {result['status']} errors={result['uvm_errors']} fatals={result['uvm_fatals']} elapsed={result['seconds']}s", flush=True)
        if result["status"] == "BLOCKED":
            print("  " + result["blocked_reason"], flush=True)
        for line in result["errors"][:4]:
            print("  " + line, flush=True)
    rows = ["# QSPI vector results", "", "| Case | Seed | Status | Checks | Compared bytes | Errors/fatals |",
            "|---|---:|---|---:|---:|---|"]
    for case in report["cases"]:
        rows.append(f"| {case['case']} | {case['seed']} | {case['status']} | {case['checks']} | {case['read_bytes']} | {case['uvm_errors']}/{case['uvm_fatals']} |")
    rows += ["", "BLOCKED means simulation was not launched because a prerequisite is unavailable.",
             "TIMEOUT is incomplete execution. PASS requires completion, zero UVM errors/fatals, and zero failed checks."]
    (args.out/"REPORT.md").write_text("\n".join(rows)+"\n")
    if all(case["status"] == "PASS" for case in report["cases"]):
        return 0
    return 2 if all(case["status"] in {"PASS", "BLOCKED"} for case in report["cases"]) else 1


if __name__ == "__main__":
    raise SystemExit(main())
