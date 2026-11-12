#!/usr/bin/env python3
"""Build Verilator configurations and run YAML-selected UVM cases/seeds."""
import argparse
import json
from pathlib import Path
import re
import shlex
import subprocess
import sys

import yaml
from solver_setup import require_solver

ROOT = Path(__file__).resolve().parents[1]


def load_plan(path, seed_override=None):
    data = yaml.safe_load(path.read_text())
    if not isinstance(data, dict) or data.get('version') != 1:
        raise ValueError('Vector must contain version: 1')
    profiles = data.get('profiles')
    tests = data.get('tests')
    if not isinstance(profiles, dict) or not profiles or not isinstance(tests, list) or not tests:
        raise ValueError('Nonempty profiles mapping and tests list are required')
    known = json.loads((ROOT / 'regr/test_map.json').read_text())
    common = data.get('common', {})
    if not isinstance(common, dict):
        raise ValueError('common must be a mapping')
    options = common.get('options', {})
    if not isinstance(options, dict):
        raise ValueError('common.options must be a mapping')
    plusargs = common.get('plusargs', ['+UVM_MAX_QUIT_COUNT=0', '+QSPI_WATCHDOG_US=100000'])
    compile_options = options.get('compile', [])
    if not isinstance(plusargs, list) or any(not isinstance(x, str) or not x.startswith('+') for x in plusargs):
        raise ValueError('common.plusargs must be a list of +arguments')
    controlled = ('+UVM_TESTNAME=', '+vseq_c=', '+verilator+seed+', '+verilator+coverage+file+')
    if any(x.startswith(controlled) for x in plusargs):
        raise ValueError('Test selection, seed, and coverage path are controlled by the vector runner')
    if not isinstance(compile_options, list) or any(not isinstance(x, str) or not x for x in compile_options):
        raise ValueError('common.options.compile must be a list of nonempty argument strings')
    timeout = options.get('timeout_seconds', data.get('timeout_seconds', 240))
    if type(timeout) is not int or timeout <= 0:
        raise ValueError('timeout_seconds must be a positive integer')
    jobs = {}
    for item in tests:
        if not isinstance(item, dict) or item.get('case') not in known:
            raise ValueError(f'Unknown case: {item!r}')
        profile = item.get('profile', 'normal')
        if profile not in profiles:
            raise ValueError(f'Undefined profile {profile}')
        seeds = seed_override or item.get('seeds', data.get('seeds', [1]))
        if not isinstance(seeds, list) or not seeds or any(type(x) is not int or x < 1 or x > 2147483647 for x in seeds):
            raise ValueError('Seeds must be a nonempty list of integers in 1..2147483647')
        for seed in seeds:
            cases = jobs.setdefault((profile, seed), [])
            if item['case'] in cases:
                raise ValueError(f'Duplicate case/seed/profile: {item["case"]}/{seed}/{profile}')
            cases.append(item['case'])
    for profile, _ in jobs:
        config = profiles[profile]
        if not isinstance(config, dict) or not isinstance(config.get('config'), str):
            raise ValueError(f'Profile {profile} needs config: path/to/config.yaml')
        if not (ROOT / config['config']).is_file():
            raise ValueError(f'Missing configuration: {config["config"]}')
        if not re.fullmatch(r'[A-Za-z0-9_-]+', profile):
            raise ValueError(f'Invalid profile name: {profile}')
    return data, jobs, timeout, plusargs, compile_options


def build_command(config, arun):
    # Reuse the owning runner's file list and flags; dry-run avoids launching a test.
    command = [sys.executable, str(arun), '--config', config, '--sim', 'verilator',
               '--quiet', '--dry-run', 'test-testc=qspi_base_test_c-seqc=qspi_indirect_seq_c']
    plan = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=True)
    matches = re.findall(r'^\[frun\] cwd=(.*?): (verilator .*?)$', plan.stdout, re.M)
    if len(matches) != 1:
        raise ValueError('Cannot obtain one Verilator build command from arun --dry-run')
    cwd, text = matches[0]
    command = shlex.split(text)
    binary = Path(command[command.index('--Mdir') + 1]) / 'Vtop'
    return command, Path(cwd), binary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--vectors', type=Path, required=True)
    parser.add_argument('--out', type=Path)
    parser.add_argument('--arun', type=Path, default=Path('/home/hungle/workspace/AlterDV/Common/script/arun.py'))
    parser.add_argument('--seeds', help='Override YAML seeds, e.g. 1,7,42')
    parser.add_argument('--dry-run', action='store_true', help='Validate vectors and print commands without building/running')
    parser.add_argument('--no-build', action='store_true', help='Explicitly reuse existing binaries; caller must ensure they match the source')
    parser.add_argument('--binary', action='append', default=[], metavar='PROFILE=PATH', help='Existing binary override; requires --no-build')
    args = parser.parse_args()
    try:
        seeds = [int(x) for x in args.seeds.split(',')] if args.seeds else None
        data, jobs, timeout, plusargs, compile_options = load_plan(args.vectors.resolve(), seeds)
        overrides = dict(item.split('=', 1) for item in args.binary)
        if overrides and not args.no_build:
            raise ValueError('--binary requires --no-build')
        if set(overrides) - {profile for profile, _ in jobs}:
            raise ValueError('--binary names a profile not used by this vector')
        if not args.dry_run and any(case not in {'indirect_smoke', 'xip'} for cases in jobs.values() for case in cases):
            require_solver()
        plans = {}
        for profile, _ in jobs:
            if profile not in plans:
                command, cwd, binary = build_command(data['profiles'][profile]['config'], args.arun.resolve())
                command.extend(compile_options)
                plans[profile] = command, cwd, binary
        output = (args.out or ROOT / '../../../../SIM/qspi_testplan/yaml_regression' / args.vectors.stem).resolve()
        if not args.dry_run:
            output.mkdir(parents=True, exist_ok=True)
        for profile, (command, cwd, binary) in plans.items():
            print(f'BUILD [{profile}]: ' + (shlex.join(command) if args.dry_run else data['profiles'][profile]['config']), flush=True)
            if args.no_build:
                binary = Path(overrides.get(profile, binary)).resolve()
                plans[profile] = command, cwd, binary
                if not args.dry_run and not binary.is_file():
                    raise ValueError(f'Missing binary: {binary}')
            elif not args.dry_run:
                cwd.mkdir(parents=True, exist_ok=True)
                with (output / f'build_{profile}.log').open('w') as log:
                    result = subprocess.run(command, cwd=cwd, stdout=log, stderr=subprocess.STDOUT)
                if result.returncode or not binary.is_file():
                    raise ValueError(f'Build failed; see {output / ("build_" + profile + ".log")}')
        results = []
        for (profile, seed), cases in jobs.items():
            folder = output / profile / f'seed_{seed}'
            command = [sys.executable, str(ROOT / 'regr/run_regression.py'),
                       '--binary', str(plans[profile][2]), '--out', str(folder),
                       '--cases', ','.join(cases), '--seed', str(seed), '--timeout', str(timeout),
                       '--no-default-plusargs']
            command.extend('--plusarg=' + value for value in plusargs)
            print('RUN: ' + shlex.join(command), flush=True)
            if not args.dry_run:
                report = folder / 'results.json'
                report.unlink(missing_ok=True)
                code = subprocess.run(command, cwd=ROOT).returncode
                batch = json.loads(report.read_text()) if report.exists() else {}
                results.append({'profile': profile, 'seed': seed, 'returncode': code,
                                'report': str(report), 'cases': batch.get('cases', []),
                                'binary': batch.get('binary'),
                                'binary_sha256': batch.get('binary_sha256')})
        if not args.dry_run:
            passed = all(x['returncode'] == 0 and x['cases'] for x in results)
            summary = {'vectors': str(args.vectors.resolve()), 'status': 'PASS' if passed else 'FAIL',
                       'reused_binaries': args.no_build, 'common': data.get('common', {}), 'runs': results}
            (output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
            print(f'{summary["status"]}: {output / "summary.json"}')
            return 0 if passed else 1
        return 0
    except (ValueError, OSError, yaml.YAMLError, subprocess.CalledProcessError) as exc:
        parser.error(str(exc))


if __name__ == '__main__':
    sys.exit(main())
