`ifndef QSPI_BUS_ACCESS_SVH
`define QSPI_BUS_ACCESS_SVH

// Transport-neutral result. Payloads and protocol errors stay associated by beat.
// QSPI bus access.
class qspi_memory_response_c extends uvm_object;
  `uvm_object_utils(qspi_memory_response_c)
  logic [31:0] data[];
  bit error[];

  // Construct this object and initialize its inherited UVM state.
  function new(string name = "qspi_memory_response");
    super.new(name);
  endfunction
endclass

// SoC environments implement this interface for their CPU/VIP bus.
// All addresses passed to an adapter are absolute bus addresses.
// QSPI bus access.
virtual class qspi_bus_access_c extends uvm_object;
  uvm_sequencer_base sequencer;
  bit [63:0] register_base_address = 0;

  // Construct this object and initialize its inherited UVM state.
  function new(string name = "qspi_bus_access");
    super.new(name);
  endfunction

  // Read32.
  pure virtual task read32(bit [63:0] address, output bit [31:0] data,
                           output bit error, input bit expected_error = 0);
  // Write32.
  pure virtual task write32(bit [63:0] address, bit [31:0] data,
                            output bit error, input bit expected_error = 0);

  // Default for SoC CPU paths: independent 32-bit accesses. An adapter can
  // override this task to issue native bursts without changing QSPI tests.
  // Access words.
  virtual task access_words(bit [31:0] address, int unsigned beats,
                            bit sequential, bit write_access,
                            output qspi_memory_response_c response);
    bit [31:0] value;
    bit error;
    response = qspi_memory_response_c::type_id::create("response");
    response.data = new[beats];
    response.error = new[beats];
    for (int beat = 0; beat < beats; beat++) begin
      if (write_access) write32(address + 4*beat, 0, error, 1);
      else read32(address + 4*beat, value, error);
      response.data[beat] = write_access ? 0 : value;
      response.error[beat] = error;
    end
  endtask
endclass

// QSPI bus access.
class qspi_apb_bus_access_c extends qspi_bus_access_c;
  `uvm_object_utils(qspi_apb_bus_access_c)

  // Construct this object and initialize its inherited UVM state.
  function new(string name = "qspi_apb_bus_access");
    super.new(name);
  endfunction

  // Read32.
  virtual task read32(bit [63:0] address, output bit [31:0] data,
                      output bit error, input bit expected_error = 0);
    apb_master_seq request;
    if (sequencer == null || (address >> `APB_ADDR_WIDTH) != 0)
      `uvm_fatal("QSPI_APB_SETUP", "Missing APB sequencer or address exceeds APB width")
    request = apb_master_seq::type_id::create("qspi_apb_read");
    request.set_sequencer(sequencer);
    request.apb_master_read(address, data, 0, expected_error ? ERROR : NO_ERROR);
    error = (request.last_pslverr == ERROR);
  endtask

  // Write32.
  virtual task write32(bit [63:0] address, bit [31:0] data,
                       output bit error, input bit expected_error = 0);
    apb_master_seq request;
    if (sequencer == null || (address >> `APB_ADDR_WIDTH) != 0)
      `uvm_fatal("QSPI_APB_SETUP", "Missing APB sequencer or address exceeds APB width")
    request = apb_master_seq::type_id::create("qspi_apb_write");
    request.set_sequencer(sequencer);
    request.apb_master_write(address, data, 0, expected_error ? ERROR : NO_ERROR);
    error = (request.last_pslverr == ERROR);
  endtask
endclass

// QSPI bus access.
class qspi_ahb_bus_access_c extends qspi_bus_access_c;
  `uvm_object_utils(qspi_ahb_bus_access_c)

  // Construct this object and initialize its inherited UVM state.
  function new(string name = "qspi_ahb_bus_access");
    super.new(name);
  endfunction

  // Access words.
  virtual task access_words(bit [31:0] address, int unsigned beats,
                            bit sequential, bit write_access,
                            output qspi_memory_response_c response);
    qspi_ahb_access_seq_c request;
    if (sequencer == null)
      `uvm_fatal("QSPI_AHB_SETUP", "Missing memory-access sequencer")
    request = qspi_ahb_access_seq_c::type_id::create("qspi_ahb_access");
    request.address = address;
    request.beats = beats;
    request.incrementing = sequential;
    request.write_access = write_access;
    request.start(sequencer);
    if (request.result == null || $size(request.result.read_data) != beats ||
        $size(request.result.responses) != beats)
      `uvm_fatal("QSPI_AHB_RESPONSE", "AHB response length does not match the request")
    response = qspi_memory_response_c::type_id::create("response");
    response.data = new[beats];
    response.error = new[beats];
    foreach (response.data[beat]) begin
      response.data[beat] = request.result.read_data[beat];
      response.error[beat] = request.result.responses[beat] != AHB_OKAY;
    end
  endtask

  // Read32.
  virtual task read32(bit [63:0] address, output bit [31:0] data,
                      output bit error, input bit expected_error = 0);
    qspi_memory_response_c response;
    if (address[63:32] != 0)
      `uvm_fatal("QSPI_AHB_ADDRESS", "Address exceeds the 32-bit AHB interface")
    access_words(address[31:0], 1, 0, 0, response);
    data = response.data[0];
    error = response.error[0];
  endtask

  // Write32.
  virtual task write32(bit [63:0] address, bit [31:0] data,
                       output bit error, input bit expected_error = 0);
    qspi_memory_response_c response;
    // The QSPI XIP port rejects writes; the negative test drives zero data.
    if (address[63:32] != 0)
      `uvm_fatal("QSPI_AHB_ADDRESS", "Address exceeds the 32-bit AHB interface")
    access_words(address[31:0], 1, 0, 1, response);
    error = response.error[0];
  endtask
endclass
`endif
