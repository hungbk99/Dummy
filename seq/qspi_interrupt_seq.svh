`ifndef QSPI_INTERRUPT_SEQ_SVH
`define QSPI_INTERRUPT_SEQ_SVH

// QSPI all eight flag/enable IRQ sources and independent clears.
class qspi_interrupt_seq_c extends qspi_feature_base_seq_c;
  `uvm_object_utils(qspi_interrupt_seq_c)
  rand int unsigned irq_observe_cycles;

  constraint irq_level_c { irq_observe_cycles inside {[4:12]};
  }
  // Select this scenario's legal fixed inputs for the dedicated Verilator list.
  virtual function void qspi_set_directed_stimulus();
    super.qspi_set_directed_stimulus();
    irq_observe_cycles = 8;
  endfunction

  extern function new(string name = "qspi_interrupt_seq_c");
  extern virtual task body();
  extern function void post_randomize();
  extern virtual task qspi_check_interrupt_level(bit expected,string label,int source,int action);
endclass : qspi_interrupt_seq_c

// Construct this object and initialize its inherited UVM state.
function qspi_interrupt_seq_c::new(string name = "qspi_interrupt_seq_c");
  super.new(name, "irq");
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Run this scenario: all eight flag/enable IRQ sources and independent clears. Check failures are reported through UVM.
task qspi_interrupt_seq_c::body();
  bit [31:0] data;
  qspi_initialize_flash_and_controller();
  qspi_program_expected_image(16);
  qspi_configure_controller();
  qspi_write_register("QSPI_CR",'h02040001);
  qspi_check_interrupt_level(1,"TXFTF IRQ level",2,0);
  qspi_write_register("QSPI_FCR",4);
  qspi_check_interrupt_level(1,"TXFTF clear reasserts while threshold holds",2,2);
  qspi_write_register("QSPI_CCR",'h04000100);
  qspi_write_register("QSPI_FCR",4);
  qspi_check_interrupt_level(0,"TXFTF condition removed and flag cleared",2,1);
  qspi_configure_controller();
  qspi_write_register("QSPI_CR",'h02020001);
  qspi_write_register("QSPI_CCR",'h106);
  qspi_wait_status_bits(2,2);
  qspi_check_interrupt_level(1,"TCF IRQ",1,0);
  qspi_write_register("QSPI_FCR",2);
  qspi_check_interrupt_level(0,"TCF independently cleared",1,1);
  qspi_configure_controller();
  qspi_write_register("QSPI_CR",'h01010001);
  qspi_write_register("QSPI_CCR",'h106);
  qspi_wait_status_bits('h41,1);
  qspi_check_interrupt_level(1,"TEF IRQ for illegal prescaler",0,0);
  qspi_write_register("QSPI_FCR",1);
  qspi_check_interrupt_level(0,"TEF clear",0,1);
  qspi_configure_controller();
  qspi_write_register("QSPI_CR",'h02080001);
  qspi_write_register("QSPI_DLR",3);
  qspi_write_register("QSPI_CCR",'h05002503);
  qspi_write_register("QSPI_AR",flash_base_addr);
  qspi_wait_status_bits(8,8);
  qspi_check_interrupt_level(1,"RXFTF IRQ",3,0);
  qspi_write_register("QSPI_FCR",8);
  qspi_check_interrupt_level(1,"RXFTF reasserts while data present",3,2);
  qspi_read_register_checked("QSPI_DR",data);
  qspi_data_integrity_check(data, image[0],$sformatf("RXFTF payload address=%08h ",flash_base_addr));
  read_bytes+=4;
  qspi_wait_status_bits('h40,0);
  qspi_write_register("QSPI_FCR",8);
  qspi_check_interrupt_level(0,"RXFTF clears after FIFO drained",3,1);
  qspi_start_automatic_polling(0,1,1,0,1,0,64,1);
  qspi_wait_status_bits('h50,'h10);
  qspi_check_interrupt_level(1,"SMF IRQ",4,0);
  qspi_write_register("QSPI_FCR",'h10);
  qspi_check_interrupt_level(0,"SMF clear",4,1);
  qspi_start_automatic_polling(1,1,1,0,1,1,64,1);
  qspi_wait_status_bits('h60,'h20);
  qspi_check_interrupt_level(1,"STOF IRQ",5,0);
  qspi_write_register("QSPI_FCR",'h20);
  qspi_check_interrupt_level(0,"STOF clear",5,1);
  qspi_configure_controller();
  qspi_write_register("QSPI_CR",'h02000000);
  qspi_write_register("QSPI_DMACR",4);
  for(int i=0;i<33;i++) qspi_write_register("QSPI_DR",i);
  qspi_read_register_checked("QSPI_DMASR",data);
  qspi_check_condition(data[2],"TXOVRF status bit");
  qspi_check_interrupt_level(1,"TXOVRF IRQ",6,0);
  qspi_write_register("QSPI_DMAFCR",4);
  qspi_check_interrupt_level(0,"TXOVRF clear",6,1);
  qspi_configure_controller();
  qspi_write_register("QSPI_CR",'h02000000);
  qspi_write_register("QSPI_CCR",'h04000100);
  qspi_write_register("QSPI_DMACR",8);
  qspi_read_register_checked("QSPI_DR",data);
  qspi_read_register_checked("QSPI_DMASR",data);
  qspi_check_condition(data[3],"RXUDRF status bit");
  qspi_check_interrupt_level(1,"RXUDRF IRQ",7,0);
  qspi_write_register("QSPI_DMAFCR",8);
  qspi_check_interrupt_level(0,"RXUDRF clear",7,1);
  qspi_report_scenario_pass("all eight flag/enable IRQ sources and independent clears");
endtask : body

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Check interrupt level.
task qspi_interrupt_seq_c::qspi_check_interrupt_level(bit expected,string label,int source,int action);
  int start_failures=failures;
  irq_vif.wait_core(4);
  repeat(irq_observe_cycles) begin
    qspi_check_condition(irq_vif.irq===expected,label);
    irq_vif.wait_core(1);
  end
  if (qspi_coverage != null) qspi_coverage.irq_cg.sample(source,expected,action,failures==start_failures);
endtask : qspi_check_interrupt_level

// Report the selected stimulus so failures can be reproduced from the run log.
function void qspi_interrupt_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s irq_observe_cycles=%0d", get_type_name(), irq_observe_cycles), UVM_LOW)
endfunction : post_randomize

`endif
