`ifndef QSPI_ABORT_SEQ_SVH
`define QSPI_ABORT_SEQ_SVH

// QSPI abort seq.
class qspi_abort_seq_c extends qspi_feature_base_seq_c;
  `uvm_object_utils(qspi_abort_seq_c)
  rand int unsigned abort_delay_cycles;

  constraint abort_timing_c { abort_delay_cycles inside {[1:3]};
  }
  // Select this scenario's legal fixed inputs for the dedicated Verilator list.
  virtual function void qspi_set_directed_stimulus();
    super.qspi_set_directed_stimulus();
    abort_delay_cycles = 2;
  endfunction

  extern function new(string name = "qspi_abort_seq_c");
  extern virtual task body();
  extern function void post_randomize();
endclass : qspi_abort_seq_c

// Construct this object and initialize its inherited UVM state.
function qspi_abort_seq_c::new(string name = "qspi_abort_seq_c");
  super.new(name, "abort");
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Run this scenario: abort seq. Check failures are reported through UVM.
task qspi_abort_seq_c::body();
  bit [31:0] data;
  bit error;
  int start_failures;
  qspi_initialize_flash_and_controller();
  qspi_program_expected_image(128);
  for(int round=0;round<repeat_count;round++) begin

    // Retain the known-failure anchor in round zero; vary later abort delays.
    if (directed_stimulus) begin
      abort_delay_cycles = (round == 0) ? 2 : 3;
      post_randomize();
    end else if (round == 0) begin
      if (!this.randomize() with { abort_delay_cycles == 2; })
      `uvm_fatal("QSPI_RANDOMIZE", "Cannot randomize abort anchor")
    end else if (!this.randomize())
    `uvm_fatal("QSPI_RANDOMIZE", "Cannot randomize abort timing")
    start_failures=failures;
    qspi_configure_controller();
    qspi_write_register("QSPI_DLR",127);
    qspi_write_register("QSPI_CCR",'h05002503);
    qspi_write_register("QSPI_AR",flash_base_addr);
    qspi_wait_status_bits('h40,'h40);
    qspi_abort_and_flush();
    qspi_configure_controller();
    qspi_read_flash_and_check_data(128,qspi_build_read_command(1),"indirect abort recovery");
    if (qspi_coverage != null) qspi_coverage.abort_cg.sample(0,failures==start_failures);
    start_failures=failures;
    qspi_start_automatic_polling(1,1,1,0,0);
    qspi_wait_status_bits('h40,'h40);
    qspi_abort_and_flush();
    qspi_configure_controller();
    qspi_read_flash_and_check_data(128,qspi_build_read_command(1),"poll abort recovery");
    if (qspi_coverage != null) qspi_coverage.abort_cg.sample(1,failures==start_failures);
    start_failures=failures;
    qspi_enable_memory_mapped_read();
    fork
    begin qspi_access_memory_mapped_word(flash_base_addr+'h4000,data,error);
      qspi_check_condition(error,"pending AHB fetch aborted with ERROR");
    end
    begin
      monitor_vif.wait_frame_start();
      irq_vif.wait_core(abort_delay_cycles);
      qspi_abort_and_flush();
    end
    join
    qspi_configure_controller();
    qspi_read_flash_and_check_data(128,qspi_build_read_command(1),"XIP abort recovery");
    if (qspi_coverage != null) qspi_coverage.abort_cg.sample(2,failures==start_failures);
    qspi_report_scenario_pass($sformatf("abort/recovery all three modes round=%0d",round));
  end
endtask : body

// Report the selected stimulus so failures can be reproduced from the run log.
function void qspi_abort_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s abort_delay_cycles=%0d", get_type_name(), abort_delay_cycles), UVM_LOW)
endfunction : post_randomize

`endif
