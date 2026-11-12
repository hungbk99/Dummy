`timescale 1ns/1ps
interface qspi_irq_if(input logic qclk, qresetn, irq);
  realtime last_qedge = 0;
  always @(posedge qclk) last_qedge = $realtime;
  always @(irq) if(qresetn && $realtime>0 && $realtime!=last_qedge)
    $error("QSPI_SVA IRQ changed outside the QSPI clock edge");

  task automatic wait_core(input int cycles=4);
    repeat(cycles) @(negedge qclk);
  endtask
endinterface
