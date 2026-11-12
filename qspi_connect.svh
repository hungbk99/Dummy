apb_sys_if_t apb_sys_if(.PCLK(i_qspi_pclk), .PRESETn(i_qspi_preset_n));

assign i_qspi_apb_paddr  = apb_sys_if.mst_in_paddr   ;
assign i_qspi_apb_pwrite = apb_sys_if.mst_in_pwrite  ;
assign i_qspi_apb_pwdata = apb_sys_if.mst_in_pwdata  ;
assign i_qspi_apb_psel   = apb_sys_if.mst_in_psel    ;
assign i_qspi_apb_penable= apb_sys_if.mst_in_penable ;

assign apb_sys_if.mst_out_prdata = o_qspi_apb_prdata;
assign apb_sys_if.mst_out_pready = o_qspi_apb_pready;
assign apb_sys_if.mst_out_pslverr= o_qspi_apb_pslverr;

initial begin
  uvm_config_db#(virtual apb_if)::set(null, "uvm_test_top.m_env.apb_env.master_agent.*", "apb_vif", apb_sys_if.master_if);
  uvm_config_db#(virtual apb_sys_if_t)::set(null, "uvm_test_top.m_env.apb_env", "apb_sys_vif", apb_sys_if);
end


ahb_if ahb_vif(.hclk(i_qspi_hclk), .hresetn(i_qspi_hreset_n));

// A single AHB master owns the memory-mapped DUT port.
assign i_qspi_ahb_haddr = ahb_vif.haddr;
assign i_qspi_ahb_htrans = ahb_vif.htrans;
assign i_qspi_ahb_hwrite = ahb_vif.hwrite;
assign i_qspi_ahb_hwdata = ahb_vif.hwdata;
assign i_qspi_ahb_hsel = ahb_vif.htrans[1];
assign ahb_vif.hselx = {{(`AHB_VIP_NO_OF_SLAVES-1){1'b0}}, i_qspi_ahb_hsel};
assign ahb_vif.hrdata = o_qspi_ahb_hrdata;
assign ahb_vif.hready = o_qspi_ahb_hreadyout;
assign ahb_vif.hreadyout = o_qspi_ahb_hreadyout;
assign ahb_vif.hresp = o_qspi_ahb_hresp;
assign ahb_vif.hexokay = 1'b0;
initial uvm_config_db#(virtual ahb_if)::set(
  null, "uvm_test_top.m_env", "ahb_vif", ahb_vif);

// Dedicated passive serial monitor, separate from bus, IRQ, and DMA interfaces.
qspi_monitor_if serial_monitor(.resetn(i_qspi_rst_n),
  .csn(o_qspi_pad_cs_n), .sclk(o_qspi_pad_sclk));
initial uvm_config_db#(virtual qspi_monitor_if)::set(
  null, "*", "qspi_monitor_vif", serial_monitor);
qspi_irq_if irq_if(.qclk(i_qspi_clk), .qresetn(i_qspi_rst_n), .irq(o_qspi_int_irq));
qspi_dma_if dma_if(.dclk(i_qspi_dma_clk), .dresetn(i_qspi_dma_rst_n),
                   .tx_req(o_qspi_dma_tx_req), .rx_req(o_qspi_dma_rx_req));
assign i_qspi_dma_tx_clr = dma_if.tx_clr;
assign i_qspi_dma_rx_clr = dma_if.rx_clr;
initial begin
  uvm_config_db#(virtual qspi_irq_if)::set(null, "*", "qspi_irq_vif", irq_if);
  uvm_config_db#(virtual qspi_dma_if)::set(null, "*", "qspi_dma_vif", dma_if);
end
  // Checks are sampled at the external interfaces, independently of DUT internals.
  reset_outputs: assert property (@(posedge i_qspi_clk) (!i_qspi_rst_n && $past(!i_qspi_rst_n)) |-> (!o_qspi_int_irq && o_qspi_pad_cs_n))
    else $error("QSPI_SVA reset must deassert IRQ and deselect flash");
  apb_hold: assert property (@(posedge i_qspi_pclk) disable iff(!i_qspi_preset_n)
    (i_qspi_apb_psel && i_qspi_apb_penable && !o_qspi_apb_pready) |=> (i_qspi_apb_psel && i_qspi_apb_penable && $stable({i_qspi_apb_paddr,i_qspi_apb_pwrite,i_qspi_apb_pwdata})))
    else $error("QSPI_SVA APB request changed during wait state");
// Clock periods are checked by SVA in the connection layer.
realtime qspi_previous_core_edge = 0;
always @(posedge i_qspi_clk) qspi_previous_core_edge <= $realtime;
core_clock_period: assert property (@(posedge i_qspi_clk) disable iff(!i_qspi_rst_n)
  ($realtime-qspi_previous_core_edge > 199.999 &&
   $realtime-qspi_previous_core_edge < 200.001))
  else $error("QSPI_SVA core clock period must be 200 ns");
realtime qspi_previous_apb_edge = 0;
always @(posedge i_qspi_pclk) qspi_previous_apb_edge <= $realtime;
apb_clock_period: assert property (@(posedge i_qspi_pclk) disable iff(!i_qspi_preset_n)
  ($realtime-qspi_previous_apb_edge > 9.999 &&
   $realtime-qspi_previous_apb_edge < 10.001))
  else $error("QSPI_SVA apb clock period must be 10 ns");
realtime qspi_previous_ahb_edge = 0;
always @(posedge i_qspi_hclk) qspi_previous_ahb_edge <= $realtime;
ahb_clock_period: assert property (@(posedge i_qspi_hclk) disable iff(!i_qspi_hreset_n)
  ($realtime-qspi_previous_ahb_edge > 9.999 &&
   $realtime-qspi_previous_ahb_edge < 10.001))
  else $error("QSPI_SVA ahb clock period must be 10 ns");
realtime qspi_previous_dma_edge = 0;
always @(posedge i_qspi_dma_clk) qspi_previous_dma_edge <= $realtime;
dma_clock_period: assert property (@(posedge i_qspi_dma_clk) disable iff(!i_qspi_dma_rst_n)
  ($realtime-qspi_previous_dma_edge > 9.999 &&
   $realtime-qspi_previous_dma_edge < 10.001))
  else $error("QSPI_SVA dma clock period must be 10 ns");
resets_released: assert property (@(posedge i_qspi_clk) disable iff(!i_qspi_rst_n)
  (i_qspi_preset_n && i_qspi_hreset_n && i_qspi_dma_rst_n))
  else $error("QSPI_SVA bus and DMA resets must be released with core reset");

// Shared bidirectional QSPI flash bus. The DUT drives each bit only while its
// output-enable is asserted; otherwise the flash model may drive the bus.
tri [3:0] qspi_flash_io;
assign (weak0, weak1) qspi_flash_io = 4'b1100; // Idle HOLD#/WP# high.
assign i_qspi_pad_io = qspi_flash_io;

// -----------------------------------------------------------------------------
//QSPI flash model
// -----------------------------------------------------------------------------
reg mx35_csn = 1'b1;
reg w25q_csn = 1'b1;
//FIXME // -----------------------------------------------------------------------------
//FIXME // MX35 NAND/QSPI flash model
//FIXME // -----------------------------------------------------------------------------
//FIXME MX35UF4GE4AD flash_MX35UF4GE4AD_inst (
//FIXME   .SCK   (mx35_csn),
//FIXME   .CSB   (o_qspi_pad_csn),
//FIXME   .SI    (),
//FIXME   .SO    (),
//FIXME   .WPB   (),
//FIXME   .HOLDB ()
//FIXME );
//FIXME 
//FIXME // -----------------------------------------------------------------------------
//FIXME // W25Q QPSI NOR flash model
//FIXME // -----------------------------------------------------------------------------
//FIXME   W25Q16JV w25q_inst (
//FIXME       .CSn    (w25q_csn),
//FIXME       .CLK    (o_qspi_pad_sclk),
//FIXME       .DIO    (),
//FIXME       .DO     (),
//FIXME       .WPn    (),
//FIXME       .HOLDn  ()
//FIXME       );
//FIXME 
// -----------------------------------------------------------------------------
// N25Q NOR/QSPI flash model
// -----------------------------------------------------------------------------
// qspi_flash_io is a resolved bidirectional bus. The DUT drives it only when
// the corresponding pad output-enable is asserted; the flash model drives it
// during read data phases.
for (genvar qspi_io_idx = 0; qspi_io_idx < 4; qspi_io_idx++) begin : g_qspi_flash_io
  // Separate simultaneous DDR clock/data events at the vendor model pins.
  // Explicit pad skew: 5 ns data/OE propagation, clock path left undelayed.
  assign #5ns qspi_flash_io[qspi_io_idx] = o_qspi_pad_io_oe[qspi_io_idx]
                                      ? o_qspi_pad_io[qspi_io_idx] : 1'bz;
end

`ifndef QSPI_NO_FLASH
`ifdef QSPI_SDR_FLASH
qspi_flash_sdr flash_sdr_inst (
  .csb(o_qspi_pad_cs_n), .clk(o_qspi_pad_sclk),
  .io0(qspi_flash_io[0]), .io1(qspi_flash_io[1]),
  .io2(qspi_flash_io[2]), .io3(qspi_flash_io[3])
);
`else
logic [31:0] qspi_flash_vcc = 0;
initial #100ns qspi_flash_vcc = 32'd3300;
N25Qxxx #(
  .memory_file(""), // Use the vendor model's erased-array initialization.
  .fdp_file("/home/hungle/workspace/Dummy/connect/flash/n25q256a/sfdp.vmf")
) flash_n25q_inst (
  .S         (o_qspi_pad_cs_n),
  .C_        (o_qspi_pad_sclk),
  .DQ0       (qspi_flash_io[0]),
  .DQ1       (qspi_flash_io[1]),
  .Vpp_W_DQ2 (qspi_flash_io[2]),
  .HOLD_DQ3  (qspi_flash_io[3]),
  .Vcc       (qspi_flash_vcc)
);
`endif // QSPI_SDR_FLASH
`endif // QSPI_NO_FLASH
//FIXME 
//FIXME   if ($test$plusargs("w25q_csn")) begin
//FIXME     force w25q_csn = o_qspi_pad_csn;
//FIXME   end
//FIXME 
//FIXME  if ($test$plusargs("mx35_csn")) begin
//FIXME     force mx35_csn = o_qspi_pad_csn;
//FIXME   end
//FIXME end
//FIXME 


