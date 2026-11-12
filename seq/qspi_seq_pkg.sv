`ifndef QSPI_SEQ_PKG_SV
`define QSPI_SEQ_PKG_SV

package qspi_seq_pkg;
  import uvm_pkg::*;
  import apb_enum_pkg::*;
  import apb_master_pkg::*;
  import base_pkg::*;
  import qspi_env_pkg::*;

  `include "uvm_macros.svh"
  `include "qspi_base_seq.svh"
  `include "qspi_reg_access_seq.svh"
  `include "qspi_transfer_base_seq.svh"
  `include "qspi_indirect_seq.svh"
  `include "qspi_feature_base_seq.svh"
  `include "qspi_register_access_seq.svh"
  `include "qspi_clock_reset_seq.svh"
  `include "qspi_indirect_matrix_seq.svh"
  `include "qspi_frame_format_seq.svh"
  `include "qspi_fifo_seq.svh"
  `include "qspi_polling_seq.svh"
  `include "qspi_xip_seq.svh"
  `include "qspi_ahb_timeout_seq.svh"
  `include "qspi_mode_switch_seq.svh"
  `include "qspi_interrupt_seq.svh"
  `include "qspi_abort_seq.svh"
  `include "qspi_dma_seq.svh"
  `include "qspi_sioo_seq.svh"
  `include "qspi_delay_seq.svh"

endpackage: qspi_seq_pkg

`endif//QSPI_SEQ_PKG_SV  
