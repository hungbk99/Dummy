`ifndef QSPI_MODE_SWITCH_SEQ_SVH
`define QSPI_MODE_SWITCH_SEQ_SVH

class qspi_mode_switch_seq_c extends qspi_feature_base_seq_c;
  `uvm_object_utils(qspi_mode_switch_seq_c)
  rand int unsigned indirect_bytes;

  constraint mixed_transfer_c { indirect_bytes inside {4,8,16,32};
  }
  extern function new(string name = "qspi_mode_switch_seq_c");
  extern virtual task body();
  extern function void post_randomize();
endclass : qspi_mode_switch_seq_c

function qspi_mode_switch_seq_c::new(string name = "qspi_mode_switch_seq_c");
  super.new(name, "mixed");
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_mode_switch_seq_c::body();
  initialize();
  prepare_image(128);
  for(int round=0;round<repeat_count;round++) begin
    configure();
    check_read(indirect_bytes,read_ccr(1),"mixed indirect");
    poll_start(0,1);
    wait_status('h50,'h10);
    enter_xip();
    xip_check(128);
    configure();
    check_read(indirect_bytes,read_ccr(4),"mixed quad indirect");
    bin_pass($sformatf("indirect -> poll -> XIP -> indirect round=%0d",round));
  end
endtask : body

function void qspi_mode_switch_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s indirect_bytes=%0d", get_type_name(), indirect_bytes), UVM_LOW)
endfunction : post_randomize

`endif
