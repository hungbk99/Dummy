
`ifndef QSPI_BASE_SEQ_C_SVH
`define QSPI_BASE_SEQ_C_SVH

class qspi_base_seq_c extends base_sequence;
  `uvm_object_utils(qspi_base_seq_c);

  qspi_env_c m_qspi_env;

  `include "qspi_reg_info.svh"

  extern function new(string name="qspi_base_seq_c");

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
  virtual task pre_body();
    if (!$cast(m_qspi_env, m_env))
      `uvm_fatal("QSPI_ENV_CAST", "Sequence requires qspi_env_c")
  endtask: pre_body

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
  virtual task reg_write32(bit [31:0] addr, bit[31:0] data);
    apb_master_seq m_wr_seq;

    m_wr_seq = apb_master_seq::type_id::create("m_wr_seq");
    m_wr_seq.set_sequencer(m_qspi_env.m_apb_env.master_agent.m_apb_master_sequencer);
    m_wr_seq.apb_master_write(addr, data);
  endtask: reg_write32

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
  virtual task reg_read32(bit [31:0] addr, output bit [31:0] data, output bit error);
    apb_master_seq m_rd_seq;

    m_rd_seq = apb_master_seq::type_id::create("m_rd_seq");
    m_rd_seq.set_sequencer(m_qspi_env.m_apb_env.master_agent.m_apb_master_sequencer);
    m_rd_seq.apb_master_read(addr, data);
    error = (m_rd_seq.last_pslverr == ERROR);
    `ifdef QSPI_TESTPLAN
    if (!error) begin
      m_qspi_env.m_coverage.register_cg.sample(int'(addr));
      if (addr==32'h08)
        m_qspi_env.m_coverage.fifo_cg.sample(int'(data[13:8]),int'(data[21:16]));
    end
    `endif
  endtask: reg_read32

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
  virtual task xip_read_single();
    //FIXME ahb_single_read_seq m_xip_seq;

    //FIXME m_xip_seq = apb_master_seq::type_id::create("m_xip_seq");
    //FIXME m_xip_seq
  endtask: xip_read_single

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
  virtual task xip_read_burst();
  endtask: xip_read_burst

  //FIXME - Should use RAL, or script to generate QSPI_RW_REGS from RTL
  //        information
  extern function bit qspi_get_reg_addr(
      input  string     reg_name,
      output bit [31:0] addr
  );

endclass: qspi_base_seq_c

function qspi_base_seq_c::new(string name="qspi_base_seq_c");
    super.new(name);
  endfunction : new

function bit qspi_base_seq_c::qspi_get_reg_addr(
      input  string     reg_name,
      output bit [31:0] addr
  );
    addr = '0;

    foreach (QSPI_RW_REGS[i]) begin
      if (QSPI_RW_REGS[i].name == reg_name) begin
        addr = QSPI_RW_REGS[i].addr;
        return 1'b1;  // Register found
      end
    end

    return 1'b0;      // Register not found
  endfunction : qspi_get_reg_addr


`endif//QSPI_BASE_SEQ_C_SVH


  
