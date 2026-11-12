#!/usr/bin/env python3
"""Consolidate actual regression logs against the extracted workbook IDs."""
import json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SIM=Path('/home/hungle/workspace/SIM/qspi_testplan')
plan=json.loads((ROOT/'regr/qspi_testplan.json').read_text())
main=json.loads((SIM/'regression/results.json').read_text())
extra=json.loads((SIM/'timeout_regression/results.json').read_text())
cases=main['cases']+extra['cases']
passed=sum(c['status']=='PASS' for c in cases)
randomized=all('test' in c and 'seed' in c for c in cases)
summary={'workbook':plan['workbook'],'workbook_sha256':plan['sha256'],'test_count':len(cases),'passed':passed,'failed':len(cases)-passed,'plan_closed':False,'constrained_random_execution':randomized,'scope':'Micron adapted vendor model; see documented simulation/coverage limits','cases':cases}
(SIM/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
rows=['# QSPI testplan verification summary','',f"Source: `{plan['workbook']}`, QSPI worksheet (8 IDs).",f"Workbook SHA-256: `{plan['sha256']}`.",'',f"**{len(cases)} executable tests: {passed} PASS, {len(cases)-passed} FAIL. Full testplan closure: NO.**",'', 'The workbook was not modified. Historical workbook statuses were not treated as evidence. QSPI RTL was not changed. Tests used Verilator 5.054, V2 RTL under `qspi_new`, and the compatibility-adapted Micron N25Q256A13E vendor model. Assertions were enabled.','', '| Case | IDs | Result | Explicit checks | Compared/read bytes |','|---|---|---|---:|---:|']
for c in cases: rows.append(f"| {c['case']} | {', '.join(c['ids'])} | {c['status']} | {c['checks']} | {c['read_bytes']} |")
rows+=['','The check counter counts explicit sequence checks; delegated register/VIP checks and assertions are additional. PASS does not mean every cover bin for the associated ID is closed.','', '## Results by workbook item','', '| ID | Observed result | Coverage qualification |','|---|---|---|']
notes={
'QSPI_0':('PASS','17-register reset/readback, reserved regions and V2 DLY/DCR; approved SR.TXFTF warning retained.'),
'QSPI_1':('WAIVE in workbook; bench checks PASS','Four configured clocks and POR releases checked; required frequencies are TBD. Individual system-reset injections not closed.'),
'QSPI_2':('PARTIAL / DDR FAIL','SDR passes in both CKMODE settings; FIFO/frame/DLY cases pass. Read matrix: 48/72 pass, 24 fail. Single DDR model limitation; mode-3 DDR unresolved.'),
'QSPI_3':('PASS for implemented Micron cases','AND/OR, lengths 1–4, zero mask, timeout and real WIP transition; illegal longer lengths rejected. Other vendors and polling lane/rate cross not closed.'),
'QSPI_4':('PASS for implemented Micron cases','SDR XIP 1–1024 bytes, single/dual/quad, cache hit, range/write errors, short AHB timeout and SIOO. DDR XIP and CPU execution not closed.'),
'QSPI_5':('PASS for implemented Micron cases','Two indirect→polling→XIP→indirect cycles with data comparison; full vendor/rate/random cross not closed.'),
'QSPI_6':('PASS for implemented checks','All eight IRQ flag/enable sources, level behavior and independent clears; arbitrary simultaneous non-threshold set/clear not exhaustively closed.'),
'QSPI_7':('FAIL','Indirect/polling/XIP restart checks pass, but aborted pending AHB read returns OK in two rounds; specification requires ERROR.')}
for item in plan['items']:
 status,note=notes[item['id']];rows.append(f"| {item['id']} | {status} | {note} |")
rows+=['','## Failure triage','','- **Single-lane DDR:** independent `vendor_ddr_reference.sv` also fails 14/16 bytes in each clock mode without the DUT. This result cannot be assigned to RTL yet.','- **Mode-3 DDR:** the independent dual/quad reference passes, but the DUT/model run shifts requested address 0x10000 to 0x20000. The first DDR address edge needs comparison with the V2 timing specification.','- **XIP abort:** two fresh-frame aborts return HRESP=OK/data=0xffffffff. Separate range/write/timeout tests observe AHB ERROR correctly. The abort completion/global-idle path needs RTL review.','','See [FINDINGS.md](regr/FINDINGS.md) for evidence and source paths. All data comparisons retain error severity; no new failures were waived.','','## Limits and reproduction','','Macronix/Infineon vendor bins remain uncovered. The testplan model includes 5 ns DUT data/OE pad delay and zero added SCLK delay; that is a simulation assumption, not timing closure. DMA TX request and cancellation are checked and clear stimulus is driven; full external DMA streaming/clear-response coverage is not closed. Adapted vendor model four-state/cancellation equivalence is not certified.','','Run from `dv/qspi`:','','```sh','python3 regr/run_all.py','```','','Reports and logs: `/home/hungle/workspace/SIM/qspi_testplan/` (`summary.json`, `regression/`, `timeout_regression/`, `vendor_ddr_reference/`). Configuration and bin details: [regr/README.md](regr/README.md).','']
if not randomized:
 rows[2:2]=['> Directed baseline before the sequence/UVM-test refactor. These counts do not validate the new constrained-random classes; their runtime requires an SMT solver.', '']
(ROOT/'TESTPLAN_REPORT.md').write_text('\n'.join(rows))
print(f'Consolidated {len(cases)} cases: {passed} PASS, {len(cases)-passed} FAIL; wrote TESTPLAN_REPORT.md')
