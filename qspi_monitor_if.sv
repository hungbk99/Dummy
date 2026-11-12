`timescale 1ns/1ps
// Passive serial-pin monitor. AHB/APB traffic remains owned by their agents.
interface qspi_monitor_if(input logic resetn, csn, sclk);
  int unsigned frames=0, sclk_rises=0;
  realtime frame_start_ns=0, last_edge_ns=0, last_end_ns=0;
  bit edge_seen=0, completed_frame=0;
  bit timing_enabled=0;
  realtime min_setup_ns=0, min_hold_ns=0, min_idle_ns=0;
  int unsigned setup_checks=0, hold_checks=0, idle_checks=0, timing_errors=0;

  always @(negedge csn) if(resetn) begin
    frames++;
    frame_start_ns=$realtime;
    edge_seen=0;
  end
  always @(sclk) if(resetn && !csn) begin
    edge_seen=1;
    last_edge_ns=$realtime;
  end
  always @(posedge csn) if(resetn) begin
    last_end_ns=$realtime;
    completed_frame=1;
  end
  always @(posedge sclk) if(resetn && !csn) sclk_rises++;

  cs_setup: assert property (@(sclk) disable iff(!resetn || csn || !timing_enabled)
    (!edge_seen) |-> ($realtime-frame_start_ns+0.001 >= min_setup_ns))
    begin if(!$sampled(edge_seen)) setup_checks++; end
    else begin timing_errors++; $error("QSPI_SVA CS setup time too short"); end
  cs_hold: assert property (@(posedge csn) disable iff(!resetn || !timing_enabled)
    edge_seen |-> ($realtime-last_edge_ns+0.001 >= min_hold_ns))
    begin if($sampled(edge_seen)) hold_checks++; end
    else begin timing_errors++; $error("QSPI_SVA CS hold time too short"); end
  cs_idle: assert property (@(negedge csn) disable iff(!resetn || !timing_enabled)
    completed_frame |-> ($realtime-last_end_ns+0.001 >= min_idle_ns))
    begin if($sampled(completed_frame)) idle_checks++; end
    else begin timing_errors++; $error("QSPI_SVA CS idle time too short"); end

  task automatic check_timing(input realtime setup_ns, hold_ns, idle_ns);
    min_setup_ns=setup_ns;
    min_hold_ns=hold_ns;
    min_idle_ns=idle_ns;
    timing_enabled=1;
  endtask
  task automatic stop_timing_checks();
    timing_enabled=0;
  endtask
  task automatic wait_frame_start();
    @(negedge csn);
  endtask
endinterface
