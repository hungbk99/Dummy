
typedef struct {
    string       name;
    bit [31:0]   addr;
    bit [31:0]   reset_value;
    bit [31:0]   reset_mask;
    bit [31:0]   write_mask;
} qspi_reg_info_t;


// ============================================================
// QSPI Register Information
// ============================================================

const qspi_reg_info_t QSPI_RW_REGS [0:16] = '{

    // --------------------------------------------------------
    // 0x000: QSPI_CR - Control Register
    // --------------------------------------------------------

    '{
        name:        "QSPI_CR",
        addr:        32'h0000_0000,
        reset_value: 32'h0000_0000,
        reset_mask:  32'hFFFF_1FFF,
        write_mask:  32'hFFFF_1FFC
    },

    // --------------------------------------------------------
    // 0x004: QSPI_DCR - Device Configuration Register (V2.0: CSHT removed)
    // --------------------------------------------------------

    '{
        name:        "QSPI_DCR",
        addr:        32'h0000_0004,
        reset_value: 32'h0000_0000,
        reset_mask:  32'h001F_0001,
        write_mask:  32'h001F_0001
    },

    // --------------------------------------------------------
    // 0x008: QSPI_SR - Status Register
    // --------------------------------------------------------

    '{
        name:        "QSPI_SR",
        addr:        32'h0000_0008,
        reset_value: 32'h0000_0000,
        reset_mask:  32'h003F_3F7F,
        write_mask:  32'h0000_0000
    },

    // --------------------------------------------------------
    // 0x00C: QSPI_FCR - Flag Clear Register
    // --------------------------------------------------------

    '{
        name:        "QSPI_FCR",
        addr:        32'h0000_000C,
        reset_value: 32'h0000_0000,
        reset_mask:  32'h0000_0000,
        write_mask:  32'h0000_0000
    },

    // --------------------------------------------------------
    // 0x010: QSPI_DLR - Data Length Register
    // --------------------------------------------------------

    '{
        name:        "QSPI_DLR",
        addr:        32'h0000_0010,
        reset_value: 32'h0000_0000,
        reset_mask:  32'hFFFF_FFFF,
        write_mask:  32'hFFFF_FFFF
    },

    // --------------------------------------------------------
    // 0x014: QSPI_CCR - Communication Configuration Register
    // --------------------------------------------------------

    '{
        name:        "QSPI_CCR",
        addr:        32'h0000_0014,
        reset_value: 32'h0000_0000,
        reset_mask:  32'h9F7F_FFFF,
        write_mask:  32'h9F7F_FFFF
    },

    // --------------------------------------------------------
    // 0x018: QSPI_AR - Address Register
    // --------------------------------------------------------

    '{
        name:        "QSPI_AR",
        addr:        32'h0000_0018,
        reset_value: 32'h0000_0000,
        reset_mask:  32'hFFFF_FFFF,
        write_mask:  32'hFFFF_FFFF
    },

    // --------------------------------------------------------
    // 0x01C: QSPI_ABR - Alternate Bytes Register
    // --------------------------------------------------------

    '{
        name:        "QSPI_ABR",
        addr:        32'h0000_001C,
        reset_value: 32'h0000_0000,
        reset_mask:  32'hFFFF_FFFF,
        write_mask:  32'hFFFF_FFFF
    },

    // --------------------------------------------------------
    // 0x020: QSPI_DR - Data Register
    // --------------------------------------------------------

    '{
        name:        "QSPI_DR",
        addr:        32'h0000_0020,
        reset_value: 32'h0000_0000,
        reset_mask:  32'h0000_0000,
        write_mask:  32'h0000_0000
    },

    // --------------------------------------------------------
    // 0x024: QSPI_PSMKR - Polling Status Mask Register
    // --------------------------------------------------------

    '{
        name:        "QSPI_PSMKR",
        addr:        32'h0000_0024,
        reset_value: 32'h0000_0000,
        reset_mask:  32'hFFFF_FFFF,
        write_mask:  32'hFFFF_FFFF
    },

    // --------------------------------------------------------
    // 0x028: QSPI_PSMAR - Polling Status Match Register
    // --------------------------------------------------------

    '{
        name:        "QSPI_PSMAR",
        addr:        32'h0000_0028,
        reset_value: 32'h0000_0000,
        reset_mask:  32'hFFFF_FFFF,
        write_mask:  32'hFFFF_FFFF
    },

    // --------------------------------------------------------
    // 0x02C: QSPI_PIR - Polling Interval Register
    // --------------------------------------------------------

    '{
        name:        "QSPI_PIR",
        addr:        32'h0000_002C,
        reset_value: 32'h0000_0000,
        reset_mask:  32'h0000_FFFF,
        write_mask:  32'h0000_FFFF
    },

    // --------------------------------------------------------
    // 0x030: QSPI_PTR - Polling Timeout Register
    // --------------------------------------------------------

    '{
        name:        "QSPI_PTR",
        addr:        32'h0000_0030,
        reset_value: 32'h0000_0000,
        reset_mask:  32'hFFFF_FFFF,
        write_mask:  32'hFFFF_FFFF
    },

    // --------------------------------------------------------
    // 0x034: QSPI_DMACR - DMA Control Register
    // --------------------------------------------------------

    '{
        name:        "QSPI_DMACR",
        addr:        32'h0000_0034,
        reset_value: 32'h0000_0000,
        reset_mask:  32'h0000_000F,
        write_mask:  32'h0000_000F
    },

    // --------------------------------------------------------
    // 0x038: QSPI_DMASR - DMA Status Register
    // --------------------------------------------------------

    '{
        name:        "QSPI_DMASR",
        addr:        32'h0000_0038,
        reset_value: 32'h0000_0000,
        reset_mask:  32'h0000_000C,
        write_mask:  32'h0000_0000
    },

    // --------------------------------------------------------
    // 0x03C: QSPI_DMAFCR - DMA Flag Clear Register
    // --------------------------------------------------------

    '{
        name:        "QSPI_DMAFCR",
        addr:        32'h0000_003C,
        reset_value: 32'h0000_0000,
        reset_mask:  32'h0000_0000,
        write_mask:  32'h0000_0000
    },

    // V2.0 DLY: CSS[7:0], CSH[15:8], CSIDLE[23:16]; bits [31:24] reserved.
    '{
        name:        "QSPI_DLY",
        addr:        32'h0000_0040,
        reset_value: 32'h0000_0000,
        reset_mask:  32'h00FF_FFFF,
        write_mask:  32'h00FF_FFFF
    }

};


//FIXME // ============================================================
//FIXME // Get register address by name
//FIXME // ============================================================
//FIXME
//FIXME function automatic bit qspi_get_reg_addr(
//FIXME     input  string     reg_name,
//FIXME     output bit [31:0] addr
//FIXME );
//FIXME
//FIXME     foreach (QSPI_RW_REGS[i]) begin
//FIXME
//FIXME         if (QSPI_RW_REGS[i].name == reg_name) begin
//FIXME             addr = QSPI_RW_REGS[i].addr;
//FIXME             return 1'b1;
//FIXME         end
//FIXME
//FIXME     end
//FIXME
//FIXME     addr = '0;
//FIXME     return 1'b0;
//FIXME
//FIXME endfunction


  
