`ifndef QSPI_ENV_PKG_SV
`define QSPI_ENV_PKG_SV

package qspi_env_pkg;
 import uvm_pkg::*;
 import apb_enum_pkg::*;
 import apb_global_pkg::*;
 import apb_env_pkg::*;
 import ahb_package::*;
  import base_pkg::*;

  `include "uvm_macros.svh"
  `include "qspi_coverage.svh"
  `include "qspi_ahb_access_seq.svh"
  `include "qspi_bus_access.svh"
  `include "qspi_virtual_sequencer.svh"
  `include "qspi_env.svh"

endpackage: qspi_env_pkg

`endif//QSPI_ENV_PKG_SV
