`ifndef QSPI_FEATURE_BASE_SEQ_SVH
`define QSPI_FEATURE_BASE_SEQ_SVH

// Common operations and reporting only. Each feature has its own factory class/body.
class qspi_feature_base_seq_c extends qspi_transfer_base_seq_c;
  virtual qspi_test_if vif;
  extern task ahb_access(bit [31:0] address, output bit [31:0] data,
                         output bit error, input bit write_access=0);

  string case_name;
  int checks = 0;
  bit active_ckmode;
  int active_xip_lanes=1;
  bit active_xip_ddr;
  int feature_ids[string] = '{ "registers":0, "clocks":1, "indirect":2,
    "polling":3, "xip":4, "mixed":5, "irq":6, "abort":7,
    "frames":8, "fifo":9, "delays":10, "dma":11, "sioo":12, "timeout":13 };
  int failures = 0;
  int read_bytes = 0;
  bit [31:0] image[];
  rand int unsigned flash_base_addr;
  rand int unsigned data_seed;
  rand int unsigned repeat_count;
  rand int unsigned idle_periods;
  rand int unsigned poll_interval;

  constraint flash_region_c {
    flash_base_addr inside {[32'h0001_0000:32'h0008_0000]};
    flash_base_addr[7:0] == 0;
  }

  constraint common_stimulus_c {
    data_seed inside {[1:32'h7fff_ffff]};
    repeat_count inside {[2:3]};
    idle_periods inside {[0:3]};
    poll_interval inside {[0:3]};
  }
  extern function new(string name = "qspi_feature_base_seq_c", string label = "");
  extern virtual task pre_body();
  extern virtual task post_body();
  extern virtual function void verify(bit condition,string label);
  extern virtual function void bin_pass(string label);
  extern virtual function void make_image(int bytes);
  extern virtual function bit [31:0] read_ccr(int lanes,bit ddr=0,bit quad_io=0);
  extern virtual task read_reg(string reg_name,output bit [31:0] data);
  extern virtual task wait_status(bit [31:0] mask,bit [31:0] expected,int limit=5000);
  extern virtual task abort_controller();
  extern virtual task configure(bit ckmode=0,bit ddr=0);
  extern virtual task initialize();
  extern virtual task prepare_image(int bytes=1024);
  extern virtual task check_read(int bytes,bit [31:0] ccr,string label);
  extern virtual task poll_start(bit [31:0] match,bit [31:0] mask,int length=1,bit pmm=0,bit apms=1,bit timeout_en=0,int timeout_cycles=64,bit irq_enable=0);
  extern virtual task enter_xip(int lanes=1,bit ddr=0);
  extern virtual task xip_check(int bytes,bit sequential=0);
endclass : qspi_feature_base_seq_c

function qspi_feature_base_seq_c::new(string name = "qspi_feature_base_seq_c", string label = "");
  super.new(name);
  case_name = label;
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_feature_base_seq_c::pre_body();
  super.pre_body();
  if (!uvm_config_db#(virtual qspi_test_if)::get(null, "", "qspi_test_vif", vif))
  `uvm_fatal("QSPI_SETUP", "Missing qspi_test_vif")
`ifdef VERILATOR
  // XIP has a directed matrix that does not need an external SMT solver.
  if (case_name == "xip") begin
    flash_base_addr = 32'h0001_0000;
    data_seed = 32'h1357_2468;
    repeat_count = 2;
    idle_periods = 0;
    poll_interval = 0;
    `uvm_info("QSPI_DIRECTED", "Verilator XIP: deterministic legal stimulus; constrained randomization disabled", UVM_LOW)
  end else begin
`endif
  if (!this.randomize())
    `uvm_fatal("QSPI_RANDOMIZE", "Cannot randomize sequence; check constraints and SMT solver setup")
`ifdef VERILATOR
  end
`endif

  // Keep the programmed flash context stable while individual scenarios randomize.
  flash_base_addr.rand_mode(0);
  data_seed.rand_mode(0);
  repeat_count.rand_mode(0);
  idle_periods.rand_mode(0);
  poll_interval.rand_mode(0);
  `uvm_info("TESTPLAN_START", case_name, UVM_LOW)
  `uvm_info("QSPI_RANDOM_CONFIG",
  $sformatf("sequence=%s flash_base=%08h seed=%08h repeats=%0d idle=%0d poll_interval=%0d",
  get_type_name(), flash_base_addr, data_seed, repeat_count, idle_periods, poll_interval), UVM_LOW)
endtask : pre_body

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_feature_base_seq_c::post_body();
  // Conservative feature closure: every check in this sequence must pass.
  if (feature_ids.exists(case_name))
    m_qspi_env.m_coverage.feature_cg.sample(feature_ids[case_name],checks>0 && failures==0 &&
      uvm_report_server::get_server().get_severity_count(UVM_ERROR)==0);
  `uvm_info("TESTPLAN_RESULT",
  $sformatf("case=%s checks=%0d failures=%0d read_bytes=%0d",
  case_name, checks, failures, read_bytes), UVM_LOW)
  super.post_body();
endtask : post_body

function void qspi_feature_base_seq_c::verify(bit condition,string label);
  checks++;
  if(!condition) begin failures++;
    `uvm_error("TESTPLAN_CHECK",$sformatf("%s: %s",case_name,label)) end
endfunction : verify

function void qspi_feature_base_seq_c::bin_pass(string label);
  if (failures==0 && checks>0)
    `uvm_info("TESTPLAN_BIN",$sformatf("%s %s",case_name,label),UVM_LOW)
endfunction : bin_pass

function void qspi_feature_base_seq_c::make_image(int bytes);
  image=new[(bytes+3)/4];
  foreach(image[i]) image[i]=0;
  for(int i=0;i<bytes;i++) image[i/4][(i%4)*8+:8]=8'((i*37)^((i>>8)*'h5b)^data_seed);
endfunction : make_image

function bit [31:0] qspi_feature_base_seq_c::read_ccr(int lanes,bit ddr=0,bit quad_io=0);
  bit [31:0] result;
  result='h00002500;
  case(lanes)
    1: result|=ddr?'h0110000d:'h01000003;
    2: result|=ddr?'h0210003d:'h0210003b;
    4: result|=ddr?'h0320006d:'h0320006b;
  endcase
  if(quad_io) result='h03102deb;
  result[31]=ddr;
  return result;
endfunction : read_ccr

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_feature_base_seq_c::read_reg(string reg_name,output bit [31:0] data);
  bit error;
  bit [31:0] address;
  if (!qspi_get_reg_addr(reg_name,address))
  `uvm_fatal("QSPI_REGISTER", {"Unknown register: ",reg_name})
  reg_read32(address,data,error);
  verify(!error,$sformatf("APB read @%08h without PSLVERR",address));

endtask : read_reg

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_feature_base_seq_c::wait_status(bit [31:0] mask,bit [31:0] expected,int limit=5000);
  bit [31:0] sr;
  for(int n=0;n<limit;n++) begin
    read_reg("QSPI_SR",sr);
    if((sr&mask)==expected) return;
  end
  failures++;
  `uvm_fatal("TESTPLAN_TIMEOUT",$sformatf("%s: SR mask=%08h expected=%08h last=%08h",case_name,mask,expected,sr))
endtask : wait_status

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_feature_base_seq_c::abort_controller();
  bit [31:0] cr,sr;
  read_reg("QSPI_CR",cr);
  qspi_write_reg("QSPI_CR",cr|2);
  for(int n=0;n<5000;n++) begin
    read_reg("QSPI_CR",cr);
    read_reg("QSPI_SR",sr);
    if(!cr[1] && !sr[6]) begin
      verify(sr[1],"abort sets TCF");
      verify(sr[21:16]==0 && sr[13:8]==0,"abort flushes RX/TX FIFO");
      vif.wait_core();
      verify(!vif.dma_tx_req && !vif.dma_rx_req,"abort suppresses DMA requests");
      return;
    end
  end
  `uvm_fatal("TESTPLAN_TIMEOUT","abort did not retire")
endtask : abort_controller

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_feature_base_seq_c::configure(bit ckmode=0,bit ddr=0);
  bit [31:0] cr;
  abort_controller();
  qspi_write_reg("QSPI_CR",0);
  qspi_write_reg("QSPI_CCR",0);
  qspi_write_reg("QSPI_FCR",'h3f);
  qspi_write_reg("QSPI_DMAFCR",'hc);
  qspi_write_reg("QSPI_DMACR",0);
  qspi_write_reg("QSPI_DCR",(20<<16)|int'(ckmode));
  active_ckmode=ckmode;
  qspi_write_reg("QSPI_DLY",idle_periods << 16);
  cr='h02000001;
  qspi_write_reg("QSPI_CR",cr);
endtask : configure

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_feature_base_seq_c::initialize();
  configure();
  qspi_flash_write_config(8'h81, 8'h4b);
  configure();
endtask : initialize

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_feature_base_seq_c::prepare_image(int bytes=1024);
  bit [31:0] page[];
  make_image(bytes);
  for(int offset=0;offset<bytes;offset+=256) begin
    int count;
    count=((bytes-offset)>256)?256:(bytes-offset);
    page=new[(count+3)/4];
    foreach(page[i]) page[i]=image[offset/4+i];
    qspi_wait_idle();
    qspi_write_reg("QSPI_CCR",'h00000106);
    qspi_wait_complete();
    qspi_indirect_write(flash_base_addr+offset,count,'h01002502,0,0,page);
    qspi_flash_wait_ready();
  end
endtask : prepare_image

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_feature_base_seq_c::check_read(int bytes,bit [31:0] ccr,string label);
  bit [31:0] data[];
  bit [31:0] mask;
  int start_failures=failures;
  int start_errors=uvm_report_server::get_server().get_severity_count(UVM_ERROR);
  data=new[(bytes+3)/4];
  foreach(data[i]) data[i]='hdeadbeef;
  qspi_indirect_read(flash_base_addr,bytes,ccr,0,0,data);
  for(int i=0;i<bytes;i++) begin
    verify(data[i/4][(i%4)*8+:8]===image[i/4][(i%4)*8+:8],$sformatf("%s byte[%0d] expected=%02h actual=%02h",label,i,image[i/4][(i%4)*8+:8],data[i/4][(i%4)*8+:8]));
    read_bytes++;
  end
  if(bytes%4) begin
    mask='1 << ((bytes%4)*8);
    verify((data[$size(data)-1]&mask)==0,{label," partial word is zero padded"});
  end
  m_qspi_env.m_coverage.read_cg.sample(
    (ccr[25:24]==3)?4:((ccr[25:24]==2)?2:1),bytes,ccr[31],active_ckmode,0,
    failures==start_failures && uvm_report_server::get_server().get_severity_count(UVM_ERROR)==start_errors);
  bin_pass(label);
endtask : check_read

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_feature_base_seq_c::poll_start(bit [31:0] match,bit [31:0] mask,int length=1,bit pmm=0,bit apms=1,bit timeout_en=0,int timeout_cycles=64,bit irq_enable=0);
  bit [31:0] cr;
  configure();
  qspi_write_reg("QSPI_PSMKR",mask);
  qspi_write_reg("QSPI_PSMAR",match);
  qspi_write_reg("QSPI_PIR",poll_interval);
  qspi_write_reg("QSPI_PTR",timeout_cycles);
  qspi_write_reg("QSPI_DLR",length-1);
  cr='h02000001 | (int'(pmm)<<23) | (int'(apms)<<22) | (int'(timeout_en)<<2);
  if(irq_enable) cr|='h00300000;
  qspi_write_reg("QSPI_CR",cr);
  qspi_write_reg("QSPI_CCR",'h09000105);
endtask : poll_start

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_feature_base_seq_c::enter_xip(int lanes=1,bit ddr=0);
  bit [31:0] ccr;
  configure();
  active_xip_lanes=lanes;
  active_xip_ddr=ddr;
  ccr=read_ccr(lanes,ddr);
  ccr[27:26]=3;
  qspi_write_reg("QSPI_CCR",ccr);
  vif.wait_core(8);
endtask : enter_xip

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_feature_base_seq_c::ahb_access(bit [31:0] address,
    output bit [31:0] data, output bit error, input bit write_access=0);
  qspi_ahb_access_seq_c access_seq;
  access_seq = qspi_ahb_access_seq_c::type_id::create("access_seq");
  access_seq.address = address;
  access_seq.write_access = write_access;
  access_seq.start(m_qspi_env.m_ahb_agent.sequencer);
  data = access_seq.result.read_data[0];
  error = access_seq.result.responses[0] != AHB_OKAY;
endtask : ahb_access

task qspi_feature_base_seq_c::xip_check(int bytes,bit sequential=0);
  bit [31:0] data;
  bit error;
  int start_failures=failures;
  int start_errors=uvm_report_server::get_server().get_severity_count(UVM_ERROR);
  for(int offset=0;offset<bytes;) begin
    qspi_ahb_access_seq_c access_seq;
    int beats;
    beats = sequential ? (bytes-offset+3)/4 : 1;
    if (beats > (1024-int'((flash_base_addr+offset)&32'h3ff))/4)
      beats = (1024-int'((flash_base_addr+offset)&32'h3ff))/4;
    access_seq = qspi_ahb_access_seq_c::type_id::create("xip_access_seq");
    access_seq.address = flash_base_addr+offset;
    access_seq.beats = beats;
    access_seq.incrementing = sequential;
    access_seq.start(m_qspi_env.m_ahb_agent.sequencer);
    for(int beat=0;beat<beats;beat++) begin
      data = access_seq.result.read_data[beat];
      error = access_seq.result.responses[beat] != AHB_OKAY;
      verify(!error,$sformatf("XIP HRESP OK address=%08h",flash_base_addr+offset));
      for(int b=0;b<4 && offset+b<bytes;b++) begin
        verify(data[b*8+:8]===image[(offset+b)/4][((offset+b)%4)*8+:8],$sformatf("XIP byte %0d",offset+b));
        read_bytes++;
      end
      offset+=4;
    end
  end
  qspi_wait_idle();
  m_qspi_env.m_coverage.read_cg.sample(active_xip_lanes,bytes,active_xip_ddr,active_ckmode,1,
    failures==start_failures && uvm_report_server::get_server().get_severity_count(UVM_ERROR)==start_errors);
endtask : xip_check

`endif
