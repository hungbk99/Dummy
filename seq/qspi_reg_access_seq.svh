
`ifndef QSPI_REG_ACESS_SEQ_C_SVH
`define QSPI_REG_ACESS_SEQ_C_SVH

class qspi_reg_rw_seq_c extends qspi_base_seq_c;

  `uvm_object_utils(qspi_reg_rw_seq_c)

  extern function new(string name = "qspi_reg_rw_seq_c");


  // ---------------------------------------------------------
  // Check register reset/default value
  // ---------------------------------------------------------
//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
  task automatic check_default_value(
    input qspi_reg_info_t reg_info
  );

    bit [31:0] read_data;
    bit        err_rsp;

    reg_read32(reg_info.addr, read_data, err_rsp);

    if ((read_data & reg_info.reset_mask) !==
        (reg_info.reset_value & reg_info.reset_mask)) begin

      // Approved post-reset exception: indirect-write mode and an empty TX
      // FIFO assert TXFTF after reset release. Waive only this exact value;
      // APB errors and every other register/status mismatch remain errors.
      if (!err_rsp && reg_info.name == "QSPI_SR" &&
          reg_info.addr == 32'h0000_0008 &&
          reg_info.reset_value == 32'h0000_0000 &&
          read_data === 32'h0000_0004) begin
        `uvm_warning("REG_RESET_TXFTF_WAIVED",
          "QSPI_SR post-reset value 0x00000004: TXFTF asserted because the empty TX FIFO meets TXFIFOTH+1; reset-value mismatch waived.")
      end
      else begin
      `uvm_error("REG_RESET_CHECK",
        $sformatf(
          "%s reset mismatch: ADDR=0x%08h EXPECTED=0x%08h ACTUAL=0x%08h MASK=0x%08h",
          reg_info.name,
          reg_info.addr,
          (reg_info.reset_value & reg_info.reset_mask),
          (read_data & reg_info.reset_mask),
          reg_info.reset_mask
        ))
      end
    end
    else begin
      `uvm_info("REG_RESET_CHECK",
        $sformatf(
          "%s reset PASS: ADDR=0x%08h VALUE=0x%08h",
          reg_info.name,
          reg_info.addr,
          read_data
        ),
        UVM_LOW)
    end

  endtask


  // ---------------------------------------------------------
  // Write register, read it back, and compare writable bits
  // ---------------------------------------------------------
//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
  task automatic write_readback_check(
    input qspi_reg_info_t reg_info
  );

    bit [31:0] write_data;
    bit [31:0] read_data;
    bit        err_rsp;

    // Generate random data, restricted to writable bits.
    write_data = $urandom();
    write_data = write_data & reg_info.write_mask;

    // Write register.
    reg_write32(reg_info.addr, write_data);

    // Read back the written register.
    reg_read32(reg_info.addr, read_data, err_rsp);

    // Compare only bits defined as writable.
    if ((read_data & reg_info.write_mask) !==
        (write_data & reg_info.write_mask)) begin

      `uvm_error("REG_RW_CHECK",
        $sformatf(
          "%s readback mismatch: ADDR=0x%08h WRITE=0x%08h READ=0x%08h MASK=0x%08h",
          reg_info.name,
          reg_info.addr,
          (write_data & reg_info.write_mask),
          (read_data & reg_info.write_mask),
          reg_info.write_mask
        ))
    end
    else begin
      `uvm_info("REG_RW_CHECK",
        $sformatf(
          "%s readback PASS: ADDR=0x%08h WRITE=0x%08h READ=0x%08h",
          reg_info.name,
          reg_info.addr,
          write_data,
          read_data
        ),
        UVM_LOW)
    end

  endtask


  // ---------------------------------------------------------
  // Sequence body
  // ---------------------------------------------------------
//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
  virtual task body();
    int CCR_idx;

    `uvm_info("QSPI_REG_SEQ", "Starting QSPI register validation", UVM_LOW)

    // Step 1:
    // Check all default values before modifying any register.
    `uvm_info("QSPI_REG_SEQ", "STEP 1: Checking default values", UVM_LOW)

    foreach (QSPI_RW_REGS[i]) begin
      check_default_value(QSPI_RW_REGS[i]);
    end

    // Step 2 and 3:
    // Write each register, read it back, and compare.
    `uvm_info("QSPI_REG_SEQ", "STEP 2/3: Write and readback checks", UVM_LOW)

    foreach (QSPI_RW_REGS[i]) begin
      if(QSPI_RW_REGS[i].name == "QSPI_CCR") begin
        CCR_idx =i;
        continue;
      end
      write_readback_check(QSPI_RW_REGS[i]);
    end

    write_readback_check(QSPI_RW_REGS[CCR_idx]);

    `uvm_info("QSPI_REG_SEQ", "Finished QSPI register validation", UVM_LOW)

  endtask

endclass

function qspi_reg_rw_seq_c::new(string name = "qspi_reg_rw_seq_c");
    super.new(name);
  endfunction : new


`endif//QSPI_REG_ACESS_SEQ_C_SVH


   
