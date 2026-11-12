`timescale 1ns/1ps
interface qspi_dma_if(input logic dclk, dresetn, tx_req, rx_req);
  logic tx_clr = 0, rx_clr = 0;

  task automatic pulse_tx_clear(input int cycles);
    @(negedge dclk);
    tx_clr = 1;
    repeat(cycles) @(negedge dclk);
    tx_clr = 0;
  endtask
endinterface
