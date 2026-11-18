`ifndef QSPI_DMA_SEQ_SVH
`define QSPI_DMA_SEQ_SVH

// QSPI DMA TX request/clear and abort cancellation; external DMA engine not modeled.
class qspi_dma_seq_c extends qspi_feature_base_seq_c;
  `uvm_object_utils(qspi_dma_seq_c)
  rand int unsigned clear_pulse_cycles;

  constraint dma_clear_c { clear_pulse_cycles inside {[4:8]};
  }
  // Select this scenario's legal fixed inputs for the dedicated Verilator list.
  virtual function void qspi_set_directed_stimulus();
    super.qspi_set_directed_stimulus();
    clear_pulse_cycles = 4;
  endfunction

  extern function new(string name = "qspi_dma_seq_c");
  extern virtual task body();
  extern function void post_randomize();
endclass : qspi_dma_seq_c

// Construct this object and initialize its inherited UVM state.
function qspi_dma_seq_c::new(string name = "qspi_dma_seq_c");
  super.new(name, "dma");
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Run this scenario: DMA TX request/clear and abort cancellation; external DMA engine not modeled. Check failures are reported through UVM.
task qspi_dma_seq_c::body();
  bit [31:0] cr;
  qspi_initialize_flash_and_controller();
  qspi_program_expected_image(16);
  qspi_configure_controller();
  qspi_write_register("QSPI_DMACR",1);
  qspi_write_register("QSPI_DLR",15);
  qspi_write_register("QSPI_CCR",'h01002502);
  qspi_write_register("QSPI_AR",flash_base_addr);
  irq_vif.wait_core(12);
  qspi_check_condition(dma_vif.tx_req,"DMA TX request when FIFO has free space");
  dma_vif.pulse_tx_clear(clear_pulse_cycles);
  qspi_abort_and_flush();
  irq_vif.wait_core(12);
  qspi_check_condition(!dma_vif.tx_req&&!dma_vif.rx_req,"DMA cancelled after abort");
  qspi_configure_controller();
  qspi_read_flash_and_check_data(16,qspi_build_read_command(1),"DMA abort preserves programmed data");
  qspi_report_scenario_pass("DMA TX request/clear and abort cancellation; external DMA engine not modeled");
endtask : body

// Report the selected stimulus so failures can be reproduced from the run log.
function void qspi_dma_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s clear_pulse_cycles=%0d", get_type_name(), clear_pulse_cycles), UVM_LOW)
endfunction : post_randomize

`endif
