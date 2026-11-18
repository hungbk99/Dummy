`ifndef QSPI_XIP_SEQ_SVH
`define QSPI_XIP_SEQ_SVH

// QSPI XIP random low/high/middle ranges, cache hit and range/write errors.
class qspi_xip_seq_c extends qspi_feature_base_seq_c;
  `uvm_object_utils(qspi_xip_seq_c)
  rand int unsigned transfer_bytes;
  rand bit [31:0] system_start_addr;
  rand int unsigned region; // 0: low boundary, 1: high boundary, 2: middle
  int unsigned lane_count;

  constraint xip_transfer_c {
    transfer_bytes inside {[4:1024]};
    transfer_bytes % 4 == 0;
    region inside {[0:2]};
    system_start_addr[1:0] == 0;
    if (region == 0)
      system_start_addr == `QSPI_AHB_SYSTEM_BASE;
    if (region == 1)
      system_start_addr == `QSPI_AHB_SYSTEM_BASE + `QSPI_AHB_WINDOW_BYTES - transfer_bytes;
    if (region == 2)
      system_start_addr inside {[(`QSPI_AHB_SYSTEM_BASE+4096):
        (`QSPI_AHB_SYSTEM_BASE+`QSPI_AHB_WINDOW_BYTES-4096-1024)]};
  }
  // Select this scenario's legal fixed inputs for the dedicated Verilator list.
  virtual function void qspi_set_directed_stimulus();
    super.qspi_set_directed_stimulus();
    transfer_bytes = 512; region = 0; system_start_addr = `QSPI_AHB_SYSTEM_BASE;
  endfunction

  extern function new(string name = "qspi_xip_seq_c");
  extern virtual task body();
  extern virtual task qspi_select_xip_region(int selected_region);
  extern virtual task qspi_check_all_xip_lane_modes();
  extern virtual task qspi_check_xip_cache_hit();
  extern virtual task qspi_check_xip_rejected_accesses();
  extern function string qspi_xip_region_name();
  extern function void post_randomize();
endclass : qspi_xip_seq_c

// Construct this object and initialize its inherited UVM state.
function qspi_xip_seq_c::new(string name = "qspi_xip_seq_c");
  super.new(name, "xip");
endfunction : new

// Each region has one intended image, followed by three read-lane scenarios.
// Run this scenario: XIP random low/high/middle ranges, cache hit and range/write errors. Check failures are reported through UVM.
task qspi_xip_seq_c::body();
  qspi_initialize_flash_and_controller();
`ifndef VERILATOR
  flash_region_c.constraint_mode(0);
`endif
  for (int selected_region = 0; selected_region < 3; selected_region++) begin
    qspi_select_xip_region(selected_region);
    qspi_configure_controller();
    qspi_program_expected_image(transfer_bytes);
    qspi_check_all_xip_lane_modes();
  end
  qspi_check_xip_cache_hit();
  qspi_check_xip_rejected_accesses();
endtask : body

// System address is driven unchanged on the memory bus. Only indirect flash
// setup uses the low 24-bit offset; this does not translate the bus address.
// Select xip region.
task qspi_xip_seq_c::qspi_select_xip_region(int selected_region);
`ifdef VERILATOR
  region = selected_region;
  // Fixed lengths exercise aligned and unaligned page starts reproducibly.
  if (directed_stimulus) begin
    case (region)
      0: transfer_bytes = 512;
      1: transfer_bytes = 204;
      2: transfer_bytes = 648;
    endcase
  end else transfer_bytes = 4 * $urandom_range(256, 1);
  case (region)
    0: system_start_addr = `QSPI_AHB_SYSTEM_BASE;
    1: system_start_addr = `QSPI_AHB_SYSTEM_BASE + `QSPI_AHB_WINDOW_BYTES - transfer_bytes;
    2: if (directed_stimulus) system_start_addr = `QSPI_AHB_SYSTEM_BASE + 32'h0007_3034;
       else system_start_addr = `QSPI_AHB_SYSTEM_BASE +
         4 * $urandom_range((`QSPI_AHB_WINDOW_BYTES - 4096 - 1024)/4, 1024);
  endcase
  post_randomize();
`else
  if (!this.randomize() with { region == local::selected_region; })
    `uvm_fatal("QSPI_RANDOMIZE", "Cannot randomize XIP boundary/interior transfer")
`endif
  flash_base_addr = {8'h00, system_start_addr[23:0]};
endtask : qspi_select_xip_region

// Xip region name.
function string qspi_xip_seq_c::qspi_xip_region_name();
  case (region)
    0: return "low";
    1: return "high";
    2: return "middle";
    default: return "invalid";
  endcase
endfunction : qspi_xip_region_name

// Check all xip lane modes.
task qspi_xip_seq_c::qspi_check_all_xip_lane_modes();
  for (int lanes = 1; lanes <= 4; lanes *= 2) begin
    lane_count = lanes;
    qspi_enable_memory_mapped_read(lanes);
    qspi_read_xip_and_check_data(transfer_bytes, 1, system_start_addr);
    qspi_report_scenario_pass($sformatf(
      "XIP %s lanes=%0d system_start=%08h system_end=%08h bytes=%0d",
      qspi_xip_region_name(), lanes, system_start_addr,
      system_start_addr + transfer_bytes - 1, transfer_bytes));
  end
endtask : qspi_check_all_xip_lane_modes

// First read fills the cache; the same word must then return without a frame.
// Check xip cache hit.
task qspi_xip_seq_c::qspi_check_xip_cache_hit();
  int frames_before_cached_read;
  qspi_enable_memory_mapped_read();
  qspi_read_xip_and_check_data(4, 0, system_start_addr);
  frames_before_cached_read = monitor_vif.frames;
  qspi_read_xip_and_check_data(4, 0, system_start_addr);
  qspi_check_condition(monitor_vif.frames == frames_before_cached_read,
                       "cache hit creates no serial frame");
endtask : qspi_check_xip_cache_hit

// Check xip rejected accesses.
task qspi_xip_seq_c::qspi_check_xip_rejected_accesses();
  bit [31:0] data;
  bit error;
  qspi_access_memory_mapped_word(`QSPI_AHB_WINDOW_BYTES, data, error);
  qspi_check_condition(error, "address 0x31000000 above the XIP window returns ERROR");
  qspi_access_memory_mapped_word(32'hffff_fffc, data, error);
  qspi_check_condition(error, "address 0x2ffffffc below the XIP window returns ERROR");
  qspi_access_memory_mapped_word(flash_base_addr, data, error, 1);
  qspi_check_condition(error, "writes to the XIP window return ERROR");
  qspi_report_scenario_pass("XIP random low/high/middle ranges, cache hit and range/write errors");
endtask : qspi_check_xip_rejected_accesses

// Report the selected stimulus so failures can be reproduced from the run log.
function void qspi_xip_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s region=%0d system_start=%08h system_end=%08h transfer_bytes=%0d",
    get_type_name(),region,system_start_addr,system_start_addr+transfer_bytes-1,transfer_bytes), UVM_LOW)
endfunction : post_randomize

`endif
