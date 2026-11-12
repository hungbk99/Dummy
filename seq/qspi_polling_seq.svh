`ifndef QSPI_POLLING_SEQ_SVH
`define QSPI_POLLING_SEQ_SVH

class qspi_polling_seq_c extends qspi_feature_base_seq_c;
  `uvm_object_utils(qspi_polling_seq_c)
  rand int unsigned timeout_cycles;

  constraint polling_timing_c { timeout_cycles inside {[32:128]};
  }
  extern function new(string name = "qspi_polling_seq_c");
  extern virtual task body();
  extern function void post_randomize();
endclass : qspi_polling_seq_c

function qspi_polling_seq_c::new(string name = "qspi_polling_seq_c");
  super.new(name, "polling");
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_polling_seq_c::body();
  bit [31:0] data;
  initialize();
  for(int n=1;n<=4;n++) begin
    poll_start(0,'hffffffff,n);
    wait_status('h50,'h10);
    read_reg("QSPI_DR",data);
    verify(data==0,$sformatf("poll length=%0d status data",n));
    m_qspi_env.m_coverage.polling_cg.sample(n,failures==0);
    bin_pass($sformatf("AND match length=%0d",n));
  end
  poll_start(2,3,1,1);
  wait_status('h50,'h10);
    m_qspi_env.m_coverage.polling_cg.sample(5,failures==0);
  bin_pass("OR match one matching bit");
  poll_start(1,1,1,0,1,1,timeout_cycles);
  wait_status('h60,'h20);
    m_qspi_env.m_coverage.polling_cg.sample(6,failures==0);
  bin_pass("non-match polling timeout");
  poll_start(0,0);
  wait_status('h50,'h10);
    m_qspi_env.m_coverage.polling_cg.sample(7,failures==0);
  bin_pass("zero mask AND matches");
  poll_start(0,0,1,1,1,1,timeout_cycles);
  wait_status('h60,'h20);
    m_qspi_env.m_coverage.polling_cg.sample(8,failures==0);
  bin_pass("zero mask OR times out");
  for(int i=0;i<4;i++) begin
    bit [31:0] lengths[4]='{4,15,16,'hffffffff};
    configure();
    qspi_write_reg("QSPI_DLR",lengths[i]);
    qspi_write_reg("QSPI_CCR",'h09000105);
    wait_status('h41,1);
    m_qspi_env.m_coverage.polling_cg.sample(9+i,failures==0);
    bin_pass($sformatf("illegal polling DLR=%08h rejected",lengths[i]));
  end

  // Real WIP transitions: launch programming, then autonomously poll until ready.
  configure();
  make_image(16);
  qspi_write_reg("QSPI_CCR",'h106);
  qspi_wait_complete();
  qspi_indirect_write(flash_base_addr,16,'h01002502,0,0,image);
  poll_start(0,1);
  wait_status('h50,'h10);
  read_reg("QSPI_DR",data);
  verify(!data[0],"automatic WIP polling returns ready");
    m_qspi_env.m_coverage.polling_cg.sample(13,failures==0);
  bin_pass("autonomous polling waits for real flash programming");
endtask : body

function void qspi_polling_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s timeout_cycles=%0d", get_type_name(), timeout_cycles), UVM_LOW)
endfunction : post_randomize

`endif
