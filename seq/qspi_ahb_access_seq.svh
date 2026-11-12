`ifndef QSPI_AHB_ACCESS_SEQ_SVH
`define QSPI_AHB_ACCESS_SEQ_SVH

class qspi_ahb_access_seq_c extends uvm_sequence #(ahb_master_transaction);
  `uvm_object_utils(qspi_ahb_access_seq_c)
  bit [31:0] address;
  bit write_access;
  int unsigned beats = 1;
  bit incrementing;
  ahb_master_transaction result;

  function new(string name="qspi_ahb_access_seq_c");
    super.new(name);
  endfunction

  virtual task body();
    ahb_master_transaction req;
    req = ahb_master_transaction::type_id::create("req");
    start_item(req);
    req.addr = address;
    req.direction = write_access ? AHB_WRITE : AHB_READ;
    req.size = AHB_WORD;
    req.burst = incrementing ? AHB_INCR : AHB_SINGLE;
    req.num_beats = beats;
    req.hprot = 4'b0011;
    req.hmastlock = 0;
    req.master_delay = 0;
    req.write_data = new[beats];
    req.hwstrb = new[beats];
    req.busy_cycles = new[beats];
    req.read_data = new[beats];
    req.responses = new[beats];
    req.wait_cycles = new[beats];
    foreach(req.hwstrb[i]) req.hwstrb[i] = write_access ? '1 : '0;
    finish_item(req);
    get_response(result);
  endtask
endclass
`endif
