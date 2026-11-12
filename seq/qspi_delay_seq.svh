`ifndef QSPI_DELAY_SEQ_SVH
`define QSPI_DELAY_SEQ_SVH

class qspi_delay_seq_c extends qspi_feature_base_seq_c;
  `uvm_object_utils(qspi_delay_seq_c)
  rand int unsigned delay_periods;

  constraint chip_select_timing_c { delay_periods inside {0,1,3};
  }
  extern function new(string name = "qspi_delay_seq_c");
  extern virtual task body();
  extern function void post_randomize();
endclass : qspi_delay_seq_c

function qspi_delay_seq_c::new(string name = "qspi_delay_seq_c");
  super.new(name, "delays");
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_delay_seq_c::body();
  bit [31:0] values[3]='{0,1,3};
  initialize();
  foreach(values[n]) begin
    int level;
    level=values[n];
    if (!this.randomize() with { delay_periods == level; })
    `uvm_fatal("QSPI_RANDOMIZE", "Cannot randomize CSN timing bin")
    configure();
    qspi_write_reg("QSPI_DLY",(delay_periods<<16)|(delay_periods<<8)|delay_periods);
    repeat(2) begin
      qspi_write_reg("QSPI_CCR",'h106);
      qspi_wait_complete();
      verify(vif.setup_ns+0.001>=level*800.0,$sformatf("DLY.CSS=%0d minimum setup",level));
      verify(vif.hold_ns+0.001>=level*800.0,$sformatf("DLY.CSH=%0d minimum hold",level));
      verify(vif.idle_ns+0.001>=level*800.0,$sformatf("DLY.CSIDLE=%0d minimum idle",level));
    end
    m_qspi_env.m_coverage.delay_cg.sample(delay_periods,delay_periods,delay_periods,failures==0);
    bin_pass($sformatf("DLY CSS/CSH/CSIDLE=%0d",level));
  end
endtask : body

function void qspi_delay_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s delay_periods=%0d", get_type_name(), delay_periods), UVM_LOW)
endfunction : post_randomize

`endif
