`timescale 1ns/1ps

`include "uvm_macros.svh"

import uvm_pkg::*;
import ahb_package::*;
import apb_master_pkg::*;
import qspi_env_pkg::*;
import qspi_seq_pkg::*;
import qspi_test_pkg::*;

module top #(parameter int AHB_TIMEOUT_CYCLES=1048576) ();

`ifdef VERILATOR
  initial begin
    $dumpfile("test.fst");
    $dumpvars(0, top);
  end
`endif

  // ----------------------------------------------------------
  // DUT parameters
  // ----------------------------------------------------------

  localparam int PARA_APB_ADDR_WIDTH      = 16;
  localparam int PARA_APB_DATA_WIDTH      = 32;
  localparam int PARA_AHB_ADDR_WIDTH      = 32;
  localparam int PARA_AHB_DATA_WIDTH      = 32;
  localparam int PARA_SLAVE_NUM           = 1;
  localparam int PARA_APB_SYNC_FIFO_DEPTH = 4;
  localparam int PARA_AHB_SYNC_FIFO_DEPTH = 8;
  localparam int PARA_QSPI_CMD_FIFO_DEPTH = 4;
  localparam int PARA_QSPI_TX_FIFO_DEPTH  = 32;
  localparam int PARA_QSPI_RX_FIFO_DEPTH  = 32;
  localparam int PARA_BUS_CLK_TIMEOUT     = 5000;

  // ----------------------------------------------------------
  // Clock and reset
  // ----------------------------------------------------------

  logic i_qspi_clk;
  logic i_qspi_rst_n;

  logic i_qspi_pclk;

  logic            i_qspi_preset_n;        // To u_qspi_top of m_qspi_top.v

  logic            i_qspi_hclk;            // To u_qspi_top of m_qspi_top.v
  logic            i_qspi_hreset_n;        // To u_qspi_top of m_qspi_top.v


  localparam int QSPI_RST_MIN_CYCLES = 2;
  localparam int QSPI_RST_MAX_CYCLES = 10;

  // ---------------------------------------------------------------------------------------
  // APB interface (PCLK / PRESETn)
  // ---------------------------------------------------------------------------------------
  /*AUTOINPUT("^i_qspi_p\(clk\|reset_n\)$")*/
  // Beginning of automatic inputs (from unused autoinst inputs)
  // End of automatics
  /*AUTOINPUT("^i_qspi_apb_")*/
  // Beginning of automatic inputs (from unused autoinst inputs)
  wire [PARA_APB_ADDR_WIDTH-1:0] i_qspi_apb_paddr;// To u_qspi_top of m_qspi_top.v
  wire            i_qspi_apb_penable;     // To u_qspi_top of m_qspi_top.v
  wire            i_qspi_apb_psel;        // To u_qspi_top of m_qspi_top.v
  wire [PARA_APB_DATA_WIDTH-1:0] i_qspi_apb_pwdata;// To u_qspi_top of m_qspi_top.v
  wire            i_qspi_apb_pwrite;      // To u_qspi_top of m_qspi_top.v
  // End of automatics
  /*AUTOOUTPUT("^o_qspi_apb_")*/
  // Beginning of automatic outputs (from unused autoinst outputs)
  wire [PARA_APB_DATA_WIDTH-1:0] o_qspi_apb_prdata;// From u_qspi_top of m_qspi_top.v
  wire          o_qspi_apb_pready;      // From u_qspi_top of m_qspi_top.v
  wire          o_qspi_apb_pslverr;     // From u_qspi_top of m_qspi_top.v
  // End of automatics

  // ---------------------------------------------------------------------------------------
  // AHB-Lite interface (HCLK / HRESETn)
  // ---------------------------------------------------------------------------------------
  /*AUTOINPUT("^i_qspi_h\(clk\|reset_n\)$")*/
  // Beginning of automatic inputs (from unused autoinst inputs)
  // End of automatics
  /*AUTOINPUT("^i_qspi_ahb_")*/
  // Beginning of automatic inputs (from unused autoinst inputs)
  wire [PARA_AHB_ADDR_WIDTH-1:0] i_qspi_ahb_haddr;// To u_qspi_top of m_qspi_top.v
  wire            i_qspi_ahb_hsel;        // To u_qspi_top of m_qspi_top.v
  wire [1:0]      i_qspi_ahb_htrans;      // To u_qspi_top of m_qspi_top.v
  wire [PARA_AHB_DATA_WIDTH-1:0] i_qspi_ahb_hwdata;// To u_qspi_top of m_qspi_top.v
  wire            i_qspi_ahb_hwrite;      // To u_qspi_top of m_qspi_top.v
  // End of automatics
  /*AUTOOUTPUT("^o_qspi_ahb_")*/
  // Beginning of automatic outputs (from unused autoinst outputs)
  wire [PARA_AHB_DATA_WIDTH-1:0] o_qspi_ahb_hrdata;// From u_qspi_top of m_qspi_top.v
  wire          o_qspi_ahb_hreadyout;   // From u_qspi_top of m_qspi_top.v
  wire          o_qspi_ahb_hresp;       // From u_qspi_top of m_qspi_top.v

  // ---------------------------------------------------------------------------------------
  // Interrupt interface (INT -> GIC)
  // ---------------------------------------------------------------------------------------
  /*AUTOOUTPUT("^o_qspi_int_")*/
  // Beginning of automatic outputs (from unused autoinst outputs)
  logic          o_qspi_int_irq;         // From u_qspi_top of m_qspi_top.v
  // End of automatics

  // ---------------------------------------------------------------------------------------
  // DMA interface (DMA_CLK / DMA_RST_N)
  // ---------------------------------------------------------------------------------------
  /*AUTOINPUT("^i_qspi_dma_")*/
  // Beginning of automatic inputs (from unused autoinst inputs)
  logic            i_qspi_dma_clk;         // To u_qspi_top of m_qspi_top.v
  logic            i_qspi_dma_rst_n;       // To u_qspi_top of m_qspi_top.v
  wire            i_qspi_dma_rx_clr;      // To u_qspi_top of m_qspi_top.v
  wire            i_qspi_dma_tx_clr;      // To u_qspi_top of m_qspi_top.v
  // End of automatics
  /*AUTOOUTPUT("^o_qspi_dma_")*/
  // Beginning of automatic outputs (from unused autoinst outputs)
  wire          o_qspi_dma_rx_req;      // From u_qspi_top of m_qspi_top.v
  wire          o_qspi_dma_tx_req;      // From u_qspi_top of m_qspi_top.v
  // End of automatics

  // ---------------------------------------------------------------------------------------
  // QSPI I/O interface (PAD -> IO PAD selection)
  // ---------------------------------------------------------------------------------------
  /*AUTOOUTPUT("^o_qspi_pad_")*/
  // Beginning of automatic outputs (from unused autoinst outputs)
  logic          o_qspi_pad_cs_n;        // From u_qspi_top of m_qspi_top.v
  logic [3:0]    o_qspi_pad_io;          // From u_qspi_top of m_qspi_top.v
  logic [3:0]    o_qspi_pad_io_oe;       // From u_qspi_top of m_qspi_top.v
  logic          o_qspi_pad_sclk;        // From u_qspi_top of m_qspi_top.v
  // End of automatics
  /*AUTOINPUT("^i_qspi_pad_")*/
  // Beginning of automatic inputs (from unused autoinst inputs)
  tri  [3:0]      i_qspi_pad_io;          // Resolved flash-to-DUT QSPI data bus
  // End of automatics


  // ----------------------------------------------------------
  // Default weak drive values
  //
  // Weak assignments allow stronger testbench/interface drivers
  // to override these idle values.
  // ----------------------------------------------------------

  assign (weak0, weak1) i_qspi_apb_paddr  = '0;
  assign (weak0, weak1) i_qspi_apb_psel   = '0;
  assign (weak0, weak1) i_qspi_apb_penable = '0;
  assign (weak0, weak1) i_qspi_apb_pwrite = '0;
  assign (weak0, weak1) i_qspi_apb_pwdata = '0;

  assign (weak0, weak1) i_qspi_ahb_haddr  = '0;
  assign (weak0, weak1) i_qspi_ahb_htrans = '0;
  assign (weak0, weak1) i_qspi_ahb_hwdata = '0;
  assign (weak0, weak1) i_qspi_ahb_hwrite = '0;
  assign (weak0, weak1) i_qspi_ahb_hsel   = '0;

  assign (weak0, weak1) i_qspi_dma_rx_clr = '0;
  assign (weak0, weak1) i_qspi_dma_tx_clr = '0;

  // ----------------------------------------------------------
  // Connection include
  // ----------------------------------------------------------

  `include "qspi_connect.svh"

  // ============================================================
  // Clock generation
  // ============================================================

  // QSPI core clock: 5 MHz
  initial begin
      i_qspi_clk = 1'b0;
      forever #100 i_qspi_clk = ~i_qspi_clk;
  end

  // APB clock: 100 MHz
  initial begin
      i_qspi_pclk = 1'b0;
      forever #5 i_qspi_pclk = ~i_qspi_pclk;
  end

  // AHB clock: 100 MHz
  initial begin
      i_qspi_hclk = 1'b0;
      forever #5 i_qspi_hclk = ~i_qspi_hclk;
  end

  // DMA clock: 100 MHz
  initial begin
      i_qspi_dma_clk = 1'b0;
      forever #5 i_qspi_dma_clk = ~i_qspi_dma_clk;
  end

  // ============================================================
  // Reset generation
  // ============================================================

  initial begin
      i_qspi_rst_n     = 1'b0;
      i_qspi_preset_n  = 1'b0;
      i_qspi_hreset_n  = 1'b0;
      i_qspi_dma_rst_n = 1'b0;

      // Hold all resets active for 1 us.
      #1000;

      fork
          begin
              @(negedge i_qspi_clk);
              i_qspi_rst_n = 1'b1;
          end

          begin
              @(negedge i_qspi_pclk);
              i_qspi_preset_n = 1'b1;
          end

          begin
              @(negedge i_qspi_hclk);
              i_qspi_hreset_n = 1'b1;
          end

          begin
              @(negedge i_qspi_dma_clk);
              i_qspi_dma_rst_n = 1'b1;
          end
      join
  end

  // ----------------------------------------------------------
  // DUT instance
  // ----------------------------------------------------------

`ifdef QSPI_TESTPLAN
  m_qspi_wrap #(.PARA_BUS_CLK_TIMEOUT(AHB_TIMEOUT_CYCLES)) dut (
`else
  m_qspi_wrap dut (
`endif
    // Keep the bidirectional flash input explicit; the remaining matching
    // ports use the wildcard connection below.
    .i_qspi_pad_io (i_qspi_pad_io),
    .*
  );

`ifdef QSPI_TESTPLAN
  qspi_test_if test_if(
    .qclk(i_qspi_clk),.pclk(i_qspi_pclk),.hclk(i_qspi_hclk),.dclk(i_qspi_dma_clk),
    .qresetn(i_qspi_rst_n),.presetn(i_qspi_preset_n),.hresetn(i_qspi_hreset_n),.dresetn(i_qspi_dma_rst_n),
    .irq(o_qspi_int_irq),.csn(o_qspi_pad_cs_n),.sclk(o_qspi_pad_sclk),
    .hrdata(o_qspi_ahb_hrdata),.hready(o_qspi_ahb_hreadyout),.hresp(o_qspi_ahb_hresp),
    .dma_tx_req(o_qspi_dma_tx_req),.dma_rx_req(o_qspi_dma_rx_req),
    .psel(i_qspi_apb_psel),.penable(i_qspi_apb_penable),.pready(o_qspi_apb_pready),
    .pwrite(i_qspi_apb_pwrite),.paddr(i_qspi_apb_paddr),.pwdata(i_qspi_apb_pwdata));
  assign i_qspi_ahb_haddr=test_if.haddr;
  assign i_qspi_ahb_hsel=test_if.hsel;
  assign i_qspi_ahb_htrans=test_if.htrans;
  assign i_qspi_ahb_hwrite=test_if.hwrite;
  assign i_qspi_ahb_hwdata=test_if.hwdata;
  assign i_qspi_dma_tx_clr=test_if.dma_tx_clr;
  assign i_qspi_dma_rx_clr=test_if.dma_rx_clr;
  initial uvm_config_db#(virtual qspi_test_if)::set(null,"*","qspi_test_vif",test_if);
  initial begin
    int limit_us;
    if(!$value$plusargs("QSPI_WATCHDOG_US=%d",limit_us)) limit_us=500000;
    #(limit_us*1us);
    $fatal(1,"QSPI testplan global watchdog expired");
  end
`endif

  // ----------------------------------------------------------
  // Start UVM
  // ----------------------------------------------------------

  initial begin
    run_test();
  end

endmodule : top

