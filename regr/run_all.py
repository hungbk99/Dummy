#!/usr/bin/env python3
"""Compile the two required parameter configurations and execute the testplan."""
import json,subprocess,sys
from pathlib import Path
from solver_setup import require_solver
ROOT=Path(__file__).resolve().parents[1]
ARUN=Path('/home/hungle/workspace/AlterDV/Common/script/arun.py')
SIM=Path('/home/hungle/workspace/SIM')
TESTS={'registers':'qspi_register_test_c','timeout':'qspi_ahb_timeout_test_c'}

def build(config,name,case):
 runstring='test-testc='+TESTS[case]
 run=SIM/name/runstring
 result=subprocess.run([sys.executable,str(ARUN),'--config',config,'--sim','verilator','--quiet',runstring],cwd=ROOT)
 log=run/'compile.log';binary=run/'obj_dir/Vtop'
 if not binary.is_file() or not log.is_file() or '%Error' in log.read_text(errors='replace'):
  raise SystemExit('Compile failed; see '+str(log))
 return binary

def execute(binary,output,cases=None):
 args=[sys.executable,'regr/run_regression.py','--binary',str(binary),'--out',str(output),'--timeout','240']
 if cases:args+=['--cases',cases]
 return subprocess.run(args,cwd=ROOT).returncode

require_solver()
subprocess.run([sys.executable,'regr/extract_testplan.py'],cwd=ROOT,check=True)
binary=build('qspi_testplan.yaml','qspi_testplan','registers')
main_result=execute(binary,SIM/'qspi_testplan/regression')
timeout_binary=build('qspi_testplan_timeout.yaml','qspi_testplan_timeout','timeout')
timeout_result=execute(timeout_binary,SIM/'qspi_testplan/timeout_regression','timeout')
link=ROOT/'outfeed'
if link.is_symlink():link.unlink();link.symlink_to(SIM/'qspi_testplan',target_is_directory=True)
subprocess.run([sys.executable,'regr/summarize.py'],cwd=ROOT,check=True)
print('Reports:',SIM/'qspi_testplan/regression/REPORT.md',SIM/'qspi_testplan/timeout_regression/REPORT.md')
raise SystemExit(main_result or timeout_result)
