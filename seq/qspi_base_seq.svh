`ifndef QSPI_BASE_SEQ_C_SVH
`define QSPI_BASE_SEQ_C_SVH

// Reusable QSPI behavior depends on a shared registry, never on an env hierarchy.
// QSPI base seq.
class qspi_base_seq_c extends base_sequence;
  `uvm_object_utils(qspi_base_seq_c)

  qspi_virtual_sequencer_c base_vseqr;
  qspi_coverage_c qspi_coverage;
  string access_path = "QSPI";
  qspi_bus_access_c register_access;
  qspi_bus_access_c memory_access;

  `include "qspi_reg_info.svh"

  // Construct this object and initialize its inherited UVM state.
  function new(string name = "qspi_base_seq_c");
    super.new(name);
  endfunction

  // Resolve the configured access path and prepare the sequence before stimulus starts.
  virtual task pre_body();
    string cpu;
    super.pre_body();
    if (base_vseqr == null)
      `uvm_fatal("QSPI_VSEQR", "Test must provide the shared base_vseqr handle")
    if ($value$plusargs("QSPI_CPU=%s", cpu)) begin
      case (cpu)
        "STANDALONE": access_path = "QSPI";
        "IBEX", "CVA6": access_path = cpu;
        default: `uvm_fatal("QSPI_CPU", "Use +QSPI_CPU=STANDALONE, IBEX, or CVA6")
      endcase
    end
    register_access = base_vseqr.get_register_path(access_path);
    // Register-only sequences do not require a memory-window transport.
    if (base_vseqr.memory_paths.exists(access_path))
      memory_access = base_vseqr.get_memory_path(access_path);
    qspi_coverage = base_vseqr.coverage;
    `uvm_info("QSPI_ACCESS_PATH", $sformatf("Register and XIP access path: %s", access_path), UVM_LOW)
  endtask

  // Bus write32.
  virtual task qspi_bus_write32(bit [31:0] address, bit [31:0] data,
                                bit expected_error = 0);
    bit error;
    register_access.write32(register_access.register_base_address + address,
                            data, error, expected_error);
    if (error != expected_error)
      `uvm_error("QSPI_BUS_WRITE", $sformatf("path=%s offset=%08h expected_error=%0b actual_error=%0b",
        access_path, address, expected_error, error))
  endtask

  // Bus read32.
  virtual task qspi_bus_read32(bit [31:0] address, output bit [31:0] data,
                               output bit error, input bit expected_error = 0);
    register_access.read32(register_access.register_base_address + address,
                           data, error, expected_error);
    if (error != expected_error)
      `uvm_error("QSPI_BUS_READ", $sformatf("path=%s offset=%08h expected_error=%0b actual_error=%0b",
        access_path, address, expected_error, error))
    if (!error && qspi_coverage != null) begin
      if (qspi_coverage != null) qspi_coverage.register_cg.sample(int'(address));
      if (address == 32'h08)
        if (qspi_coverage != null) qspi_coverage.fifo_cg.sample(int'(data[13:8]), int'(data[21:16]));
    end
  endtask

  // Lookup register address.
  virtual function bit qspi_lookup_register_address(string register_name,
                                                    output bit [31:0] address);
    address = '0;
    foreach (QSPI_RW_REGS[index]) begin
      if (QSPI_RW_REGS[index].name == register_name) begin
        address = QSPI_RW_REGS[index].addr;
        return 1;
      end
    end
    return 0;
  endfunction
endclass
`endif
