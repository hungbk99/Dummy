`ifndef QSPI_VIRTUAL_SEQUENCER_SVH
`define QSPI_VIRTUAL_SEQUENCER_SVH

// Shared registry used by both standalone and SoC tests (slides 36–37).
// SoC environments may extend this class or register their adapters directly.
// QSPI virtual sequencer.
class qspi_virtual_sequencer_c extends uvm_sequencer;
  `uvm_component_utils(qspi_virtual_sequencer_c)

  uvm_sequencer_base apb_seqr[string];
  uvm_sequencer_base ahb_seqr[string];
  uvm_sequencer_base axi_seqr[string];
  qspi_bus_access_c register_paths[string];
  qspi_bus_access_c memory_paths[string];
  qspi_coverage_c coverage;

  // Construct this object and initialize its inherited UVM state.
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Get register path.
  function qspi_bus_access_c get_register_path(string path);
    if (!register_paths.exists(path) || register_paths[path] == null)
      `uvm_fatal("QSPI_REGISTER_PATH", $sformatf("No register adapter registered for %s", path))
    return register_paths[path];
  endfunction

  // Get memory path.
  function qspi_bus_access_c get_memory_path(string path);
    if (!memory_paths.exists(path) || memory_paths[path] == null)
      `uvm_fatal("QSPI_MEMORY_PATH", $sformatf("No memory adapter registered for %s", path))
    return memory_paths[path];
  endfunction
endclass
`endif
