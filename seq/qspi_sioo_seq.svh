`ifndef QSPI_SIOO_SEQ_SVH
`define QSPI_SIOO_SEQ_SVH

class qspi_sioo_seq_c extends qspi_feature_base_seq_c;
  `uvm_object_utils(qspi_sioo_seq_c)
  rand int unsigned continuation_offset;

  constraint continuation_address_c { continuation_offset inside {256,512,768};
  }
  extern function new(string name = "qspi_sioo_seq_c");
  extern virtual task body();
  extern function void post_randomize();
endclass : qspi_sioo_seq_c

function qspi_sioo_seq_c::new(string name = "qspi_sioo_seq_c");
  super.new(name, "sioo");
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_sioo_seq_c::body();
  bit [31:0] data;
  bit error;
  int first_edges,second_edges,before_edges;
  initialize();
  prepare_image(1024);
  qspi_flash_write_config('h81,'h43);

  // VCR XIP enabled, four dummy cycles.
  configure();
  qspi_write_reg("QSPI_CCR",'h1f102deb);
  irq_vif.wait_core(8);
  before_edges=signals.sclk_rises;
  ahb_access(flash_base_addr,data,error);
  verify(!error&&data===image[0],"SIOO first EB frame data");
  qspi_wait_idle();
  first_edges=signals.sclk_rises-before_edges;
  before_edges=signals.sclk_rises;
  ahb_access(flash_base_addr+continuation_offset,data,error);
  verify(!error&&data===image[continuation_offset/4],"SIOO continuation frame data");
  qspi_wait_idle();
  second_edges=signals.sclk_rises-before_edges;
  verify(first_edges-second_edges==8,"SIOO continuation omits eight instruction clocks");
  bin_pass("flash continuous-read SIOO first/continuation frames");
endtask : body

function void qspi_sioo_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s continuation_offset=%0d", get_type_name(), continuation_offset), UVM_LOW)
endfunction : post_randomize

`endif
