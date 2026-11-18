`ifndef QSPI_POLLING_SEQ_SVH
`define QSPI_POLLING_SEQ_SVH

// QSPI OR match one matching bit; non-match polling timeout; zero mask AND matches.
class qspi_polling_seq_c extends qspi_feature_base_seq_c;
  `uvm_object_utils(qspi_polling_seq_c)
  rand int unsigned timeout_cycles;

  constraint polling_timing_c { timeout_cycles inside {[32:128]};
  }
  // Select this scenario's legal fixed inputs for the dedicated Verilator list.
  virtual function void qspi_set_directed_stimulus();
    super.qspi_set_directed_stimulus();
    timeout_cycles = 64;
  endfunction

  extern function new(string name = "qspi_polling_seq_c");
  extern virtual task body();
  extern function void post_randomize();
endclass : qspi_polling_seq_c

// Construct this object and initialize its inherited UVM state.
function qspi_polling_seq_c::new(string name = "qspi_polling_seq_c");
  super.new(name, "polling");
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Run this scenario: OR match one matching bit; non-match polling timeout; zero mask AND matches. Check failures are reported through UVM.
task qspi_polling_seq_c::body();
  bit [31:0] data;
  qspi_initialize_flash_and_controller();
  for(int n=1;n<=4;n++) begin
    qspi_start_automatic_polling(0,'hffffffff,n);
    qspi_wait_status_bits('h50,'h10);
    qspi_read_register_checked("QSPI_DR",data);
    qspi_check_condition(data==0,$sformatf("poll length=%0d status data",n));
    if (qspi_coverage != null) qspi_coverage.polling_cg.sample(n,failures==0);
    qspi_report_scenario_pass($sformatf("AND match length=%0d",n));
  end
  qspi_start_automatic_polling(2,3,1,1);
  qspi_wait_status_bits('h50,'h10);
    if (qspi_coverage != null) qspi_coverage.polling_cg.sample(5,failures==0);
  qspi_report_scenario_pass("OR match one matching bit");
  qspi_start_automatic_polling(1,1,1,0,1,1,timeout_cycles);
  qspi_wait_status_bits('h60,'h20);
    if (qspi_coverage != null) qspi_coverage.polling_cg.sample(6,failures==0);
  qspi_report_scenario_pass("non-match polling timeout");
  qspi_start_automatic_polling(0,0);
  qspi_wait_status_bits('h50,'h10);
    if (qspi_coverage != null) qspi_coverage.polling_cg.sample(7,failures==0);
  qspi_report_scenario_pass("zero mask AND matches");
  qspi_start_automatic_polling(0,0,1,1,1,1,timeout_cycles);
  qspi_wait_status_bits('h60,'h20);
    if (qspi_coverage != null) qspi_coverage.polling_cg.sample(8,failures==0);
  qspi_report_scenario_pass("zero mask OR times out");
  for(int i=0;i<4;i++) begin
    bit [31:0] lengths[4]='{4,15,16,'hffffffff};
    qspi_configure_controller();
    qspi_write_register("QSPI_DLR",lengths[i]);
    qspi_write_register("QSPI_CCR",'h09000105);
    qspi_wait_status_bits('h41,1);
    if (qspi_coverage != null) qspi_coverage.polling_cg.sample(9+i,failures==0);
    qspi_report_scenario_pass($sformatf("illegal polling DLR=%08h rejected",lengths[i]));
  end

  // Program data, poll for ready, then verify every programmed byte.
  // This does not claim WIP=1 was observed: programming may finish before polling starts.
  qspi_configure_controller();
  qspi_generate_expected_image(16);
  qspi_write_register("QSPI_CCR",'h106);
  qspi_wait_transfer_complete();
  qspi_indirect_write(flash_base_addr,16,'h01002502,0,0,image);
  qspi_start_automatic_polling(0,1);
  qspi_wait_status_bits('h50,'h10);
  qspi_read_register_checked("QSPI_DR",data);
  qspi_check_condition(!data[0],"automatic WIP polling returns ready");
    if (qspi_coverage != null) qspi_coverage.polling_cg.sample(13,failures==0);
  qspi_configure_controller();
  qspi_read_flash_and_check_data(16,qspi_build_read_command(1),"polling Page Program readback");
  qspi_report_scenario_pass("automatic polling returns ready and programmed data matches");
endtask : body

// Report the selected stimulus so failures can be reproduced from the run log.
function void qspi_polling_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s timeout_cycles=%0d", get_type_name(), timeout_cycles), UVM_LOW)
endfunction : post_randomize

`endif
