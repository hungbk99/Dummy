`ifndef QSPI_DELAY_SEQ_SVH
`define QSPI_DELAY_SEQ_SVH

// QSPI delay seq.
class qspi_delay_seq_c extends qspi_feature_base_seq_c;
  `uvm_object_utils(qspi_delay_seq_c)
  rand int unsigned delay_periods;

  constraint chip_select_timing_c { delay_periods inside {0,1,3};
  }
  // Select this scenario's legal fixed inputs for the dedicated Verilator list.
  virtual function void qspi_set_directed_stimulus();
    super.qspi_set_directed_stimulus();
    delay_periods = 0;
  endfunction

  extern function new(string name = "qspi_delay_seq_c");
  extern virtual task body();
  extern function void post_randomize();
endclass : qspi_delay_seq_c

// Construct this object and initialize its inherited UVM state.
function qspi_delay_seq_c::new(string name = "qspi_delay_seq_c");
  super.new(name, "delays");
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Run this scenario: delay seq. Check failures are reported through UVM.
task qspi_delay_seq_c::body();
  bit [31:0] values[3]='{0,1,3};
  qspi_initialize_flash_and_controller();
  foreach(values[n]) begin
    int level;
    int setup_before,hold_before,idle_before,errors_before;
    level=values[n];
    if (directed_stimulus) begin
      delay_periods = level;
      post_randomize();
    end else if (!this.randomize() with { delay_periods == level; })
    `uvm_fatal("QSPI_RANDOMIZE", "Cannot randomize CSN timing bin")
    qspi_configure_controller();
    qspi_write_register("QSPI_DLY",(delay_periods<<16)|(delay_periods<<8)|delay_periods);
    setup_before=monitor_vif.setup_checks;
    hold_before=monitor_vif.hold_checks;
    idle_before=monitor_vif.idle_checks;
    errors_before=monitor_vif.timing_errors;
    // PRESCALER=2: SCLK period is 4 core cycles = 20 ns at 200 MHz.
    monitor_vif.check_timing(level*20.0,level*20.0,level*20.0);
    repeat(2) begin
      qspi_write_register("QSPI_CCR",'h106);
      qspi_wait_transfer_complete();
    end
    monitor_vif.stop_timing_checks();
    qspi_check_condition(monitor_vif.setup_checks-setup_before==2,"SVA checked setup for both frames");
    qspi_check_condition(monitor_vif.hold_checks-hold_before==2,"SVA checked hold for both frames");
    qspi_check_condition(monitor_vif.idle_checks-idle_before==2,"SVA checked idle before both frames");
    qspi_check_condition(monitor_vif.timing_errors==errors_before,"CS timing SVA passed");
    if (qspi_coverage != null) qspi_coverage.delay_cg.sample(delay_periods,delay_periods,delay_periods,failures==0);
    qspi_report_scenario_pass($sformatf("DLY CSS/CSH/CSIDLE=%0d",level));
  end
endtask : body

// Report the selected stimulus so failures can be reproduced from the run log.
function void qspi_delay_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s delay_periods=%0d", get_type_name(), delay_periods), UVM_LOW)
endfunction : post_randomize

`endif
