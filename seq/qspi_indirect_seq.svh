`ifndef QSPI_INDIRECT_SEQ_C_SVH
`define QSPI_INDIRECT_SEQ_C_SVH

class qspi_indirect_seq_c extends qspi_transfer_base_seq_c;
  `uvm_object_utils(qspi_indirect_seq_c)

  // ==========================================================
  // Randomized CCR fields
  // ==========================================================

  rand bit        ddrm;
  rand bit        sioo;

  rand bit [1:0]  fmode;
  rand bit [1:0]  dmode;
  rand bit [4:0]  dcyc;

  rand bit [1:0]  absize;
  rand bit [1:0]  abmode;

  rand bit [1:0]  adsize;
  rand bit [1:0]  admode;

  rand bit [1:0]  imode;

  rand bit [7:0]  instruction;

  // ==========================================================
  // Constraints
  // ==========================================================

  constraint ccr_mode_c {

    // Avoid automatically starting polling or memory-mapped
    // operations during a simple register configuration test.
    fmode inside {2'b00, 2'b01};

    // SIOO has no effect when instruction mode is disabled.
    if (imode == 2'b00)
      sioo == 1'b0;

  }

  extern function new(string name = "qspi_indirect_seq_c");


  extern virtual function bit [31:0] pack_ccr();
  extern virtual task qspi_init();
  extern virtual task configure_frame_format();


//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
  virtual task body();
    bit [31:0] tx_data[];
    bit [31:0] rx_data[];
    bit [31:0] write_ccr;
    bit [31:0] read_ccr;
    bit [7:0]  write_opcode;
    bit [7:0]  read_opcode;
    bit [31:0] flash_addr;
    bit [7:0]  vcr_value;
    bit [4:0]  flash_dummy_cycles;
    string     mode_name;
    int        compared_words = 0;
    int        mismatch_count = 0;

`ifdef VERILATOR
    // Keep the smoke test deterministic when no external constraint solver is installed.
    ddrm = 1'b0;
    sioo = 1'b0;
    fmode = 2'b00;
    dmode = 2'b01;
    dcyc = 5'd0;
    absize = 2'b00;
    abmode = 2'b00;
    adsize = 2'b10;
    admode = 2'b11;
    imode = 2'b01;
    instruction = 8'h03;
`else
    this.randomize();
`endif
    qspi_init();

`ifdef QSPI_MICRON_MODEL
    // Configure the real flash and the controller consistently: four dummy clocks.
    qspi_flash_write_config(8'h81, 8'h4b);
`endif

    // Read the flash's Volatile Configuration Register. The N25Q model uses
    // VCR[7:4] for fast-read dummy cycles; 0 and F select its default of 8.
    qspi_flash_read_vcr(vcr_value);
    if ((vcr_value[7:4] == 4'h0) || (vcr_value[7:4] == 4'hF))
      flash_dummy_cycles = 5'd8;
    else
      flash_dummy_cycles = {1'b0, vcr_value[7:4]};

`ifdef QSPI_MICRON_MODEL
    if (vcr_value[7:4] != 4'd4)
      `uvm_fatal("QSPI_FLASH_CFG", $sformatf("Expected VCR dummy cycles=4, read VCR=0x%02h", vcr_value))
`endif

    `uvm_info("QSPI_FLASH_CFG",
      $sformatf("N25Q VCR=0x%02h; model fast-read dummy cycles=%0d (dual/quad CCR will use this value)",
                vcr_value, flash_dummy_cycles), UVM_LOW)

    tx_data = new[4];
    tx_data[0] = 32'h03020100;
    tx_data[1] = 32'h07060504;
    tx_data[2] = 32'h0B0A0908;
    tx_data[3] = 32'h0F0E0D0C;

    rx_data = new[4];

    // Exercise matching write/read opcodes with single-, dual-, and
    // quad-lane data phases. Each mode uses its own flash address.
    for (int mode = 0; mode < 3; mode++) begin
      case (mode)
        0: begin
          mode_name = "single";
          flash_addr = 32'h0000_1000;
          write_opcode = 8'h02; // Page Program
          read_opcode = 8'h03;  // Read
          write_ccr = 32'h0100_2502;
          read_ccr = 32'h0100_2503;
        end
        1: begin
          mode_name = "dual";
          flash_addr = 32'h0000_1020;
          write_opcode = 8'hA2; // Dual Program
          read_opcode = 8'h3B;  // Dual Output Fast Read
          write_ccr = 32'h0200_25A2;
          read_ccr = 32'h0200_253B; // DMODE=dual, DCYC filled from VCR below
          read_ccr[22:18] = flash_dummy_cycles;
        end
        default: begin
          mode_name = "quad";
          flash_addr = 32'h0000_1040;
          write_opcode = 8'h32; // Quad Program
          read_opcode = 8'h6B;  // Quad Output Fast Read
          write_ccr = 32'h0300_2532;
          read_ccr = 32'h0300_256B; // DMODE=quad, DCYC filled from VCR below
          read_ccr[22:18] = flash_dummy_cycles;
`ifdef QSPI_MICRON_MODEL
          // N25Q256A13E vendor model fixes 6Bh at eight dummy clocks.
          // Its EBh quad-I/O path is tested with the programmable four below.
          read_ccr[22:18] = 5'd8;
`endif
        end
      endcase

      `uvm_info("QSPI_MODE_TEST",
        $sformatf("Starting %s-lane write/read at 0x%08h (write opcode=0x%02h, read opcode=0x%02h, read CCR=0x%08h, DCYC=%0d)",
                  mode_name, flash_addr, write_opcode, read_opcode,
                  read_ccr, read_ccr[22:18]), UVM_LOW)

      // Page-program operations require WREN. This is instruction-only.
      qspi_wait_idle();
      qspi_write_reg("QSPI_CCR", 32'h0000_0106);
      qspi_wait_complete();

      qspi_indirect_write(
          flash_addr,
          32'd16,
          write_ccr,
          1'b0,
          32'h0000_0000,
          tx_data
      );

      // Controller TCF means the serial frame ended. The flash can still be
      // internally busy programming the page, so poll WIP in status register.
      qspi_flash_wait_ready();

      // For dual/quad cases, first read the programmed address with the known
      // working single-lane read command. This separates a write-side failure
      // from a multi-lane read-side failure.
      if (mode != 0) begin
        qspi_indirect_read(
            flash_addr,
            32'd16,
            32'h0100_2503, // Single-lane 03h read, 24-bit address
            1'b0,
            32'h0000_0000,
            rx_data
        );

        foreach (tx_data[i]) begin
          compared_words++;
          if (rx_data[i] !== tx_data[i]) begin
            mismatch_count++;
            `uvm_error("QSPI_WRITE_COMPARE",
              $sformatf("%s write read by single-lane 03h at word %0d: expected=0x%08h actual=0x%08h",
                        mode_name, i, tx_data[i], rx_data[i]))
          end
        end
      end

      qspi_indirect_read(
          flash_addr,
          32'd16,
          read_ccr,
          1'b0,
          32'h0000_0000,
          rx_data
      );

      foreach (tx_data[i]) begin
        compared_words++;
        if (rx_data[i] !== tx_data[i]) begin
          mismatch_count++;
          `uvm_error("QSPI_DATA_COMPARE",
            $sformatf("%s readback mismatch at word %0d: expected=0x%08h actual=0x%08h",
                      mode_name, i, tx_data[i], rx_data[i]))
        end
      end
`ifdef QSPI_MICRON_MODEL
      if (mode == 2) begin
        read_ccr = 32'h0310_2DEB; // EBh: quad address/data, 24-bit address, DCYC=4.
        `uvm_info("QSPI_MODE_TEST",
          "Starting EBh quad-I/O readback with four dummy clocks", UVM_LOW)
        qspi_indirect_read(flash_addr, 32'd16, read_ccr,
                           1'b0, 32'd0, rx_data);
        foreach (tx_data[i]) begin
          compared_words++;
          if (rx_data[i] !== tx_data[i]) begin
            mismatch_count++;
            `uvm_error("QSPI_DATA_COMPARE",
              $sformatf("EBh quad read (DCYC=4) word %0d: expected=0x%08h actual=0x%08h",
                        i, tx_data[i], rx_data[i]))
          end
        end
      end
`endif
    end
    `uvm_info("QSPI_COMPARE_SUMMARY",
      $sformatf("Compared %0d words across single/dual/quad reads and single-lane cross-checks; mismatches=%0d",
                compared_words, mismatch_count), UVM_LOW)
  endtask: body

endclass: qspi_indirect_seq_c

function qspi_indirect_seq_c::new(string name = "qspi_indirect_seq_c");
    super.new(name);
  endfunction : new


function bit [31:0] qspi_indirect_seq_c::pack_ccr();

  return {
    ddrm,           // [31]
    2'b00,          // [30:29] Reserved
    sioo,           // [28]
    fmode,          // [27:26]
    dmode,          // [25:24]
    1'b0,           // [23] Reserved
    dcyc,           // [22:18]
    absize,         // [17:16]
    abmode,         // [15:14]
    adsize,         // [13:12]
    admode,         // [11:10]
    imode,          // [9:8]
    instruction     // [7:0]
  };

endfunction

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_indirect_seq_c::qspi_init();

  bit [31:0] addr;
  bit [31:0] tmp_data;
  bit        err_rsp;
  bit        busy;

  // Debug register values
  bit [31:0] dcr_data;
  bit [31:0] cr_data;
  bit [31:0] dmacr_data;
  bit [31:0] sr_data;

  // Randomized configuration
  bit [7:0] cfg_csidle;
  bit       cfg_ckmode;
  bit [7:0] cfg_prescaler;
  bit [4:0] cfg_txfifoth;
  bit [4:0] cfg_rxfifoth;


  // =========================================================
  // STEP 0: Randomize configuration
  // =========================================================

`ifdef VERILATOR
  cfg_csidle = 8'd1;
  cfg_ckmode = 1'b0;
  cfg_prescaler = 8'd2;
  cfg_txfifoth = 5'd4;
  cfg_rxfifoth = 5'd4;
`else
  if (!std::randomize(cfg_csidle, cfg_ckmode,
                      cfg_prescaler, cfg_txfifoth,
                      cfg_rxfifoth) with {
    cfg_csidle      inside {[0:255]};
    cfg_prescaler inside {[0:254]};
    if (ddrm == 1'b0)
      cfg_prescaler[0] == 1'b0;
    else
      cfg_prescaler[1:0] == 2'b10;
    cfg_txfifoth  inside {[0:31]};
    cfg_rxfifoth  inside {[0:31]};
  }) begin
    `uvm_error("QSPI_INIT", "Configuration randomization failed")
  end
`endif


  // =========================================================
  // STEP 1: Wait until SR.BUSY = 0
  // =========================================================

  qspi_get_reg_addr("QSPI_SR", addr);

  busy = 1'b1;

  for (int i = 0; i < 1000; i++) begin

    reg_read32(addr, tmp_data, err_rsp);

    if (err_rsp)
      `uvm_error("QSPI_INIT", "QSPI_SR read error")

    if (tmp_data[6] == 1'b0) begin
      busy = 1'b0;
      break;
    end

  end

  if (busy)
    `uvm_error("QSPI_INIT", "QSPI BUSY timeout")


  // =========================================================
  // STEP 2: Configure DCR and CR
  // =========================================================

  // V2 DCR: FSIZE, CKMODE; CS idle timing is in DLY.
  qspi_get_reg_addr("QSPI_DCR", addr);
  reg_read32(addr, tmp_data, err_rsp);

  if (err_rsp)
    `uvm_error("QSPI_INIT", "QSPI_DCR read error")

  tmp_data[20:16] = 5'd20;
  tmp_data[10:8]  = 3'd0; // Reserved in V2.0
  tmp_data[0]     = cfg_ckmode;

  reg_write32(addr, tmp_data);


  // V2 DLY: CSIDLE[23:16], CSH[15:8], CSS[7:0].
  qspi_write_reg("QSPI_DLY", {8'd0, cfg_csidle, 8'd0, 8'd0});

  // CR: PRESCALER, TXFIFOTH, RXFIFOTH
  qspi_get_reg_addr("QSPI_CR", addr);
  reg_read32(addr, tmp_data, err_rsp);

  if (err_rsp)
    `uvm_error("QSPI_INIT", "QSPI_CR read error")

  tmp_data[0]     = 1'b0;
  tmp_data[31:24] = cfg_prescaler;
  tmp_data[12:8]  = cfg_txfifoth;
  tmp_data[7:3]   = cfg_rxfifoth;

  reg_write32(addr, tmp_data);


  // =========================================================
  // STEP 3: Clear stale flags
  // =========================================================

  qspi_get_reg_addr("QSPI_FCR", addr);
  reg_write32(addr, 32'h0000_003F);

  qspi_get_reg_addr("QSPI_DMAFCR", addr);
  reg_write32(addr, 32'h0000_000C);


  // =========================================================
  // STEP 4: Configure interrupt enables
  // =========================================================

  // CR interrupt enables
  qspi_get_reg_addr("QSPI_CR", addr);
  reg_read32(addr, tmp_data, err_rsp);

  if (err_rsp)
    `uvm_error("QSPI_INIT", "QSPI_CR read error")

  tmp_data[21:16] = 6'b000011;

  reg_write32(addr, tmp_data);


  // DMACR interrupt enables
  qspi_get_reg_addr("QSPI_DMACR", addr);
  reg_read32(addr, tmp_data, err_rsp);

  if (err_rsp)
    `uvm_error("QSPI_INIT", "QSPI_DMACR read error")

  // TXDMAEN=0, RXDMAEN=0
  // TXOVRIE=1, RXUDRIE=1
  tmp_data[3:0] = 4'b1100;

  reg_write32(addr, tmp_data);


  // =========================================================
  // STEP 5: Enable QSPI
  // =========================================================

  qspi_get_reg_addr("QSPI_CR", addr);
  reg_read32(addr, tmp_data, err_rsp);

  if (err_rsp)
    `uvm_error("QSPI_INIT", "QSPI_CR read error")

  tmp_data[0] = 1'b1;

  reg_write32(addr, tmp_data);


  // =========================================================
  // STEP 6: Read back and print actual configuration
  // =========================================================

  `uvm_info("QSPI_INIT",
    "==================================================",
    UVM_LOW)

  `uvm_info("QSPI_INIT",
    "          QSPI INITIALIZATION SUMMARY",
    UVM_LOW)


  // ---------------------------------------------------------
  // DCR configuration
  // ---------------------------------------------------------

  qspi_get_reg_addr("QSPI_DCR", addr);
  reg_read32(addr, dcr_data, err_rsp);

  if (err_rsp)
    `uvm_error("QSPI_INIT", "DCR debug read error")

  `uvm_info("QSPI_INIT",
    $sformatf(
      {"DCR     = 0x%08h\n",
       "          FSIZE=%0d CKMODE=%0b"},
      dcr_data,
      dcr_data[20:16],
      dcr_data[0]),
    UVM_LOW)


  // ---------------------------------------------------------
  // CR configuration
  // ---------------------------------------------------------

  qspi_get_reg_addr("QSPI_CR", addr);
  reg_read32(addr, cr_data, err_rsp);

  if (err_rsp)
    `uvm_error("QSPI_INIT", "CR debug read error")

  `uvm_info("QSPI_INIT",
    $sformatf(
      {"CR      = 0x%08h\n",
       "          EN=%0b PRESCALER=%0d DIVIDER=%0d\n",
       "          TXFIFOTH=%0d RXFIFOTH=%0d"},
      cr_data,
      cr_data[0],
      cr_data[31:24],
      cr_data[31:24] + 2,
      cr_data[12:8],
      cr_data[7:3]),
    UVM_LOW)

  `uvm_info("QSPI_INIT",
    $sformatf(
      {"CR IRQ  | TEIE=%0b TCIE=%0b TXFTIE=%0b ",
       "RXFTIE=%0b SMIE=%0b STOIE=%0b"},
      cr_data[16],
      cr_data[17],
      cr_data[18],
      cr_data[19],
      cr_data[20],
      cr_data[21]),
    UVM_LOW)


  // ---------------------------------------------------------
  // DMACR configuration
  // ---------------------------------------------------------

  qspi_get_reg_addr("QSPI_DMACR", addr);
  reg_read32(addr, dmacr_data, err_rsp);

  if (err_rsp)
    `uvm_error("QSPI_INIT", "DMACR debug read error")

  `uvm_info("QSPI_INIT",
    $sformatf(
      {"DMACR   = 0x%08h\n",
       "          TXDMAEN=%0b RXDMAEN=%0b\n",
       "          TXOVRIE=%0b RXUDRIE=%0b"},
      dmacr_data,
      dmacr_data[0],
      dmacr_data[1],
      dmacr_data[2],
      dmacr_data[3]),
    UVM_LOW)


  // ---------------------------------------------------------
  // SR status
  // ---------------------------------------------------------

  qspi_get_reg_addr("QSPI_SR", addr);
  reg_read32(addr, sr_data, err_rsp);

  if (err_rsp)
    `uvm_error("QSPI_INIT", "SR debug read error")

  `uvm_info("QSPI_INIT",
    $sformatf(
      {"SR      = 0x%08h\n",
       "          BUSY=%0b TCF=%0b TEF=%0b\n",
       "          TXFLEVEL=%0d RXFLEVEL=%0d"},
      sr_data,
      sr_data[6],
      sr_data[1],
      sr_data[0],
      sr_data[13:8],
      sr_data[21:16]),
    UVM_LOW)


  `uvm_info("QSPI_INIT",
    "==================================================",
    UVM_LOW)

  `uvm_info("QSPI_INIT",
    "QSPI initialization completed",
    UVM_LOW)

endtask

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
task qspi_indirect_seq_c::configure_frame_format();
  bit [31:0] addr;
  bit [31:0] tmp_data;
  bit        err_rsp;

  this.randomize();

  //Communication configuration register
  qspi_get_reg_addr("QSPI_CCR", addr);
  reg_read32(addr, tmp_data, err_rsp);
  tmp_data=pack_ccr();
  reg_write32(addr, tmp_data);

endtask: configure_frame_format

`endif
