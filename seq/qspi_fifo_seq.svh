`ifndef QSPI_FIFO_SEQ_SVH
`define QSPI_FIFO_SEQ_SVH

// QSPI TX full/overflow, RX full/backpressure/empty and abort flush.
class qspi_fifo_seq_c extends qspi_feature_base_seq_c;
  `uvm_object_utils(qspi_fifo_seq_c)
  rand int unsigned overflow_data;

  constraint overflow_data_c { overflow_data != 0;
  }
  // Select this scenario's legal fixed inputs for the dedicated Verilator list.
  virtual function void qspi_set_directed_stimulus();
    super.qspi_set_directed_stimulus();
    overflow_data = 'h5aa5_1234;
  endfunction

  extern function new(string name = "qspi_fifo_seq_c");
  extern virtual task body();
  extern function void post_randomize();
endclass : qspi_fifo_seq_c

// Construct this object and initialize its inherited UVM state.
function qspi_fifo_seq_c::new(string name = "qspi_fifo_seq_c");
  super.new(name, "fifo");
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Run this scenario: TX full/overflow, RX full/backpressure/empty and abort flush. Check failures are reported through UVM.
task qspi_fifo_seq_c::body();
  bit [31:0] data,sr;
  qspi_initialize_flash_and_controller();
  qspi_program_expected_image(256);

  // Fill TX while disabled, overflow the next write, then abort/flush.
  qspi_configure_controller();
  qspi_write_register("QSPI_CR",'h02000000);
  qspi_write_register("QSPI_CCR",'h01002502);
  qspi_write_register("QSPI_DLR",255);
  for(int i=0;i<32;i++) qspi_write_register("QSPI_DR",image[i]);
  qspi_read_register_checked("QSPI_SR",sr);
  qspi_check_condition(sr[13:8]==32,"TX FIFO full at 32 words");
  qspi_write_register("QSPI_DR",overflow_data);
  qspi_read_register_checked("QSPI_DMASR",data);
  qspi_check_condition(data[2],"TX overflow flag");
  qspi_abort_and_flush();
  qspi_configure_controller();

  // Let RX fill and stall, then drain all data and verify recovery.
  qspi_write_register("QSPI_DLR",255);
  qspi_write_register("QSPI_CCR",'h05002503);
  qspi_write_register("QSPI_AR",flash_base_addr);
  #2ms;
  qspi_read_register_checked("QSPI_SR",sr);
  qspi_check_condition(sr[21:16]==32,"RX FIFO full at 32 words");
  qspi_check_condition(sr[6],"RX full stalls active transfer");
  for(int i=0;i<64;i++) begin
    begin
      bit ready=0;
      for(int n=0;n<5000;n++) begin
        qspi_read_register_checked("QSPI_SR",sr);
        if(sr[21:16]!=0) begin ready=1;
          break;
        end
      end
      if(!ready) `uvm_fatal("TESTPLAN_TIMEOUT","RX FIFO did not refill")
    end
    qspi_read_register_checked("QSPI_DR",data);
    qspi_data_integrity_check(data, image[i],$sformatf("RX drain address=%08h ",flash_base_addr+4*i));
    read_bytes+=4;
  end
  qspi_wait_transfer_complete();
  qspi_read_register_checked("QSPI_SR",sr);
  qspi_check_condition(sr[21:16]==0,"RX FIFO empty after drain");
  qspi_report_scenario_pass("TX full/overflow, RX full/backpressure/empty and abort flush");
endtask : body

// Report the selected stimulus so failures can be reproduced from the run log.
function void qspi_fifo_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s overflow_data=%0d", get_type_name(), overflow_data), UVM_LOW)
endfunction : post_randomize

`endif
