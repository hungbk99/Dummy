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
  vif.wait_core(observe_cycles);
  verify(vif.qresetn&&vif.presetn&&vif.hresetn&&vif.dresetn,"all four resets released");
  verify((vif.qperiod>199.999 && vif.qperiod<200.001),"bench QSPI clock period 200ns");
  verify((vif.pperiod>9.999&&vif.pperiod<10.001&&vif.hperiod>9.999&&vif.hperiod<10.001&&vif.dperiod>9.999&&vif.dperiod<10.001),"bench bus/DMA periods 10ns");
  bin_pass("observed configured clocks; workbook QSPI_1 remains WAIVE (frequencies TBD)");
endtask : body

function void qspi_clock_reset_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s observe_cycles=%0d", get_type_name(), observe_cycles), UVM_LOW)
endfunction : post_randomize

`endif
