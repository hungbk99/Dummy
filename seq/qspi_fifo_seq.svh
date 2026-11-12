`ifndef QSPI_FIFO_SEQ_SVH
`define QSPI_FIFO_SEQ_SVH

class qspi_fifo_seq_c extends qspi_feature_base_seq_c;
  `uvm_object_utils(qspi_fifo_seq_c)
  rand int unsigned overflow_data;

  constraint overflow_data_c { overflow_data != 0;
  }
  extern function new(string name = "qspi_fifo_seq_c");
  extern virtual task body();
  extern function void post_randomize();
endclass : qspi_fifo_seq_c

function qspi_fifo_seq_c::new(string name = "qspi_fifo_seq_c");
  super.new(name, "fifo");
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_fifo_seq_c::body();
  bit [31:0] data,sr;
  initialize();
  prepare_image(256);

  // Fill TX while disabled, overflow the next write, then abort/flush.
  configure();
  qspi_write_reg("QSPI_CR",'h02000000);
  qspi_write_reg("QSPI_CCR",'h01002502);
  qspi_write_reg("QSPI_DLR",255);
  for(int i=0;i<32;i++) qspi_write_reg("QSPI_DR",image[i]);
  read_reg("QSPI_SR",sr);
  verify(sr[13:8]==32,"TX FIFO full at 32 words");
  qspi_write_reg("QSPI_DR",overflow_data);
  read_reg("QSPI_DMASR",data);
  verify(data[2],"TX overflow flag");
  abort_controller();
  configure();

  // Let RX fill and stall, then drain all data and verify recovery.
  qspi_write_reg("QSPI_DLR",255);
  qspi_write_reg("QSPI_CCR",'h05002503);
  qspi_write_reg("QSPI_AR",flash_base_addr);
  #2ms;
  read_reg("QSPI_SR",sr);
  verify(sr[21:16]==32,"RX FIFO full at 32 words");
  verify(sr[6],"RX full stalls active transfer");
  for(int i=0;i<64;i++) begin
    begin
      bit ready=0;
      for(int n=0;n<5000;n++) begin
        read_reg("QSPI_SR",sr);
        if(sr[21:16]!=0) begin ready=1;
          break;
        end
      end
      if(!ready) `uvm_fatal("TESTPLAN_TIMEOUT","RX FIFO did not refill")
    end
    read_reg("QSPI_DR",data);
    verify(data===image[i],$sformatf("RX drain word %0d",i));
  end
  qspi_wait_complete();
  read_reg("QSPI_SR",sr);
  verify(sr[21:16]==0,"RX FIFO empty after drain");
  bin_pass("TX full/overflow, RX full/backpressure/empty and abort flush");
endtask : body

function void qspi_fifo_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s overflow_data=%0d", get_type_name(), overflow_data), UVM_LOW)
endfunction : post_randomize

`endif
