"""Locate and validate the real SMT solver used by Verilator randomization."""
import os
from pathlib import Path
import shlex
import shutil
import subprocess


def solver_candidates():
    """An explicit override is authoritative; otherwise try installed solvers."""
    configured = os.environ.get('VERILATOR_SOLVER')
    if configured is not None:
        return [configured]
    workspace = Path(__file__).resolve().parents[2]
    local_z3 = workspace / '.venvs/dv-solver/bin/z3'
    return ['z3 -in -smt2', 'cvc5 --lang=smt2 --incremental --produce-models',
            f'{shlex.quote(str(local_z3))} -in -smt2']


def require_solver():
    failures = []
    probe = ('(set-logic QF_BV)\n(declare-fun x () (_ BitVec 8))\n'
             '(assert (= x #x2a))\n(check-sat)\n(get-value (x))\n(exit)\n')
    for command in solver_candidates():
        try:
            args = shlex.split(command)
            if not args or not shutil.which(args[0]):
                failures.append(f'{command}: executable not found')
                continue
            result = subprocess.run(args, input=probe, capture_output=True,
                                    text=True, timeout=10)
            if (result.returncode or 'sat' not in result.stdout.split()
                    or 'error' in result.stdout.lower() or '(x ' not in result.stdout):
                failures.append(f'{command}: SMT-LIB/model probe failed')
                continue
        except (ValueError, OSError, subprocess.TimeoutExpired) as exc:
            failures.append(f'{command}: {exc}')
            continue
        # Child simulator processes must use exactly the solver we validated.
        os.environ['VERILATOR_SOLVER'] = command
        return command
    raise SystemExit('Constrained-random setup: no working SMT solver. '
                     'Install Z3/CVC5 or set VERILATOR_SOLVER to its SMT-LIB command. '
                     'Fixed-stimulus fallback is disabled. Tried: ' + '; '.join(failures))


if __name__ == '__main__':
    print(require_solver())
