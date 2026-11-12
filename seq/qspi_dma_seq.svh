`ifndef QSPI_DMA_SEQ_SVH
`define QSPI_DMA_SEQ_SVH

class qspi_dma_seq_c extends qspi_feature_base_seq_c;
  `uvm_object_utils(qspi_dma_seq_c)
  rand int unsigned clear_pulse_cycles;

  constraint dma_clear_c { clear_pulse_cycles inside {[4:8]};
  }
  extern function new(string name = "qspi_dma_seq_c");
  extern virtual task body();
  extern function void post_randomize();
endclass : qspi_dma_seq_c

function qspi_dma_seq_c::new(string name = "qspi_dma_seq_c");
  super.new(name, "dma");
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_dma_seq_c::body();
  bit [31:0] cr;
  initialize();
  configure();
  qspi_write_reg("QSPI_DMACR",1);
  qspi_write_reg("QSPI_DLR",15);
  qspi_write_reg("QSPI_CCR",'h01002502);
  qspi_write_reg("QSPI_AR",flash_base_addr);
  vif.wait_core(12);
  verify(vif.dma_tx_req,"DMA TX request when FIFO has free space");
  @(negedge vif.dclk);
  vif.dma_tx_clr=1;
  repeat(clear_pulse_cycles) @(negedge vif.dclk);
  vif.dma_tx_clr=0;
  abort_controller();
  vif.wait_core(12);
  verify(!vif.dma_tx_req&&!vif.dma_rx_req,"DMA cancelled after abort");
  bin_pass("DMA TX request/clear and abort cancellation; external DMA engine not modeled");
endtask : body

function void qspi_dma_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s clear_pulse_cycles=%0d", get_type_name(), clear_pulse_cycles), UVM_LOW)
endfunction : post_randomize

`endif
