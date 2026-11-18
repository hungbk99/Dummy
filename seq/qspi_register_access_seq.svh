`ifndef QSPI_REGISTER_ACCESS_SEQ_SVH
`define QSPI_REGISTER_ACCESS_SEQ_SVH

// QSPI mapped/unmapped/reserved APB.
class qspi_register_access_seq_c extends qspi_feature_base_seq_c;
  `uvm_object_utils(qspi_register_access_seq_c)
  rand int unsigned reserved_offset;
  rand int unsigned register_pattern;

  constraint register_access_c {
    reserved_offset inside {[32'h44:32'hfc]};
    reserved_offset[1:0] == 0;
    register_pattern != 0;
  }
  // Select this scenario's legal fixed inputs for the dedicated Verilator list.
  virtual function void qspi_set_directed_stimulus();
    super.qspi_set_directed_stimulus();
    reserved_offset = 'h44; register_pattern = 'ha5a5_5a5a;
  endfunction

  extern function new(string name = "qspi_register_access_seq_c");
  extern virtual task body();
  extern function void post_randomize();
  extern virtual task qspi_expect_register_access_error(bit [31:0] address,bit write_access=0);
endclass : qspi_register_access_seq_c

// Construct this object and initialize its inherited UVM state.
function qspi_register_access_seq_c::new(string name = "qspi_register_access_seq_c");
  super.new(name, "registers");
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Run this scenario: mapped/unmapped/reserved APB. Check failures are reported through UVM.
task qspi_register_access_seq_c::body();
  qspi_reg_rw_seq_c registers_seq;
  registers_seq=qspi_reg_rw_seq_c::type_id::create("registers");
  registers_seq.base_vseqr = base_vseqr;
  registers_seq.start(null);
  qspi_configure_controller();
  for(int address='h44;address<='hfc;address+=4) begin
    qspi_expect_register_access_error(address);
    qspi_expect_register_access_error(address,1);
  end

  // Reserved bits in DLY and the removed DCR.CSHT must read back zero.
  qspi_write_register("QSPI_DLY",register_pattern | 32'hff000000);
  begin bit [31:0] data;
    qspi_read_register_checked("QSPI_DLY",data);
    qspi_check_condition(data==(register_pattern & 32'h00ffffff),"DLY reserved bits read zero");
  end
  qspi_write_register("QSPI_DCR",'h001f0701);
  begin bit [31:0] data;
    qspi_read_register_checked("QSPI_DCR",data);
    qspi_check_condition(data=='h001f0001,"removed DCR.CSHT reads zero");
  end
  qspi_report_scenario_pass("mapped/unmapped/reserved APB");
  qspi_expect_register_access_error(reserved_offset);
  qspi_expect_register_access_error(reserved_offset,1);
endtask : body

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Expect register access error.
task qspi_register_access_seq_c::qspi_expect_register_access_error(bit [31:0] address,bit write_access=0);
  bit [31:0] data;
  bit error;
  if (write_access) qspi_bus_write32(address, '1, 1);
  else begin
    qspi_bus_read32(address, data, error, 1);
    qspi_check_condition(error, $sformatf("unmapped register read rejected at %08h",address));
  end
endtask : qspi_expect_register_access_error

// Report the selected stimulus so failures can be reproduced from the run log.
function void qspi_register_access_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s reserved_offset=%0d register_pattern=%0d", get_type_name(), reserved_offset, register_pattern), UVM_LOW)
endfunction : post_randomize

`endif
