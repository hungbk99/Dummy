`ifndef QSPI_CLOCK_RESET_SEQ_SVH
`define QSPI_CLOCK_RESET_SEQ_SVH

class qspi_clock_reset_seq_c extends qspi_feature_base_seq_c;
  `uvm_object_utils(qspi_clock_reset_seq_c)
  rand int unsigned observe_cycles;

  constraint clock_observation_c { observe_cycles inside {[16:64]};
  }
  extern function new(string name = "qspi_clock_reset_seq_c");
  extern virtual task body();
  extern function void post_randomize();
endclass : qspi_clock_reset_seq_c

function qspi_clock_reset_seq_c::new(string name = "qspi_clock_reset_seq_c");
  super.new(name, "clocks");
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_clock_reset_seq_c::body();
  irq_vif.wait_core(observe_cycles);
  verify(uvm_report_server::get_server().get_severity_count(UVM_ERROR)==0,
    "clock/reset observation window completed; SVA checks periods and reset release");
  bin_pass("observed configured clocks; workbook QSPI_1 remains WAIVE (frequencies TBD)");
endtask : body

function void qspi_clock_reset_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s observe_cycles=%0d", get_type_name(), observe_cycles), UVM_LOW)
endfunction : post_randomize

`endif
