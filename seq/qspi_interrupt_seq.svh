`ifndef QSPI_INTERRUPT_SEQ_SVH
`define QSPI_INTERRUPT_SEQ_SVH

class qspi_interrupt_seq_c extends qspi_feature_base_seq_c;
  `uvm_object_utils(qspi_interrupt_seq_c)
  rand int unsigned irq_observe_cycles;

  constraint irq_level_c { irq_observe_cycles inside {[4:12]};
  }
  extern function new(string name = "qspi_interrupt_seq_c");
  extern virtual task body();
  extern function void post_randomize();
  extern virtual task check_irq(bit expected,string label,int source,int action);
endclass : qspi_interrupt_seq_c

function qspi_interrupt_seq_c::new(string name = "qspi_interrupt_seq_c");
  super.new(name, "irq");
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_interrupt_seq_c::body();
  bit [31:0] data;
  initialize();
  prepare_image(16);
  configure();
  qspi_write_reg("QSPI_CR",'h02040001);
  check_irq(1,"TXFTF IRQ level",2,0);
  qspi_write_reg("QSPI_FCR",4);
  check_irq(1,"TXFTF clear reasserts while threshold holds",2,2);
  qspi_write_reg("QSPI_CCR",'h04000100);
  qspi_write_reg("QSPI_FCR",4);
  check_irq(0,"TXFTF condition removed and flag cleared",2,1);
  configure();
  qspi_write_reg("QSPI_CR",'h02020001);
  qspi_write_reg("QSPI_CCR",'h106);
  wait_status(2,2);
  check_irq(1,"TCF IRQ",1,0);
  qspi_write_reg("QSPI_FCR",2);
  check_irq(0,"TCF independently cleared",1,1);
  configure();
  qspi_write_reg("QSPI_CR",'h01010001);
  qspi_write_reg("QSPI_CCR",'h106);
  wait_status('h41,1);
  check_irq(1,"TEF IRQ for illegal prescaler",0,0);
  qspi_write_reg("QSPI_FCR",1);
  check_irq(0,"TEF clear",0,1);
  configure();
  qspi_write_reg("QSPI_CR",'h02080001);
  qspi_write_reg("QSPI_DLR",3);
  qspi_write_reg("QSPI_CCR",'h05002503);
  qspi_write_reg("QSPI_AR",flash_base_addr);
  wait_status(8,8);
  check_irq(1,"RXFTF IRQ",3,0);
  qspi_write_reg("QSPI_FCR",8);
  check_irq(1,"RXFTF reasserts while data present",3,2);
  read_reg("QSPI_DR",data);
  wait_status('h40,0);
  qspi_write_reg("QSPI_FCR",8);
  check_irq(0,"RXFTF clears after FIFO drained",3,1);
  poll_start(0,1,1,0,1,0,64,1);
  wait_status('h50,'h10);
  check_irq(1,"SMF IRQ",4,0);
  qspi_write_reg("QSPI_FCR",'h10);
  check_irq(0,"SMF clear",4,1);
  poll_start(1,1,1,0,1,1,64,1);
  wait_status('h60,'h20);
  check_irq(1,"STOF IRQ",5,0);
  qspi_write_reg("QSPI_FCR",'h20);
  check_irq(0,"STOF clear",5,1);
  configure();
  qspi_write_reg("QSPI_CR",'h02000000);
  qspi_write_reg("QSPI_DMACR",4);
  for(int i=0;i<33;i++) qspi_write_reg("QSPI_DR",i);
  read_reg("QSPI_DMASR",data);
  verify(data[2],"TXOVRF status bit");
  check_irq(1,"TXOVRF IRQ",6,0);
  qspi_write_reg("QSPI_DMAFCR",4);
  check_irq(0,"TXOVRF clear",6,1);
  configure();
  qspi_write_reg("QSPI_CR",'h02000000);
  qspi_write_reg("QSPI_CCR",'h04000100);
  qspi_write_reg("QSPI_DMACR",8);
  read_reg("QSPI_DR",data);
  read_reg("QSPI_DMASR",data);
  verify(data[3],"RXUDRF status bit");
  check_irq(1,"RXUDRF IRQ",7,0);
  qspi_write_reg("QSPI_DMAFCR",8);
  check_irq(0,"RXUDRF clear",7,1);
  bin_pass("all eight flag/enable IRQ sources and independent clears");
endtask : body

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_interrupt_seq_c::check_irq(bit expected,string label,int source,int action);
  int start_failures=failures;
  irq_vif.wait_core(4);
  repeat(irq_observe_cycles) begin
    verify(irq_vif.irq===expected,label);
    irq_vif.wait_core(1);
  end
  m_qspi_env.m_coverage.irq_cg.sample(source,expected,action,failures==start_failures);
endtask : check_irq

function void qspi_interrupt_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s irq_observe_cycles=%0d", get_type_name(), irq_observe_cycles), UVM_LOW)
endfunction : post_randomize

`endif
