
`ifndef QSPI_ENV_C_SVH
`define QSPI_ENV_C_SVH

// QSPI env.
class qspi_env_c extends uvm_env;
  `uvm_component_utils(qspi_env_c)

  qspi_coverage_c m_coverage;
  qspi_virtual_sequencer_c vseqr;

  ahb_master_agent m_ahb_agent;
  ahb_master_agent_cfg m_ahb_cfg;

  apb_env         m_apb_env;
  apb_sys_config  m_apb_cfg;

  extern virtual function void connect_phase(uvm_phase phase);

  extern function new(string name="qspi_env_c", uvm_component parent=null);

  extern virtual function void build_phase(uvm_phase phase);

endclass: qspi_env_c

// Construct this object and initialize its inherited UVM state.
function qspi_env_c::new(string name="qspi_env_c", uvm_component parent=null);
    super.new(name, parent);
  endfunction : new

// Create and configure the UVM components owned by this component.
function void qspi_env_c::build_phase(uvm_phase phase);
    m_coverage = qspi_coverage_c::type_id::create("m_coverage", this);
    vseqr = qspi_virtual_sequencer_c::type_id::create("vseqr", this);
    //APB ENV set up
    m_apb_cfg = apb_sys_config::type_id::create("m_apb_cfg", this);
    m_apb_cfg.pready_timeout = 1000;
    m_apb_cfg.slave_numb  = 0;

    uvm_config_db#(apb_sys_config)::set(this, "*", "apb_sys_config", m_apb_cfg);
    m_apb_env = apb_env::type_id::create("apb_env",this);

    // The DUT is the AHB slave; instantiate only an active VIP master.
    m_ahb_cfg = ahb_master_agent_cfg::type_id::create("m_ahb_cfg");
    m_ahb_cfg.wait_timeout_cycles = 1100000;
    if (!uvm_config_db#(virtual ahb_if)::get(this, "", "ahb_vif", m_ahb_cfg.vif))
      `uvm_fatal("QSPI_AHB_SETUP", "Missing AHB master interface")
    uvm_config_db#(ahb_master_agent_cfg)::set(this, "m_ahb_agent*", "cfg", m_ahb_cfg);
    m_ahb_agent = ahb_master_agent::type_id::create("m_ahb_agent", this);
  endfunction : build_phase


// Connect the bus sequencers and register the access paths used by reusable sequences.
function void qspi_env_c::connect_phase(uvm_phase phase);
    qspi_apb_bus_access_c register_access;
    qspi_ahb_bus_access_c memory_access;
    super.connect_phase(phase);
    vseqr.apb_seqr["QSPI"] = m_apb_env.master_agent.m_apb_master_sequencer;
    vseqr.ahb_seqr["QSPI"] = m_ahb_agent.sequencer;
    vseqr.coverage = m_coverage;

    register_access = qspi_apb_bus_access_c::type_id::create("register_access");
    register_access.sequencer = vseqr.apb_seqr["QSPI"];
    memory_access = qspi_ahb_bus_access_c::type_id::create("memory_access");
    memory_access.sequencer = vseqr.ahb_seqr["QSPI"];
    vseqr.register_paths["QSPI"] = register_access;
    vseqr.memory_paths["QSPI"] = memory_access;
endfunction : connect_phase

`endif//QSPI_ENV_C_SVH


      
