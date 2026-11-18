`ifndef QSPI_MACROS_SVH
`define QSPI_MACROS_SVH

// System AHB window: 0x3000_0000 through 0x30ff_ffff (16 MiB).
// Indirect AR commands and expected-image indices remain flash offsets.
`define QSPI_AHB_SYSTEM_BASE 32'h3000_0000
`define QSPI_AHB_WINDOW_BYTES 32'h0100_0000
`define QSPI_AHB_FSIZE 23
`define QSPI_FLASH_PAGE_BYTES 256
`define QSPI_AHB_MAX_BURST_BYTES 1024

`endif
