`ifndef QSPI_REGISTER_ACCESS_SEQ_SVH
`define QSPI_REGISTER_ACCESS_SEQ_SVH

class qspi_register_access_seq_c extends qspi_feature_base_seq_c;
  `uvm_object_utils(qspi_register_access_seq_c)
  rand int unsigned reserved_offset;
  rand int unsigned register_pattern;

  constraint register_access_c {
    reserved_offset inside {[32'h44:32'hfc]};
    reserved_offset[1:0] == 0;
    register_pattern != 0;
  }
  extern function new(string name = "qspi_register_access_seq_c");
  extern virtual task body();
  extern function void post_randomize();
  extern virtual task expected_apb_error(bit [31:0] address,bit write_access=0);
endclass : qspi_register_access_seq_c

function qspi_register_access_seq_c::new(string name = "qspi_register_access_seq_c");
  super.new(name, "registers");
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_register_access_seq_c::body();
  qspi_reg_rw_seq_c registers_seq;
  registers_seq=qspi_reg_rw_seq_c::type_id::create("registers");
  registers_seq.m_env=m_env;
  registers_seq.start(null);
  configure();
  for(int address='h44;address<='hfc;address+=4) begin
    expected_apb_error(address);
    expected_apb_error(address,1);
  end

  // Reserved bits in DLY and the removed DCR.CSHT must read back zero.
  qspi_write_reg("QSPI_DLY",register_pattern | 32'hff000000);
  begin bit [31:0] data;
    read_reg("QSPI_DLY",data);
    verify(data==(register_pattern & 32'h00ffffff),"DLY reserved bits read zero");
  end
  qspi_write_reg("QSPI_DCR",'h001f0701);
  begin bit [31:0] data;
    read_reg("QSPI_DCR",data);
    verify(data=='h001f0001,"removed DCR.CSHT reads zero");
  end
  bin_pass("mapped/unmapped/reserved APB");
  expected_apb_error(reserved_offset);
  expected_apb_error(reserved_offset,1);
endtask : body

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_register_access_seq_c::expected_apb_error(bit [31:0] address,bit write_access=0);
  apb_master_seq request;
  bit [31:0] data;
  request=apb_master_seq::type_id::create("negative_apb");
  request.set_sequencer(m_qspi_env.m_apb_env.master_agent.m_apb_master_sequencer);
  if(write_access) request.apb_master_write(address,'hffffffff,0,ERROR);
  else request.apb_master_read(address,data,0,ERROR);
endtask : expected_apb_error

function void qspi_register_access_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s reserved_offset=%0d register_pattern=%0d", get_type_name(), reserved_offset, register_pattern), UVM_LOW)
endfunction : post_randomize

`endif
