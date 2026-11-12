#!/usr/bin/env python3
"""Run one compiled UVM executable in isolated directories; fail on UVM errors."""
import argparse,hashlib,json,re,subprocess,time
from pathlib import Path
from solver_setup import require_solver
CASES={
 'registers':['QSPI_0'], 'clocks':['QSPI_1'],
 'indirect_smoke':['QSPI_2'], 'indirect':['QSPI_2'], 'frames':['QSPI_2'], 'fifo':['QSPI_2'],
 'polling':['QSPI_3','QSPI_6'], 'xip':['QSPI_4'], 'timeout':['QSPI_4'],
 'sioo':['QSPI_4'], 'delays':['QSPI_2'], 'mixed':['QSPI_5'], 'irq':['QSPI_6'], 'abort':['QSPI_7'], 'dma':['QSPI_2','QSPI_7']}
p=argparse.ArgumentParser()
p.add_argument('--binary',type=Path,required=True)
p.add_argument('--cases',default=','.join(x for x in CASES if x not in {'timeout','indirect_smoke'}))
p.add_argument('--out',type=Path,default=Path('/home/hungle/workspace/SIM/qspi_testplan/regression'))
p.add_argument('--timeout',type=int,default=180)
p.add_argument('--seed',type=int,default=1)
p.add_argument('--plusarg',action='append',default=[])
p.add_argument('--no-default-plusargs',action='store_true')
a=p.parse_args();binary=a.binary.resolve();a.out.mkdir(parents=True,exist_ok=True)
if not binary.is_file():p.error('Simulation binary does not exist')
manifest=json.loads(Path('regr/qspi_testplan.json').read_text())
sequences=json.loads(Path('regr/sequence_map.json').read_text())
tests=json.loads(Path('regr/test_map.json').read_text())
if any(name not in {'indirect_smoke', 'xip'} for name in a.cases.split(',')): require_solver()
results=[]
for name in a.cases.split(','):
 if name not in CASES:p.error('Unknown case '+name)
 folder=a.out/name;folder.mkdir(parents=True,exist_ok=True)
 (folder/'coverage.dat').unlink(missing_ok=True)
 sequence=sequences[name]
 cmd=[str(binary),f'+verilator+coverage+file+{folder.resolve() / "coverage.dat"}',f'+UVM_TESTNAME={tests[name]}',f'+verilator+seed+{a.seed}']
 if not a.no_default_plusargs:cmd+=['+UVM_MAX_QUIT_COUNT=0','+QSPI_WATCHDOG_US=100000']
 cmd+=a.plusarg
 if name=='indirect_smoke':cmd.append(f'+vseq_c={sequence}')
 start=time.monotonic();timed_out=False
 with (folder/'run.log').open('w') as f:
  try:r=subprocess.run(cmd,cwd=folder,stdout=f,stderr=subprocess.STDOUT,timeout=a.timeout);code=r.returncode
  except subprocess.TimeoutExpired:code=-1;timed_out=True
 log=(folder/'run.log').read_text(errors='replace')
 def count(severity):
  matches=re.findall(r'^'+severity+r'\s*:\s*(\d+)\s*$',log,re.M)
  return int(matches[-1]) if matches else None
 errors=count('UVM_ERROR');fatals=count('UVM_FATAL');warnings=count('UVM_WARNING')
 summary=re.search(r'\[TESTPLAN_RESULT\] case=(\S+) checks=(\d+) failures=(\d+) read_bytes=(\d+)',log)
 if name=='indirect_smoke':
  smoke=re.search(r'\[QSPI_COMPARE_SUMMARY\] Compared (\d+) words .*mismatches=(\d+)',log)
  if smoke: summary=re.match(r'(\S+) (\d+) (\d+) (\d+)',f'indirect_smoke {smoke[1]} {smoke[2]} {int(smoke[1])*4}')
 passed=code==0 and errors==0 and fatals==0 and summary is not None and int(summary[3])==0
 result={'case':name,'sequence':sequence,'test':tests[name],'seed':a.seed,'ids':CASES[name],'status':'PASS' if passed else 'FAIL','returncode':code,'timeout':timed_out,'seconds':round(time.monotonic()-start,3),'uvm_errors':errors,'uvm_fatals':fatals,'uvm_warnings':warnings,'completed':summary is not None,'checks':int(summary[2]) if summary else None,'check_failures':int(summary[3]) if summary else None,'read_bytes':int(summary[4]) if summary else None,'log':str(folder/'run.log'),'coverage_file':str(folder/'coverage.dat') if (folder/'coverage.dat').exists() else None,'bins':re.findall(r'\[TESTPLAN_BIN\] (.*)',log),'errors':[x for x in log.splitlines() if x.startswith(('UVM_ERROR','UVM_FATAL','%Error','%Fatal'))][:25]}
 results.append(result)
 print(f"{name}: {result['status']} errors={errors} fatals={fatals} elapsed={result['seconds']}s",flush=True)
 if not passed:
  for line in result['errors'][:4]:print('  '+line,flush=True)
 report={'workbook':manifest['workbook'],'workbook_sha256':manifest['sha256'],'binary':str(binary),'binary_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'cases':results,'scope':'Micron adapted vendor model only; functional SDR/DDR and clock modes limited to bins with passing evidence. Not full vendor/timing signoff.'}
 (a.out/'results.json').write_text(json.dumps(report,indent=2)+'\n')
rows=['# QSPI testplan execution report','',f"Source: `{manifest['workbook']}` (QSPI worksheet).",'', '| Case | Testplan IDs | Result | Checks | Read bytes | UVM errors/fatals |','|---|---|---|---:|---:|---|']
for r in results:rows.append(f"| {r['case']} | {', '.join(r['ids'])} | {r['status']} | {r['checks']} | {r['read_bytes']} | {r['uvm_errors']}/{r['uvm_fatals']} |")
rows+=['','## Coverage limits','','Execution PASS means that listed test passed, not that the whole workbook feature is closed. Macronix and Infineon vendor bins are not tested. Independent CPHA selection is absent from the RTL interface; CKMODE selects the documented modes 0/3. QSPI_1 is marked WAIVE in the workbook and clock frequencies are TBD; the monitor checks the configured bench clocks. Automatic polling supports 1–4 received bytes; DLR>3 buckets are exercised as negative cases. DMA tests do not model an external DMA engine. The testplan configuration models 5 ns data/OE pad propagation and zero added SCLK delay to separate vendor DDR sampling events; DDR timing closure is not established by this assumption. Four-state/timing signoff and all vendor-model cancellation paths remain unproven.','']
(a.out/'REPORT.md').write_text('\n'.join(rows))
raise SystemExit(0 if all(r['status']=='PASS' for r in results) else 1)
