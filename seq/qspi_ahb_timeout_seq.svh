`ifndef QSPI_AHB_TIMEOUT_SEQ_SVH
`define QSPI_AHB_TIMEOUT_SEQ_SVH

class qspi_ahb_timeout_seq_c extends qspi_feature_base_seq_c;
  `uvm_object_utils(qspi_ahb_timeout_seq_c)
  rand int unsigned settle_cycles;

  constraint timeout_setup_c { settle_cycles inside {[4:12]};
  }
  extern function new(string name = "qspi_ahb_timeout_seq_c");
  extern virtual task body();
  extern function void post_randomize();
endclass : qspi_ahb_timeout_seq_c

function qspi_ahb_timeout_seq_c::new(string name = "qspi_ahb_timeout_seq_c");
  super.new(name, "timeout");
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_ahb_timeout_seq_c::body();
  bit [31:0] data;
  bit error;
  initialize();
  enter_xip();
  vif.wait_core(settle_cycles);
  vif.ahb_access(flash_base_addr,data,error);
  verify(error,"short AHB timeout returns ERROR");
  abort_controller();
  bin_pass("AHB timeout and abort recovery");
endtask : body

function void qspi_ahb_timeout_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s settle_cycles=%0d", get_type_name(), settle_cycles), UVM_LOW)
endfunction : post_randomize

`endif
