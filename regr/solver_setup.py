"""Check the external SMT solver required by Verilator constrained randomization."""
import os,shlex,shutil,subprocess

def require_solver():
 command=os.environ.get('VERILATOR_SOLVER','z3 -in -smt2')
 args=shlex.split(command)
 if not args or not shutil.which(args[0]):
  raise SystemExit('Constrained-random setup: SMT solver not found. Install Z3/CVC5 or set VERILATOR_SOLVER to its working SMT-LIB command. Fixed-stimulus fallback is disabled.')
 try:
  result=subprocess.run(args,input='(set-logic QF_BV)\n(declare-fun x () (_ BitVec 8))\n(assert (= x #x2a))\n(check-sat)\n(exit)\n',capture_output=True,text=True,timeout=10)
 except (OSError,subprocess.TimeoutExpired) as exc:
  raise SystemExit(f'Constrained-random setup: solver could not run: {exc}')
 if result.returncode or 'sat' not in result.stdout.split():
  raise SystemExit('Constrained-random setup: solver failed the SMT-LIB sanity check.')
 return command

if __name__=='__main__':print(require_solver())
