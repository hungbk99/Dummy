`ifndef QSPI_SIOO_SEQ_SVH
`define QSPI_SIOO_SEQ_SVH

// QSPI flash continuous-read SIOO first/continuation frames.
class qspi_sioo_seq_c extends qspi_feature_base_seq_c;
  `uvm_object_utils(qspi_sioo_seq_c)
  rand int unsigned continuation_offset;

  constraint continuation_address_c { continuation_offset inside {256,512,768};
  }
  // Select this scenario's legal fixed inputs for the dedicated Verilator list.
  virtual function void qspi_set_directed_stimulus();
    super.qspi_set_directed_stimulus();
    continuation_offset = 256;
  endfunction

  extern function new(string name = "qspi_sioo_seq_c");
  extern virtual task body();
  extern function void post_randomize();
endclass : qspi_sioo_seq_c

// Construct this object and initialize its inherited UVM state.
function qspi_sioo_seq_c::new(string name = "qspi_sioo_seq_c");
  super.new(name, "sioo");
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Run this scenario: flash continuous-read SIOO first/continuation frames. Check failures are reported through UVM.
task qspi_sioo_seq_c::body();
  bit [31:0] data;
  bit error;
  int first_edges,second_edges,before_edges;
  qspi_initialize_flash_and_controller();
  qspi_program_expected_image(1024);
  qspi_write_flash_configuration('h81,'h43);

  // VCR XIP enabled, four dummy cycles.
  qspi_configure_controller();
  qspi_write_register("QSPI_CCR",'h1f102deb);
  irq_vif.wait_core(8);
  before_edges=monitor_vif.sclk_rises;
  qspi_access_memory_mapped_word(flash_base_addr,data,error);
  qspi_check_condition(!error, "SIOO first read response");
  qspi_data_integrity_check(data, image[0], $sformatf("SIOO first address=%08h ",flash_base_addr));
  read_bytes+=4;
  qspi_wait_controller_idle();
  first_edges=monitor_vif.sclk_rises-before_edges;
  before_edges=monitor_vif.sclk_rises;
  qspi_access_memory_mapped_word(flash_base_addr+continuation_offset,data,error);
  qspi_check_condition(!error, "SIOO continuation read response");
  qspi_data_integrity_check(data, image[continuation_offset/4], $sformatf("SIOO continuation address=%08h ",flash_base_addr+continuation_offset));
  read_bytes+=4;
  qspi_wait_controller_idle();
  second_edges=monitor_vif.sclk_rises-before_edges;
  qspi_check_condition(first_edges-second_edges==8,"SIOO continuation omits eight instruction clocks");
  qspi_report_scenario_pass("flash continuous-read SIOO first/continuation frames");
endtask : body

// Report the selected stimulus so failures can be reproduced from the run log.
function void qspi_sioo_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s continuation_offset=%0d", get_type_name(), continuation_offset), UVM_LOW)
endfunction : post_randomize

`endif
