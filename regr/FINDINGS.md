# Findings from FU3_IP_Testplan (2).xlsx verification

> Evidence below is the directed baseline, before the constrained-random sequence refactor. The failures remain unresolved; no randomized rerun is claimed.

These are observed functional results, not declarations that every workbook
bin has been closed. The testbench selects the compatibility-adapted Micron
N25Q256A13E model and V2 RTL under `qspi_new`. No QSPI RTL was modified.

## DDR read interoperability — unresolved

The 72 read combinations exercise CKMODE 0/1, SDR/DDR, 1/2/4 lanes, and
1/4/8/16/32/128 bytes. SDR passes in both CKMODE settings. In CKMODE 0,
dual/quad DDR passes, while single-lane 0Dh DDR fails. In CKMODE 1, all
three DDR widths fail. The original strict byte comparisons are retained.

### Single-lane DDR is also failing without the DUT

`vendor_ddr_reference.sv` programs the flash through independent pin-level
stimulus and performs DDR reads without any QSPI RTL or UVM sequence.
Single-lane 0Dh reads fail 14 of 16 bytes in both clock modes; dual/quad
DDR reads pass in both modes. This establishes a limitation in the current
vendor-model/reference combination. It does not establish that single-lane
DDR is an RTL defect. The adapted model's singleIO_output/ck_count scheduling
and original-versus-adapted behavior require further validation on a simulator
that can execute the unmodified vendor source.

### CKMODE 1 DDR address alignment disagrees

The DUT asks for address 0x00010000, but the flash logs address 0x00020000
for the failing mode-3 DDR cases. The model's CP_latchAddr excludes a falling
edge while iAddr is 23/31, whereas the clock manager selects both edges for
DDR and the shifter advances on those strobes. The independent reference
handles that initial excluded edge and passes dual/quad DDR in mode 3.

This is a reproducible DUT/model phase-boundary disagreement. The V2.0
waveform specification is needed before assigning ownership or changing RTL.
The testplan alone does not specify the first DDR address sampling edge.
No expected data was changed and no DDR errors were waived.

Evidence:

- `SIM/qspi_testplan/regression/indirect/run.log`
- `SIM/qspi_testplan/vendor_ddr_reference/run.log`
- RTL: `m_qspi_clk_mgr.sv`, `m_qspi_edge_sel.sv`, `m_qspi_shifter.sv`
- Model: `CP_latchAddr`, `CP_read`, `singleIO_output` in `N25Qxxx.v`

## XIP abort does not return AHB ERROR — functional failure

The abort test starts an uncached AHB read at 0x00014000, waits for a fresh
CSN falling edge, then requests abort before read data is available. In each
of two rounds the AHB response is OK with data 0xffffffff. The testplan
requires ERROR for a pending fetch when abort occurs. Both checks fail.

The bus driver independently observes ERROR correctly for range/write errors
and in the separate short-timeout test. Subsequent indirect reads recover,
so the failure is specifically the aborted pending AHB response, not a general
AHB sampling failure or inability to restart the controller.

The diagnostic run returns after 5,892 HCLK cycles with HRESP=0. APB reads
show CR.ABORT clearing while SR.BUSY remains high. The register clear path
uses i_cs_abort_done from the command sequencer; it does not explicitly wait
for a global acknowledgement from every block. This is a candidate root
cause, not a completed fix. Check the interaction between m_qspi_reg_cfg,
m_qspi_cmd_seq, m_qspi_mm_ctrl and m_qspi_ahb_if against the V2 abort contract.

Evidence:

- `SIM/qspi_testplan/regression/abort/run.log`
- `SIM/qspi_testplan/abort_debug/run.log`
- `SIM/qspi_testplan/timeout_regression/timeout/run.log`

## Testbench defects corrected during bring-up

- APB read error output had been passed as the VIP delay argument. It now
  reports the actual PSLVERR response.
- Reset wait did not hold a UVM phase objection, so the delay could be
  cancelled at time zero. The objection now protects the reset wait.
- Environment initialization used a cast as an assertion side effect. The
  cast now executes independently of whether assertions are enabled.
- Reset assertions allow the first initialization clock before checking state.
- Realtime frequency checks use a 1 ps tolerance rather than exact floating
  point equality (200 ns was represented as 199.99999999999997).
- DMA error tests use the actual map: TXOVRF bit 2, RXUDRF bit 3.
- Abort stimulus synchronizes to a fresh CSN edge rather than a level.

The existing user-approved QSPI_SR=0x4 post-reset waiver remains narrowly
scoped and warns. It does not waive any of the failures above.
