`ifndef QSPI_AHB_TIMEOUT_SEQ_SVH
`define QSPI_AHB_TIMEOUT_SEQ_SVH

// QSPI AHB timeout and abort recovery.
class qspi_ahb_timeout_seq_c extends qspi_feature_base_seq_c;
  `uvm_object_utils(qspi_ahb_timeout_seq_c)
  rand int unsigned settle_cycles;

  constraint timeout_setup_c { settle_cycles inside {[4:12]};
  }
  // Select this scenario's legal fixed inputs for the dedicated Verilator list.
  virtual function void qspi_set_directed_stimulus();
    super.qspi_set_directed_stimulus();
    settle_cycles = 8;
  endfunction

  extern function new(string name = "qspi_ahb_timeout_seq_c");
  extern virtual task body();
  extern function void post_randomize();
endclass : qspi_ahb_timeout_seq_c

// Construct this object and initialize its inherited UVM state.
function qspi_ahb_timeout_seq_c::new(string name = "qspi_ahb_timeout_seq_c");
  super.new(name, "timeout");
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Run this scenario: AHB timeout and abort recovery. Check failures are reported through UVM.
task qspi_ahb_timeout_seq_c::body();
  bit [31:0] data;
  bit error;
  qspi_initialize_flash_and_controller();
  qspi_enable_memory_mapped_read();
  irq_vif.wait_core(settle_cycles);
  qspi_access_memory_mapped_word(flash_base_addr,data,error);
  qspi_check_condition(error,"short AHB timeout returns ERROR");
  qspi_abort_and_flush();
  qspi_report_scenario_pass("AHB timeout and abort recovery");
endtask : body

// Report the selected stimulus so failures can be reproduced from the run log.
function void qspi_ahb_timeout_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s settle_cycles=%0d", get_type_name(), settle_cycles), UVM_LOW)
endfunction : post_randomize

`endif
