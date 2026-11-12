`ifndef QSPI_ABORT_SEQ_SVH
`define QSPI_ABORT_SEQ_SVH

class qspi_abort_seq_c extends qspi_feature_base_seq_c;
  `uvm_object_utils(qspi_abort_seq_c)
  rand int unsigned abort_delay_cycles;

  constraint abort_timing_c { abort_delay_cycles inside {[1:3]};
  }
  extern function new(string name = "qspi_abort_seq_c");
  extern virtual task body();
  extern function void post_randomize();
endclass : qspi_abort_seq_c

function qspi_abort_seq_c::new(string name = "qspi_abort_seq_c");
  super.new(name, "abort");
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_abort_seq_c::body();
  bit [31:0] data;
  bit error;
  int start_failures;
  initialize();
  prepare_image(128);
  for(int round=0;round<repeat_count;round++) begin

    // Retain the known-failure anchor in round zero; vary later abort delays.
    if (round == 0) begin
      if (!this.randomize() with { abort_delay_cycles == 2; })
      `uvm_fatal("QSPI_RANDOMIZE", "Cannot randomize abort anchor")
    end else if (!this.randomize())
    `uvm_fatal("QSPI_RANDOMIZE", "Cannot randomize abort timing")
    start_failures=failures;
    configure();
    qspi_write_reg("QSPI_DLR",127);
    qspi_write_reg("QSPI_CCR",'h05002503);
    qspi_write_reg("QSPI_AR",flash_base_addr);
    wait_status('h40,'h40);
    abort_controller();
    configure();
    check_read(4,read_ccr(1),"indirect abort recovery");
    m_qspi_env.m_coverage.abort_cg.sample(0,failures==start_failures);
    start_failures=failures;
    poll_start(1,1,1,0,0);
    wait_status('h40,'h40);
    abort_controller();
    configure();
    check_read(4,read_ccr(1),"poll abort recovery");
    m_qspi_env.m_coverage.abort_cg.sample(1,failures==start_failures);
    start_failures=failures;
    enter_xip();
    fork
    begin ahb_access(flash_base_addr+'h4000,data,error);
      verify(error,"pending AHB fetch aborted with ERROR");
    end
    begin
      signals.wait_frame_start();
      irq_vif.wait_core(abort_delay_cycles);
      abort_controller();
    end
    join
    configure();
    check_read(4,read_ccr(1),"XIP abort recovery");
    m_qspi_env.m_coverage.abort_cg.sample(2,failures==start_failures);
    bin_pass($sformatf("abort/recovery all three modes round=%0d",round));
  end
endtask : body

function void qspi_abort_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s abort_delay_cycles=%0d", get_type_name(), abort_delay_cycles), UVM_LOW)
endfunction : post_randomize

`endif
