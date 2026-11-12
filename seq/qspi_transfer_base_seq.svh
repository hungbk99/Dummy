`ifndef QSPI_TRANSFER_BASE_SEQ_SVH
`define QSPI_TRANSFER_BASE_SEQ_SVH

// Shared bus/flash operations; no concrete test body or test selector.
class qspi_transfer_base_seq_c extends qspi_base_seq_c;
  extern function new(string name = "qspi_transfer_base_seq_c");

  extern virtual task qspi_read_reg(
      input  string     reg_name,
      output bit [31:0] data
  );

  extern virtual task qspi_write_reg(
      input string     reg_name,
      input bit [31:0] data
  );

  extern virtual task qspi_wait_idle();

  extern virtual task qspi_wait_complete();

  extern virtual task qspi_flash_read_vcr(output bit [7:0] value);

  extern virtual task qspi_flash_wait_ready();

  extern virtual task qspi_flash_write_config(
      input bit [7:0] opcode,
      input bit [7:0] value
  );

  extern virtual task qspi_indirect_write(
      input bit [31:0] flash_addr,
      input bit [31:0] byte_count,
      input bit [31:0] ccr_cfg,
      input bit        use_abr,
      input bit [31:0] abr_data,
      input bit [31:0] tx_words[]
  );

  extern virtual task qspi_indirect_read(
      input  bit [31:0] flash_addr,
      input  bit [31:0] byte_count,
      input  bit [31:0] ccr_cfg,
      input  bit        use_abr,
      input  bit [31:0] abr_data,
      ref    bit [31:0] rx_words[]
  );
endclass : qspi_transfer_base_seq_c

function qspi_transfer_base_seq_c::new(string name = "qspi_transfer_base_seq_c");
    super.new(name);
  endfunction : new


//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_transfer_base_seq_c::qspi_read_reg(
    input  string     reg_name,
    output bit [31:0] data
);
    bit [31:0] addr;
    bit        err_rsp;

    if (!qspi_get_reg_addr(reg_name, addr))
        `uvm_error("QSPI", $sformatf("Unknown register: %s", reg_name))

    reg_read32(addr, data, err_rsp);

    if (err_rsp)
        `uvm_error("QSPI", $sformatf("Read error: %s", reg_name))
endtask : qspi_read_reg

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_transfer_base_seq_c::qspi_write_reg(
    input string     reg_name,
    input bit [31:0] data
);
    bit [31:0] addr;

    if (!qspi_get_reg_addr(reg_name, addr))
        `uvm_error("QSPI", $sformatf("Unknown register: %s", reg_name))

    reg_write32(addr, data);
endtask : qspi_write_reg

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_transfer_base_seq_c::qspi_wait_idle();

    bit [31:0] sr;
    bit        idle;

    idle = 0;

    for (int i = 0; i < 1000; i++) begin
        qspi_read_reg("QSPI_SR", sr);

        if (sr[6] == 1'b0) begin
            idle = 1;
            break;
        end
    end

    if (!idle)
        `uvm_error("QSPI", "BUSY timeout")

endtask : qspi_wait_idle

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_transfer_base_seq_c::qspi_wait_complete();

    bit [31:0] sr;
    bit        complete;

    complete = 0;

    for (int i = 0; i < 100000; i++) begin

        qspi_read_reg("QSPI_SR", sr);

        if (sr[0]) begin
            `uvm_error("QSPI", "QSPI transfer error: SR.TEF = 1")
        end

        if (sr[1]) begin
            complete = 1;
            break;
        end

    end

    if (!complete)
        `uvm_error("QSPI", "Transfer complete timeout")

    // Clear TCF: FCR.CTCF = bit 1
    qspi_write_reg("QSPI_FCR", 32'h0000_0002);

endtask : qspi_wait_complete

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_transfer_base_seq_c::qspi_flash_read_vcr(output bit [7:0] value);
    bit [31:0] sr;
    bit [31:0] dr_addr;
    bit [31:0] dr_data;
    bit        err_rsp;
    bit        rx_ready;

    value = '0;
    rx_ready = 0;
    qspi_wait_idle();
    qspi_get_reg_addr("QSPI_DR", dr_addr);

    // One-byte indirect read, instruction and data on single lane, no address.
    qspi_write_reg("QSPI_DLR", 32'd0);
    qspi_write_reg("QSPI_CCR", 32'h0500_0185);

    for (int poll = 0; poll < 100000; poll++) begin
        qspi_read_reg("QSPI_SR", sr);
        if (sr[0])
            `uvm_error("QSPI_FLASH_CFG", "TEF while reading N25Q VCR")
        if (sr[21:16] != 0) begin
            rx_ready = 1;
            break;
        end
    end

    if (!rx_ready) begin
        `uvm_error("QSPI_FLASH_CFG", "Timed out waiting for N25Q VCR data")
    end else begin
        reg_read32(dr_addr, dr_data, err_rsp);
        if (err_rsp)
            `uvm_error("QSPI_FLASH_CFG", "QSPI_DR read error while reading N25Q VCR")
        else
            value = dr_data[7:0];
    end

    qspi_wait_complete();
endtask : qspi_flash_read_vcr

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_transfer_base_seq_c::qspi_flash_wait_ready();
    bit [31:0] sr;
    bit [31:0] flash_status;
    bit [31:0] dr_addr;
    bit        err_rsp;
    bit        ready;

    ready = 0;
    qspi_get_reg_addr("QSPI_DR", dr_addr);

    for (int poll = 0; poll < 1000; poll++) begin
        qspi_wait_idle();

        // One-byte indirect read, instruction and data on single lane.
        qspi_write_reg("QSPI_DLR", 32'd0);
        qspi_write_reg("QSPI_CCR", 32'h0500_0105);

        do begin
            qspi_read_reg("QSPI_SR", sr);
            if (sr[0])
                `uvm_error("QSPI_FLASH_STATUS", "TEF while reading flash status")
        end while (sr[21:16] == 0);

        reg_read32(dr_addr, flash_status, err_rsp);
        if (err_rsp)
            `uvm_error("QSPI_FLASH_STATUS", "QSPI_DR read error while polling WIP")

        qspi_wait_complete();

        if (flash_status[0] == 1'b0) begin
            ready = 1;
            break;
        end
    end

    if (!ready)
        `uvm_error("QSPI_FLASH_STATUS", "Timed out waiting for N25Q WIP to clear")
endtask : qspi_flash_wait_ready

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_transfer_base_seq_c::qspi_flash_write_config(
    input bit [7:0] opcode,
    input bit [7:0] value
);
    bit [31:0] ccr;

    if ((opcode != 8'h81) && (opcode != 8'h61)) begin
        `uvm_error("QSPI_FLASH_CFG",
          $sformatf("Unsupported N25Q config-register opcode: 0x%02h", opcode))
        return;
    end

    // WREN (06h), instruction phase only, single lane.
    qspi_wait_idle();
    qspi_write_reg("QSPI_CCR", 32'h0000_0106);
    qspi_wait_complete();

    // Write one configuration byte, instruction and data on single lane.
    qspi_wait_idle();
    qspi_write_reg("QSPI_DLR", 32'd0);  // DLR is byte count minus one
    ccr = 32'h0100_0100 | {24'd0, opcode}; // DMODE=single, IMODE=single
    qspi_write_reg("QSPI_CCR", ccr);
    qspi_write_reg("QSPI_DR", {24'd0, value});
    qspi_wait_complete();
endtask : qspi_flash_write_config

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_transfer_base_seq_c::qspi_indirect_write(
    input bit [31:0] flash_addr,
    input bit [31:0] byte_count,
    input bit [31:0] ccr_cfg,
    input bit        use_abr,
    input bit [31:0] abr_data,
    input bit [31:0] tx_words[]
);

    bit [31:0] sr;
    bit [31:0] ccr;
    int unsigned word_count;

    // --------------------------------------------------------
    // Step 1: Wait for BUSY = 0
    // --------------------------------------------------------

    qspi_wait_idle();

    if (byte_count == 0)
        `uvm_error("QSPI", "Invalid transfer length: zero bytes")

    word_count = (byte_count + 3) / 4;

    if ($size(tx_words) < word_count)
        `uvm_error("QSPI", "TX data array is too small")


    // --------------------------------------------------------
    // Step 2: Program DLR, ABR and CCR
    // --------------------------------------------------------

    qspi_write_reg("QSPI_DLR", byte_count - 1);

    if (use_abr)
        qspi_write_reg("QSPI_ABR", abr_data);

    // FMODE = 00: Indirect write
    ccr = ccr_cfg;
    ccr[27:26] = 2'b00;

    qspi_write_reg("QSPI_CCR", ccr);

    // Write AR when address phase is enabled.
    if (ccr[11:10] != 2'b00)
        qspi_write_reg("QSPI_AR", flash_addr);


    // --------------------------------------------------------
    // Step 3: Write DR while TX FIFO is not full
    // --------------------------------------------------------

    for (int i = 0; i < word_count; i++) begin

        // Wait until TXFLEVEL < FIFO depth (32 words).
        do begin
            qspi_read_reg("QSPI_SR", sr);

            if (sr[0])
                `uvm_error("QSPI", "TX transfer error")

        end while (sr[13:8] >= 32);

        // Write one word to DR.
        // First DR write starts the transfer when applicable.
        qspi_write_reg("QSPI_DR", tx_words[i]);

    end


    // --------------------------------------------------------
    // Step 4: Wait for TCF and clear it
    // --------------------------------------------------------

    qspi_wait_complete();

    `uvm_info("QSPI",
        $sformatf("Indirect WRITE completed: ADDR=0x%08h BYTES=%0d",
                  flash_addr, byte_count),
        UVM_LOW)

endtask : qspi_indirect_write

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_transfer_base_seq_c::qspi_indirect_read(
    input  bit [31:0] flash_addr,
    input  bit [31:0] byte_count,
    input  bit [31:0] ccr_cfg,
    input  bit        use_abr,
    input  bit [31:0] abr_data,
    ref    bit [31:0] rx_words[]
);

    bit [31:0] sr;
    bit [31:0] ccr;
    bit [31:0] addr;
    bit        err_rsp;

    int unsigned word_count;

    // --------------------------------------------------------
    // Step 1: Wait for BUSY = 0
    // --------------------------------------------------------

    qspi_wait_idle();

    if (byte_count == 0)
        `uvm_error("QSPI", "Invalid transfer length: zero bytes")

    word_count = (byte_count + 3) / 4;

    if ($size(rx_words) < word_count)
        `uvm_error("QSPI", "RX data array is too small")


    // --------------------------------------------------------
    // Step 2: Program DLR, ABR and CCR
    // --------------------------------------------------------

    qspi_write_reg("QSPI_DLR", byte_count - 1);

    if (use_abr)
        qspi_write_reg("QSPI_ABR", abr_data);

    // FMODE = 01: Indirect read
    ccr = ccr_cfg;
    ccr[27:26] = 2'b01;

    qspi_write_reg("QSPI_CCR", ccr);


    // --------------------------------------------------------
    // Step 3: Write AR to start read frame
    // --------------------------------------------------------

    if (ccr[11:10] != 2'b00)
        qspi_write_reg("QSPI_AR", flash_addr);


    // --------------------------------------------------------
    // Step 4: Read DR while RX FIFO contains data
    // --------------------------------------------------------

    qspi_get_reg_addr("QSPI_DR", addr);

    for (int i = 0; i < word_count; i++) begin

        // Wait for RX FIFO data.
        do begin
            qspi_read_reg("QSPI_SR", sr);

            if (sr[0])
                `uvm_error("QSPI", "RX transfer error")

        end while (sr[21:16] == 0);

        reg_read32(addr, rx_words[i], err_rsp);

        if (err_rsp)
            `uvm_error("QSPI", "QSPI_DR read error")

        `uvm_info("QSPI",
            $sformatf("RX[%0d] = 0x%08h", i, rx_words[i]),
            UVM_LOW)

    end


    // --------------------------------------------------------
    // Step 5: Wait for TCF and clear it
    // --------------------------------------------------------

    qspi_wait_complete();

    `uvm_info("QSPI",
        $sformatf("Indirect READ completed: ADDR=0x%08h BYTES=%0d",
                  flash_addr, byte_count),
        UVM_LOW)

endtask : qspi_indirect_read

`endif
