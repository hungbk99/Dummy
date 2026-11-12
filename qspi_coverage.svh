`ifndef QSPI_COVERAGE_SVH
`define QSPI_COVERAGE_SVH

// Checker-driven functional coverage. Passing bins are gated by checker results;
// they are not counts of randomized requests or register writes.
class qspi_coverage_c extends uvm_component;
  `uvm_component_utils(qspi_coverage_c)

  covergroup feature_cg with function sample(int feature_id, bit passed);
    option.per_instance = 1;
    feature: coverpoint feature_id {
      bins registers={0}; bins clocks={1}; bins indirect={2}; bins polling={3};
      bins xip={4}; bins mixed={5}; bins irq={6}; bins abort_mode={7};
      bins frames={8}; bins fifo={9}; bins delays={10}; bins dma={11};
      bins sioo={12}; bins timeout_error={13};
    }
    result: coverpoint passed { bins fail={0}; bins pass={1}; }
    feature_result: cross feature, result;
    verified: coverpoint feature_id iff (passed) {
      bins registers={0}; bins clocks={1}; bins indirect={2}; bins polling={3};
      bins xip={4}; bins mixed={5}; bins irq={6}; bins abort_mode={7};
      bins frames={8}; bins fifo={9}; bins delays={10}; bins dma={11};
      bins sioo={12}; bins timeout_error={13};
    }
  endgroup

  // Actual completed read, with payload comparison and APB response checking.
  // CKMODE maps to modes 0/3; independent CPHA is not exposed by this RTL.
  covergroup read_cg with function sample(int lanes, int bytes, bit ddr,
                                         bit ckmode, bit xip, bit passed);
    option.per_instance = 1;
    width: coverpoint lanes iff (passed) {
      bins single_lane={1}; bins dual_lane={2}; bins quad_lane={4};
    }
    length: coverpoint bytes iff (passed) {
      bins b1={1}; bins b4={4}; bins b8={8}; bins b16={16};
      bins b32={32}; bins b128={128}; bins b256={256};
      bins b512={512}; bins b1024={1024};
    }
    rate: coverpoint ddr iff (passed) { bins sdr={0}; bins ddr_rate={1}; }
    clock_mode: coverpoint ckmode iff (passed) { bins mode0={0}; bins mode3={1}; }
    access_mode: coverpoint xip iff (passed) { bins indirect={0}; bins memory_mapped={1}; }
    indirect_size: coverpoint bytes iff (passed && !xip) {
      bins b1={1}; bins b4={4}; bins b8={8}; bins b16={16}; bins b32={32}; bins b128={128};
    }
    xip_size: coverpoint bytes iff (passed && xip) {
      bins b1={1}; bins b4={4}; bins b8={8}; bins b16={16}; bins b32={32};
      bins b128={128}; bins b256={256}; bins b512={512}; bins b1024={1024};
    }
    indirect_matrix: cross width, indirect_size, rate, clock_mode iff (!xip && passed);
    xip_matrix: cross width, xip_size iff (xip && passed);
    result: coverpoint passed { bins fail={0}; bins pass={1}; }
  endgroup

  covergroup frame_cg with function sample(int address_bytes, int alternate_bytes,
                                          int dummy_cycles, bit passed);
    option.per_instance = 1;
    address_size: coverpoint address_bytes iff (passed) { bins bytes_each[]={1,2,3,4}; }
    alternate_size: coverpoint alternate_bytes iff (passed) { bins bytes_each[]={1,2,3,4}; }
    dummy: coverpoint dummy_cycles iff (passed) {
      bins zero={0}; bins middle={[1:30]}; bins maximum={31};
    }
    phase_sizes: cross address_size, alternate_size;
    result: coverpoint passed { bins fail={0}; bins pass={1}; }
  endgroup

  covergroup delay_cg with function sample(int css, int csh, int csidle, bit passed);
    option.per_instance = 1;
    setup_time: coverpoint css iff (passed) { bins zero={0}; bins one={1}; bins three={3}; bins other={[2:2],[4:255]}; }
    hold_time: coverpoint csh iff (passed) { bins zero={0}; bins one={1}; bins three={3}; bins other={[2:2],[4:255]}; }
    idle_time: coverpoint csidle iff (passed) { bins zero={0}; bins one={1}; bins three={3}; bins other={[2:2],[4:255]}; }
    result: coverpoint passed { bins fail={0}; bins pass={1}; }
  endgroup

  // Observed successful APB reads. Access coverage does not imply value correctness.
  covergroup register_cg with function sample(int offset);
    option.per_instance = 1;
    address: coverpoint offset {
      bins cr={32'h00}; bins dcr={32'h04}; bins sr={32'h08}; bins fcr={32'h0c};
      bins dlr={32'h10}; bins ccr={32'h14}; bins ar={32'h18}; bins abr={32'h1c};
      bins dr={32'h20}; bins psmkr={32'h24}; bins psmar={32'h28}; bins pir={32'h2c};
      bins ptr={32'h30}; bins dmacr={32'h34}; bins dmasr={32'h38};
      bins dmafcr={32'h3c}; bins dly={32'h40}; bins reserved={[32'h44:32'hfc]};
    }
  endgroup

  covergroup fifo_cg with function sample(int tx_level, int rx_level);
    option.per_instance = 1;
    tx: coverpoint tx_level {
      bins empty={0}; bins one={1}; bins middle={[2:30]}; bins near_full={31}; bins full={32};
    }
    rx: coverpoint rx_level {
      bins empty={0}; bins one={1}; bins middle={[2:30]}; bins near_full={31}; bins full={32};
    }
  endgroup

  covergroup irq_cg with function sample(int source, bit expected, int action, bit passed);
    option.per_instance = 1;
    flag: coverpoint source iff (passed) {
      bins tef={0}; bins tcf={1}; bins txftf={2}; bins rxftf={3};
      bins smf={4}; bins stof={5}; bins txovrf={6}; bins rxudrf={7};
    }
    level: coverpoint expected iff (passed) { bins low_level={0}; bins high_level={1}; }
    operation: coverpoint action iff (passed) { bins assert_flag={0}; bins clear_flag={1}; bins reassert_flag={2}; }
    source_level: cross flag, level;
    source_clear: cross flag, operation {
      ignore_bins reassert_other_flags = binsof(operation.reassert_flag) &&
        binsof(flag) intersect {0,1,4,5,6,7};
    }
    result: coverpoint passed { bins fail={0}; bins pass={1}; }
  endgroup

  covergroup polling_cg with function sample(int scenario, bit passed);
    option.per_instance = 1;
    verified: coverpoint scenario iff (passed) {
      bins and_length_each[]={1,2,3,4}; bins or_match={5}; bins timeout_stop={6};
      bins zero_mask_and={7}; bins zero_mask_or={8};
      bins illegal_dlr_each[]={9,10,11,12}; bins wip_to_ready={13};
    }
    result: coverpoint passed { bins fail={0}; bins pass={1}; }
  endgroup

  covergroup abort_cg with function sample(int mode, bit passed);
    option.per_instance = 1;
    recovered: coverpoint mode iff (passed) {
      bins indirect={0}; bins polling={1}; bins memory_mapped_pending_ahb={2};
    }
    result: coverpoint passed { bins fail={0}; bins pass={1}; }
  endgroup

  extern function new(string name="qspi_coverage_c", uvm_component parent=null);
endclass : qspi_coverage_c

function qspi_coverage_c::new(string name="qspi_coverage_c", uvm_component parent=null);
    super.new(name,parent);
    feature_cg=new(); read_cg=new(); frame_cg=new(); delay_cg=new();
    register_cg=new(); fifo_cg=new(); irq_cg=new(); polling_cg=new(); abort_cg=new();
  endfunction : new

`endif
