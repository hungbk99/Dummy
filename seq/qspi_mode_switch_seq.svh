`ifndef QSPI_MODE_SWITCH_SEQ_SVH
`define QSPI_MODE_SWITCH_SEQ_SVH

// QSPI mode switch seq.
class qspi_mode_switch_seq_c extends qspi_feature_base_seq_c;
  `uvm_object_utils(qspi_mode_switch_seq_c)
  rand int unsigned indirect_bytes;

  constraint mixed_transfer_c { indirect_bytes inside {4,8,16,32};
  }
  // Select this scenario's legal fixed inputs for the dedicated Verilator list.
  virtual function void qspi_set_directed_stimulus();
    super.qspi_set_directed_stimulus();
    indirect_bytes = 16;
  endfunction

  extern function new(string name = "qspi_mode_switch_seq_c");
  extern virtual task body();
  extern function void post_randomize();
endclass : qspi_mode_switch_seq_c

// Construct this object and initialize its inherited UVM state.
function qspi_mode_switch_seq_c::new(string name = "qspi_mode_switch_seq_c");
  super.new(name, "mixed");
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Run this scenario: mode switch seq. Check failures are reported through UVM.
task qspi_mode_switch_seq_c::body();
  qspi_initialize_flash_and_controller();
  qspi_program_expected_image(128);
  for(int round=0;round<repeat_count;round++) begin
    qspi_configure_controller();
    qspi_read_flash_and_check_data(indirect_bytes,qspi_build_read_command(1),"mixed indirect");
    qspi_start_automatic_polling(0,1);
    qspi_wait_status_bits('h50,'h10);
    qspi_enable_memory_mapped_read();
    qspi_read_xip_and_check_data(128);
    qspi_configure_controller();
    qspi_read_flash_and_check_data(indirect_bytes,qspi_build_read_command(4),"mixed quad indirect");
    qspi_report_scenario_pass($sformatf("indirect -> poll -> XIP -> indirect round=%0d",round));
  end
endtask : body

// Report the selected stimulus so failures can be reproduced from the run log.
function void qspi_mode_switch_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s indirect_bytes=%0d", get_type_name(), indirect_bytes), UVM_LOW)
endfunction : post_randomize

`endif
