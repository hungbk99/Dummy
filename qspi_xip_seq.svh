`ifndef QSPI_XIP_SEQ_SVH
`define QSPI_XIP_SEQ_SVH

class qspi_xip_seq_c extends qspi_feature_base_seq_c;
  `uvm_object_utils(qspi_xip_seq_c)
  rand int unsigned transfer_bytes;
  rand int unsigned lane_count;

  constraint xip_transfer_c {
    transfer_bytes inside {1,4,8,16,32,128,256,512,1024};
    lane_count inside {1,2,4};
  }
  extern function new(string name = "qspi_xip_seq_c");
  extern virtual task body();
  extern function void post_randomize();
endclass : qspi_xip_seq_c

function qspi_xip_seq_c::new(string name = "qspi_xip_seq_c");
  super.new(name, "xip");
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_xip_seq_c::body();
  int sizes[9]='{1,4,8,16,32,128,256,512,1024};
  bit [31:0] data;
  bit error;
  int before_frames;
  initialize();
  prepare_image(1024);
  for(int lane=1;lane<=4;lane*=2) begin
    foreach (sizes[n]) begin
      int requested_bytes = sizes[n];
`ifdef VERILATOR
      transfer_bytes = requested_bytes;
      lane_count = lane;
      post_randomize();
`else
      if (!this.randomize() with { transfer_bytes == requested_bytes; lane_count == lane; })
        `uvm_fatal("QSPI_RANDOMIZE", "Cannot randomize XIP size/lane bin")
`endif
      enter_xip(lane_count);
      xip_check(transfer_bytes,1);
      bin_pass($sformatf("XIP lanes=%0d bytes=%0d",lane_count,transfer_bytes));
    end
  end
  enter_xip();
  xip_check(4);
  before_frames=monitor_vif.frames;
  xip_check(4);
  verify(monitor_vif.frames==before_frames,"cache hit creates no serial frame");
  ahb_access('h00200000,data,error);
  verify(error,"out-of-range AHB address returns ERROR");
  ahb_access(flash_base_addr,data,error,1);
  verify(error,"AHB writes return ERROR");
  bin_pass("XIP sizes, cache hit, range/write errors");
endtask : body

function void qspi_xip_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s transfer_bytes=%0d lane_count=%0d", get_type_name(), transfer_bytes, lane_count), UVM_LOW)
endfunction : post_randomize

`endif
