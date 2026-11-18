#!/usr/bin/env python3
"""Run the VCS test list through arun.py; no simulator flow is duplicated here."""
import argparse
import json
import os
from pathlib import Path
import re
import shlex
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    """Launch each test/seed, retain its log, and require clean UVM completion."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--arun', type=Path, default=Path('/home/hungle/workspace/AlterDV/Common/script/arun.py'))
    parser.add_argument('--testlist', type=Path, default=ROOT/'regr/vcs_testlist.json')
    parser.add_argument('--out', type=Path, default=ROOT/'outfeed/vcs_regression')
    parser.add_argument('--seeds', help='Override comma-separated seeds, e.g. 1,7,42')
    parser.add_argument('--cases', help='Select comma-separated case names')
    parser.add_argument('--normal-config', default='qspi_testplan.yaml')
    parser.add_argument('--timeout-config', default='qspi_testplan_timeout.yaml')
    parser.add_argument('--timeout', type=int, default=1200, help='Wall seconds per compile-and-run')
    parser.add_argument('--fsdb', action='store_true')
    parser.add_argument('--dry-run', action='store_true', help='Print commands only; do not invoke VCS')
    args = parser.parse_args()
    plan = json.loads(args.testlist.read_text())
    seeds = [int(s) for s in args.seeds.split(',')] if args.seeds else plan['seeds']
    selected = set(args.cases.split(',')) if args.cases else {x['case'] for x in plan['tests']}
    if not selected <= {x['case'] for x in plan['tests']} or not seeds or min(seeds)<1 or args.timeout<1:
        parser.error('Select known cases, positive seeds and a positive timeout')
    results = []
    for test in plan['tests']:
        if test['case'] not in selected:
            continue
        config = args.timeout_config if test['profile']=='timeout' else args.normal_config
        for seed in seeds:
            runstring = (f"test-testc={test['test']}-seqc={test['sequence']}"
                         f"-+n25q_csn-+ntb_random_seed={seed}"
                         '-+UVM_MAX_QUIT_COUNT=0-+QSPI_WATCHDOG_US=100000')
            if args.fsdb:
                runstring += '-FSDB'
            command = [sys.executable, str(args.arun.resolve()), '--sim', 'vcs', '--config', config, runstring]
            print(shlex.join(command), flush=True)
            if args.dry_run:
                continue
            folder = args.out.resolve()/test['case']/f'seed_{seed}'
            folder.mkdir(parents=True, exist_ok=True)
            log = folder/'launcher.log'
            started = time.monotonic()
            timed_out = False
            with log.open('w') as stream:
                process = subprocess.Popen(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT,
                                           start_new_session=True)
                try:
                    code = process.wait(timeout=args.timeout)
                except subprocess.TimeoutExpired:
                    timed_out = True
                    os.killpg(process.pid, signal.SIGKILL)
                    code = process.wait()
            text = log.read_text(errors='replace')
            counts = {}
            for severity in ['UVM_ERROR', 'UVM_FATAL']:
                values = re.findall(r'^'+severity+r'\s*:\s*(\d+)\s*$', text, re.M)
                counts[severity] = int(values[-1]) if values else None
            if test['case']=='indirect_smoke':
                summary = re.search(r'\[QSPI_COMPARE_SUMMARY\] Compared (\d+) words .*mismatches=(\d+)',text)
                checks = int(summary[1]) if summary else None
                failures = int(summary[2]) if summary else None
            else:
                summary = re.search(r'\[TESTPLAN_RESULT\] case=\S+ checks=(\d+) failures=(\d+)',text)
                checks = int(summary[1]) if summary else None
                failures = int(summary[2]) if summary else None
            passed = code==0 and summary is not None and failures==0 and all(v==0 for v in counts.values())
            result = dict(case=test['case'], seed=seed, command=command, log=str(log),
                          seconds=round(time.monotonic()-started,3), returncode=code,
                          status='TIMEOUT' if timed_out else ('PASS' if passed else 'FAIL'),
                          checks=checks, failures=failures, severities=counts)
            results.append(result)
            (args.out.resolve()/'results.json').write_text(json.dumps(results,indent=2)+'\n')
            print(f"{test['case']} seed={seed}: {result['status']}",flush=True)
    return 0 if args.dry_run or all(x['status']=='PASS' for x in results) else 1


if __name__ == '__main__':
    sys.exit(main())
