`ifndef QSPI_FEATURE_BASE_SEQ_SVH
`define QSPI_FEATURE_BASE_SEQ_SVH

// Common operations and reporting only. Each feature has its own factory class/body.
// QSPI feature base seq.
class qspi_feature_base_seq_c extends qspi_transfer_base_seq_c;
  virtual qspi_monitor_if monitor_vif;
  virtual qspi_irq_if irq_vif;
  virtual qspi_dma_if dma_vif;
  // address is a flash offset; this helper adds the system AHB base.
  extern task qspi_access_memory_mapped_word(bit [31:0] address, output bit [31:0] data,
                         output bit error, input bit write_access=0);

  // Explicit opt-in for the solver-free Verilator regression, never a fallback.
  bit directed_stimulus;
  // Apply legal, repeatable settings; derived scenarios supply their own fields.
  virtual function void qspi_set_directed_stimulus();
    flash_base_addr = 32'h0001_0000;
    data_seed = 32'h1357_2468;
    repeat_count = 2;
    idle_periods = 0;
    poll_interval = 0;
  endfunction

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
  // Written only when qspi_program_expected_image() starts a new preload, never from read data.
  protected bit [7:0] preload_expected[];
  protected bit [31:0] preload_flash_base;
  protected bit [31:0] preload_data_seed;
  protected bit preload_valid=0;
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
  extern virtual function void qspi_check_condition(bit condition, string label);
  extern virtual function void qspi_data_integrity_check(
      logic [31:0] actual, logic [31:0] expected, string context_label);
  extern virtual function void qspi_report_scenario_pass(string label);
  extern virtual function void qspi_generate_expected_image(int bytes);
  extern virtual function bit [31:0] qspi_build_read_command(int lanes,bit ddr=0,bit quad_io=0);
  extern virtual task qspi_read_register_checked(string reg_name,output bit [31:0] data);
  extern virtual task qspi_wait_status_bits(bit [31:0] mask,bit [31:0] expected,int limit=5000);
  extern virtual task qspi_abort_and_flush();
  extern virtual task qspi_configure_controller(bit ckmode=0,bit ddr=0);
  extern virtual task qspi_initialize_flash_and_controller();
  extern virtual task qspi_program_expected_image(int bytes=1024);
  extern virtual task qspi_read_flash_and_check_data(int bytes,bit [31:0] ccr,string label);
  extern virtual task qspi_start_automatic_polling(bit [31:0] match,bit [31:0] mask,int length=1,bit pmm=0,bit apms=1,bit timeout_en=0,int timeout_cycles=64,bit irq_enable=0);
  extern virtual task qspi_enable_memory_mapped_read(int lanes=1,bit ddr=0);
  extern virtual task qspi_read_xip_and_check_data(int bytes,bit sequential=0,bit [31:0] system_address=0);
endclass : qspi_feature_base_seq_c

// Construct this object and initialize its inherited UVM state.
function qspi_feature_base_seq_c::new(string name = "qspi_feature_base_seq_c", string label = "");
  super.new(name);
  case_name = label;
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Resolve the configured access path and prepare the sequence before stimulus starts.
task qspi_feature_base_seq_c::pre_body();
  super.pre_body();
  directed_stimulus = $test$plusargs("QSPI_DIRECTED");
`ifndef VERILATOR
  if (directed_stimulus)
    `uvm_fatal("QSPI_DIRECTED", "The directed list is dedicated to Verilator")
`endif
  if (!uvm_config_db#(virtual qspi_monitor_if)::get(null, "", "qspi_monitor_vif", monitor_vif))
  `uvm_fatal("QSPI_SETUP", "Missing QSPI serial monitor interface")
  if (!uvm_config_db#(virtual qspi_irq_if)::get(null, "", "qspi_irq_vif", irq_vif))
    `uvm_fatal("QSPI_SETUP", "Missing IRQ monitor interface")
  if (!uvm_config_db#(virtual qspi_dma_if)::get(null, "", "qspi_dma_vif", dma_vif))
    `uvm_fatal("QSPI_SETUP", "Missing DMA interface")
`ifdef VERILATOR
  // XIP has a directed matrix that does not need an external SMT solver.
  if (directed_stimulus) begin
    qspi_set_directed_stimulus();
    `uvm_info("QSPI_DIRECTED", "Explicit directed settings; no constraint solver used", UVM_LOW)
  end else if (case_name == "xip") begin
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
// Publish the accumulated scenario results after stimulus completes.
task qspi_feature_base_seq_c::post_body();
  // Conservative feature closure: every check in this sequence must pass.
  if (feature_ids.exists(case_name))
    if (qspi_coverage != null) qspi_coverage.feature_cg.sample(feature_ids[case_name],checks>0 && failures==0 &&
      uvm_report_server::get_server().get_severity_count(UVM_ERROR)==0);
  `uvm_info("TESTPLAN_RESULT",
  $sformatf("case=%s checks=%0d failures=%0d read_bytes=%0d",
  case_name, checks, failures, read_bytes), UVM_LOW)
  super.post_body();
endtask : post_body

// Count this expectation and report an error when the condition is false.
function void qspi_feature_base_seq_c::qspi_check_condition(bit condition, string label);
  checks++;
  if (!condition) begin
    failures++;
    `uvm_error("TESTPLAN_CHECK", $sformatf("%s: %s", case_name, label))
  end
endfunction : qspi_check_condition

// Compare actual and intended payloads using case equality; report the mismatch context.
function void qspi_feature_base_seq_c::qspi_data_integrity_check(
    logic [31:0] actual, logic [31:0] expected, string context_label);
  qspi_check_condition(actual === expected,
      $sformatf("%s expected=%08h actual=%08h", context_label, expected, actual));
endfunction : qspi_data_integrity_check

// Report scenario pass.
function void qspi_feature_base_seq_c::qspi_report_scenario_pass(string label);
  if (failures==0 && checks>0)
    `uvm_info("TESTPLAN_BIN",$sformatf("%s %s",case_name,label),UVM_LOW)
endfunction : qspi_report_scenario_pass

// Generate the deterministic intended payload independently of observed flash data.
function void qspi_feature_base_seq_c::qspi_generate_expected_image(int bytes);
  image=new[(bytes+3)/4];
  foreach(image[i]) image[i]=0;
  for(int i=0;i<bytes;i++) image[i/4][(i%4)*8+:8]=8'((i*37)^((i>>8)*'h5b)^data_seed);
endfunction : qspi_generate_expected_image

// Build read command.
function bit [31:0] qspi_feature_base_seq_c::qspi_build_read_command(int lanes,bit ddr=0,bit quad_io=0);
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
endfunction : qspi_build_read_command

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Read register checked.
task qspi_feature_base_seq_c::qspi_read_register_checked(string reg_name,output bit [31:0] data);
  bit error;
  bit [31:0] address;
  if (!qspi_lookup_register_address(reg_name,address))
  `uvm_fatal("QSPI_REGISTER", {"Unknown register: ",reg_name})
  qspi_bus_read32(address,data,error);
  qspi_check_condition(!error,$sformatf("APB read @%08h without PSLVERR",address));

endtask : qspi_read_register_checked

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Wait status bits.
task qspi_feature_base_seq_c::qspi_wait_status_bits(bit [31:0] mask,bit [31:0] expected,int limit=5000);
  bit [31:0] sr;
  for(int n=0;n<limit;n++) begin
    qspi_read_register_checked("QSPI_SR",sr);
    if((sr&mask)==expected) return;
  end
  failures++;
  `uvm_fatal("TESTPLAN_TIMEOUT",$sformatf("%s: SR mask=%08h expected=%08h last=%08h",case_name,mask,expected,sr))
endtask : qspi_wait_status_bits

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Abort and flush.
task qspi_feature_base_seq_c::qspi_abort_and_flush();
  bit [31:0] cr,sr;
  qspi_read_register_checked("QSPI_CR",cr);
  qspi_write_register("QSPI_CR",cr|2);
  for(int n=0;n<5000;n++) begin
    qspi_read_register_checked("QSPI_CR",cr);
    qspi_read_register_checked("QSPI_SR",sr);
    if(!cr[1] && !sr[6]) begin
      qspi_check_condition(sr[1],"abort sets TCF");
      qspi_check_condition(sr[21:16]==0 && sr[13:8]==0,"abort flushes RX/TX FIFO");
      irq_vif.wait_core();
      qspi_check_condition(!dma_vif.tx_req && !dma_vif.rx_req,"abort suppresses DMA requests");
      return;
    end
  end
  `uvm_fatal("TESTPLAN_TIMEOUT","abort did not retire")
endtask : qspi_abort_and_flush

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Configure controller.
task qspi_feature_base_seq_c::qspi_configure_controller(bit ckmode=0,bit ddr=0);
  bit [31:0] cr;
  bit [31:0] dcr;
  bit [31:0] dcr_readback;
  qspi_abort_and_flush();
  qspi_write_register("QSPI_CR",0);
  qspi_write_register("QSPI_CCR",0);
  qspi_write_register("QSPI_FCR",'h3f);
  qspi_write_register("QSPI_DMAFCR",'hc);
  qspi_write_register("QSPI_DMACR",0);
  // Configure the 16 MiB flash range while the controller is disabled.
  dcr='0;
  dcr[20:16]=`QSPI_AHB_FSIZE;
  dcr[0]=ckmode;
  qspi_write_register("QSPI_DCR",dcr);
  qspi_read_register_checked("QSPI_DCR",dcr_readback);
  qspi_check_condition((dcr_readback & 32'h001f_0001) === dcr,
    $sformatf("DCR configuration expected=%08h actual=%08h FSIZE expected=%0d actual=%0d",
      dcr,dcr_readback,`QSPI_AHB_FSIZE,dcr_readback[20:16]));
  active_ckmode=ckmode;
  qspi_write_register("QSPI_DLY",idle_periods << 16);
  cr='h02000001;
  qspi_write_register("QSPI_CR",cr);
endtask : qspi_configure_controller

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Initialize flash and controller.
task qspi_feature_base_seq_c::qspi_initialize_flash_and_controller();
  qspi_configure_controller();
  qspi_write_flash_configuration(8'h81, 8'h4b);
  qspi_configure_controller();
endtask : qspi_initialize_flash_and_controller

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Save the intended bytes, program page-safe chunks, and check flash readback.
task qspi_feature_base_seq_c::qspi_program_expected_image(int bytes=1024);
  bit [31:0] page[];
  if (bytes<=0 || flash_base_addr[1:0]!=0 ||
      ({1'b0,flash_base_addr}+bytes)>`QSPI_AHB_WINDOW_BYTES)
    `uvm_fatal("QSPI_PRELOAD_RANGE", "Preload must be word aligned and inside the flash window")
  qspi_generate_expected_image(bytes);
  preload_expected=new[bytes];
  for(int i=0;i<bytes;i++) preload_expected[i]=image[i/4][(i%4)*8+:8];
  preload_flash_base=flash_base_addr;
  preload_data_seed=data_seed;
  preload_valid=1;
  for(int offset=0;offset<bytes;) begin
    int count;
    // Never wrap a Page Program across the flash's 256-byte page.
    count = `QSPI_FLASH_PAGE_BYTES - ((flash_base_addr + offset) % `QSPI_FLASH_PAGE_BYTES);
    if (count>bytes-offset) count=bytes-offset;
    page=new[(count+3)/4];
    foreach(page[i]) page[i]='0;
    // offset is a BYTE offset into the full preload, not a page/word index.
    for(int i=0;i<count;i++) page[i/4][(i%4)*8+:8]=preload_expected[offset+i];
    `uvm_info("QSPI_PRELOAD_MAP", $sformatf(
      "flash_start=%08h flash_end=%08h image_byte=%0d count=%0d first_word=%08h seed=%08h",
      flash_base_addr+offset,flash_base_addr+offset+count-1,offset,count,page[0],preload_data_seed),UVM_LOW)
    qspi_wait_controller_idle();
    qspi_write_register("QSPI_CCR",'h00000106);
    qspi_wait_transfer_complete();
    qspi_indirect_write(flash_base_addr+offset,count,'h01002502,0,0,page);
    qspi_wait_flash_ready();
    offset+=count;
  end
  // A completed command/WIP=0 does not prove the flash accepted the data.
  qspi_read_flash_and_check_data(bytes,qspi_build_read_command(1),"programmed image readback");
endtask : qspi_program_expected_image

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Read flash and check data.
task qspi_feature_base_seq_c::qspi_read_flash_and_check_data(int bytes,bit [31:0] ccr,string label);
  bit [31:0] data[];
  bit [31:0] mask;
  bit [7:0] expected[];
  int start_failures=failures;
  int start_errors=uvm_report_server::get_server().get_severity_count(UVM_ERROR);
  if (bytes <= 0 || $size(image) < (bytes+3)/4)
    `uvm_fatal("QSPI_EXPECTED_DATA", "Invalid read length or missing expected image")
  expected=new[bytes];
  if (preload_valid) begin
    if (flash_base_addr!=preload_flash_base || bytes>$size(preload_expected))
      `uvm_fatal("QSPI_EXPECTED_DATA", "Read address/length does not match the saved preload")
    for(int i=0;i<bytes;i++) expected[i]=preload_expected[i];
  end else begin
    // Some status/polling sequences explicitly program their own image.
    for(int i=0;i<bytes;i++) expected[i]=image[i/4][(i%4)*8+:8];
  end
  data=new[(bytes+3)/4];
  foreach(data[i]) data[i]='hdeadbeef;
  qspi_indirect_read(flash_base_addr,bytes,ccr,0,0,data);
  for(int i=0;i<bytes;i++) begin
    qspi_data_integrity_check(data[i/4][(i%4)*8+:8], expected[i],$sformatf("%s flash_address=%08h image_byte=%0d", label, flash_base_addr+i, i));
    read_bytes++;
  end
  if(bytes%4) begin
    mask='1 << ((bytes%4)*8);
    qspi_check_condition((data[$size(data)-1]&mask)==0,{label," partial word is zero padded"});
  end
  if (qspi_coverage != null) qspi_coverage.read_cg.sample(
    (ccr[25:24]==3)?4:((ccr[25:24]==2)?2:1),bytes,ccr[31],active_ckmode,0,
    failures==start_failures && uvm_report_server::get_server().get_severity_count(UVM_ERROR)==start_errors);
  qspi_report_scenario_pass(label);
endtask : qspi_read_flash_and_check_data

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Start automatic polling.
task qspi_feature_base_seq_c::qspi_start_automatic_polling(bit [31:0] match,bit [31:0] mask,int length=1,bit pmm=0,bit apms=1,bit timeout_en=0,int timeout_cycles=64,bit irq_enable=0);
  bit [31:0] cr;
  qspi_configure_controller();
  qspi_write_register("QSPI_PSMKR",mask);
  qspi_write_register("QSPI_PSMAR",match);
  qspi_write_register("QSPI_PIR",poll_interval);
  qspi_write_register("QSPI_PTR",timeout_cycles);
  qspi_write_register("QSPI_DLR",length-1);
  cr='h02000001 | (int'(pmm)<<23) | (int'(apms)<<22) | (int'(timeout_en)<<2);
  if(irq_enable) cr|='h00300000;
  qspi_write_register("QSPI_CR",cr);
  qspi_write_register("QSPI_CCR",'h09000105);
endtask : qspi_start_automatic_polling

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Enable memory mapped read.
task qspi_feature_base_seq_c::qspi_enable_memory_mapped_read(int lanes=1,bit ddr=0);
  bit [31:0] ccr;
  qspi_configure_controller();
  active_xip_lanes=lanes;
  active_xip_ddr=ddr;
  ccr=qspi_build_read_command(lanes,ddr);
  ccr[27:26]=3;
  qspi_write_register("QSPI_CCR",ccr);
  irq_vif.wait_core(8);
endtask : qspi_enable_memory_mapped_read

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Access one word using a flash offset; add the system window base and return bus data/error.
task qspi_feature_base_seq_c::qspi_access_memory_mapped_word(
    bit [31:0] address, output bit [31:0] data,
    output bit error, input bit write_access=0);
  qspi_memory_response_c response;
  if (memory_access == null)
    `uvm_fatal("QSPI_MEMORY_PATH", "Register a memory adapter before XIP access")
  // This helper accepts a FLASH OFFSET; the selected adapter receives a system address.
  memory_access.access_words(`QSPI_AHB_SYSTEM_BASE + address, 1, 0, write_access, response);
  data = response.data[0];
  error = response.error[0];
endtask : qspi_access_memory_mapped_word

// Read the requested system-address range and compare each valid byte with the saved image.
task qspi_feature_base_seq_c::qspi_read_xip_and_check_data(int bytes,bit sequential=0,bit [31:0] system_address=0);
  bit [31:0] data;
  bit [31:0] ahb_start;
  bit error;
  int start_failures=failures;
  int start_errors=uvm_report_server::get_server().get_severity_count(UVM_ERROR);
  if (memory_access == null)
    `uvm_fatal("QSPI_MEMORY_PATH", "Register a memory adapter before XIP access")
  // Explicit system addresses are driven unchanged; legacy callers supply a flash offset.
  ahb_start=(system_address==0) ? (`QSPI_AHB_SYSTEM_BASE+flash_base_addr) : system_address;
  if (!preload_valid || bytes<=0 || bytes>$size(preload_expected) ||
      ahb_start!=(`QSPI_AHB_SYSTEM_BASE+preload_flash_base)) begin
    qspi_check_condition(0,$sformatf("XIP preload mapping mismatch: system_start=%08h saved_flash_base=%08h bytes=%0d saved_bytes=%0d",
      ahb_start,preload_flash_base,bytes,$size(preload_expected)));
    return;
  end
  if ($size(image)<(bytes+3)/4) begin
    qspi_check_condition(0,"XIP expected image was resized after preload");
    return;
  end
  // Catch accidental image regeneration instead of silently adopting new data.
  for(int i=0;i<bytes;i++) begin
    if (image[i/4][(i%4)*8+:8]!==preload_expected[i]) begin
      qspi_check_condition(0,$sformatf("Image changed after preload: image_byte=%0d saved=%02h current=%02h saved_seed=%08h current_seed=%08h",
        i,preload_expected[i],image[i/4][(i%4)*8+:8],preload_data_seed,data_seed));
      return;
    end
  end
  `uvm_info("QSPI_XIP_MAP",$sformatf(
    "system_start=%08h flash_start=%08h image_byte=0 bytes=%0d lanes=%0d saved_seed=%08h",
    ahb_start,preload_flash_base,bytes,active_xip_lanes,preload_data_seed),UVM_LOW)
  for(int offset=0;offset<bytes;) begin
    qspi_memory_response_c response;
    int beats;
    beats = sequential ? (bytes-offset+3)/4 : 1;
    if (beats > (`QSPI_AHB_MAX_BURST_BYTES - int'((ahb_start + offset) % `QSPI_AHB_MAX_BURST_BYTES))/4)
      beats = (`QSPI_AHB_MAX_BURST_BYTES - int'((ahb_start + offset) % `QSPI_AHB_MAX_BURST_BYTES))/4;
    memory_access.access_words(ahb_start + offset, beats, sequential, 0, response);
    if (response == null || $size(response.data) != beats || $size(response.error) != beats)
      `uvm_fatal("QSPI_XIP_RESPONSE", "Bus adapter returned an incomplete XIP response")
    for(int beat=0;beat<beats;beat++) begin
      data = response.data[beat];
      error = response.error[beat];
      qspi_check_condition(!error,$sformatf("XIP HRESP OK system_address=%08h",ahb_start+offset));
      for(int b=0;b<4 && offset+b<bytes;b++) begin
        qspi_data_integrity_check(data[b*8+:8], preload_expected[offset+b],$sformatf("XIP system_address=%08h flash_address=%08h image_byte=%0d",
          ahb_start+offset+b, preload_flash_base+offset+b, offset+b));
        read_bytes++;
      end
      offset+=4;
    end
  end
  qspi_wait_controller_idle();
  if (qspi_coverage != null) qspi_coverage.read_cg.sample(active_xip_lanes,bytes,active_xip_ddr,active_ckmode,1,
    failures==start_failures && uvm_report_server::get_server().get_severity_count(UVM_ERROR)==start_errors);
endtask : qspi_read_xip_and_check_data

`endif
