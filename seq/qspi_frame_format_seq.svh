`ifndef QSPI_FRAME_FORMAT_SEQ_SVH
`define QSPI_FRAME_FORMAT_SEQ_SVH

class qspi_frame_format_seq_c extends qspi_feature_base_seq_c;
  `uvm_object_utils(qspi_frame_format_seq_c)
  rand int unsigned address_bytes;
  rand int unsigned alternate_bytes;
  rand int unsigned dummy_cycles;
  rand int unsigned alternate_data;

  constraint frame_format_c {
    address_bytes inside {[1:4]};
    alternate_bytes inside {[1:4]};
    dummy_cycles inside {0,31};
  }
  extern function new(string name = "qspi_frame_format_seq_c");
  extern virtual task body();
  extern function void post_randomize();
endclass : qspi_frame_format_seq_c

function qspi_frame_format_seq_c::new(string name = "qspi_frame_format_seq_c");
  super.new(name, "frames");
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_frame_format_seq_c::body();
  bit [31:0] ccr;
  int before_edges,expected;
  initialize();
  for(int address_count=1;address_count<=4;address_count++) begin
    for(int alternate_count=1;alternate_count<=4;alternate_count++) begin
      int dummy;
      dummy=(alternate_count==4)?31:0;
      if (!this.randomize() with {
        address_bytes == address_count;
        alternate_bytes == alternate_count;
        dummy_cycles == dummy;
      }) `uvm_fatal("QSPI_RANDOMIZE", "Cannot randomize frame format")
      ccr='h00000500;

      // Single instruction/address, no data, unknown flash NOP opcode 00h.
      ccr[13:12]=2'(address_bytes-1);
      ccr[15:14]=1;
      ccr[17:16]=2'(alternate_bytes-1);
      ccr[22:18]=5'(dummy_cycles);
      qspi_write_reg("QSPI_ABR",alternate_data);
      before_edges=signals.sclk_rises;
      qspi_write_reg("QSPI_CCR",ccr);
      qspi_write_reg("QSPI_AR",0);
      qspi_wait_complete();
      expected=8+address_bytes*8+alternate_bytes*8+dummy;
      verify(signals.sclk_rises-before_edges==expected,$sformatf("frame address=%0d alternate=%0d dummy=%0d SCLK count expected=%0d actual=%0d",address_bytes,alternate_bytes,dummy,expected,signals.sclk_rises-before_edges));
      m_qspi_env.m_coverage.frame_cg.sample(address_bytes,alternate_bytes,dummy_cycles,
        signals.sclk_rises-before_edges==expected && failures==0);
      bin_pass($sformatf("frame address=%0d alternate=%0d dummy=%0d",address_bytes,alternate_bytes,dummy));
    end
  end
endtask : body

function void qspi_frame_format_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s address_bytes=%0d alternate_bytes=%0d dummy_cycles=%0d alternate_data=%0d", get_type_name(), address_bytes, alternate_bytes, dummy_cycles, alternate_data), UVM_LOW)
endfunction : post_randomize

`endif
