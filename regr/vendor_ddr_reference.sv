// Independent pin driver: no QSPI DUT or UVM code participates in this test.
`timescale 1ns/1ps
module vendor_ddr_reference;
  logic cs=1,clk=0;
  logic [31:0] supply=0;
  logic [3:0] host_data=0,host_oe=0;
  tri [3:0] io;
  int errors=0;
  initial begin #5ms;$fatal(1,"Vendor DDR reference watchdog");end
  initial #100 supply=3300;
  assign (weak0,weak1) io=4'b1100;
  for(genvar n=0;n<4;n++) assign #5ns io[n]=host_oe[n]?host_data[n]:1'bz;
  N25Qxxx #(.memory_file(""),.fdp_file("/home/hungle/workspace/Project/IPTrial_V0/dv/qspi/connect/flash/n25q256a/sfdp.vmf"))
  flash_n25q_inst(.S(cs),.C_(clk),.DQ0(io[0]),.DQ1(io[1]),.Vpp_W_DQ2(io[2]),.HOLD_DQ3(io[3]),.Vcc(supply));
  task start_frame(bit cpol=0);
    clk=cpol;#20;cs=0;#20;
  endtask
  task end_frame();cs=1;host_oe=0;#30;endtask
  task send_byte(byte value);
    host_oe=1;
    for(int b=7;b>=0;b--) begin
      host_data=4'(value>>b);
      if(!clk) begin #10;clk=1;#10;clk=0;end
      else begin #10;clk=0;#10;clk=1;end
    end
    #10;
  endtask
  task send_address_sdr(int addr);
    send_byte(8'(addr>>16));send_byte(8'(addr>>8));send_byte(8'(addr));
  endtask
  task send_address_ddr(int addr);
    host_oe=1;
    if(clk) begin host_data=4'(addr>>23);#10;clk=0;#10;end
    for(int b=23;b>=0;b--) begin
      host_data=4'(addr>>b);#10;clk=~clk;#10;
    end
  endtask
  task receive_ddr(output byte value,input int lanes);
    value=0;host_oe=0;
    for(int b=0;b<8;b+=lanes) begin
      #10;
      if(lanes==1)value=(value<<1)|8'(io[1]);
      else value=(value<<lanes)|8'(io&4'((1<<lanes)-1));
      clk=~clk;#10;
    end
  endtask
  initial begin
    byte got,opcode,expected;
    int before_errors;
    #1000;
    start_frame();send_byte('h06);end_frame();
    start_frame();send_byte('h81);send_byte('h4b);end_frame();#100;
    start_frame();send_byte('h06);end_frame();
    start_frame();send_byte('h02);send_address_sdr('h10000);
    for(int i=0;i<16;i++)send_byte(8'((i*37)^'ha5));
    end_frame();#1100000;
    for(int ck=0;ck<2;ck++) begin
      for(int lanes=1;lanes<=4;lanes*=2) begin
        before_errors=errors;
        opcode=(lanes==1)?8'h0d:(lanes==2)?8'h3d:8'h6d;
        start_frame(bit'(ck));send_byte(opcode);send_address_ddr('h10000);
        host_oe=0;
        repeat(lanes==4?8:4) begin #10;clk=1;#10;clk=0;end
        for(int i=0;i<16;i++)begin
          receive_ddr(got,lanes);expected=8'((i*37)^'ha5);
          if(got!==expected)begin
            errors++;
            $display("VENDOR_DDR_MISMATCH CKMODE=%0d lanes=%0d byte=%0d expected=%02h actual=%02h",ck,lanes,i,expected,got);
          end
        end
        end_frame();
        $display("VENDOR_DDR_RESULT CKMODE=%0d lanes=%0d errors=%0d",ck,lanes,errors-before_errors);
      end
    end
    if(errors) $fatal(1,"Vendor reference DDR mismatches=%0d",errors);
    $finish;
  end
endmodule
