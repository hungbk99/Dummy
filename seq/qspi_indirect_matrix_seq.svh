`ifndef QSPI_INDIRECT_MATRIX_SEQ_SVH
`define QSPI_INDIRECT_MATRIX_SEQ_SVH

// QSPI indirect matrix seq.
class qspi_indirect_matrix_seq_c extends qspi_feature_base_seq_c;
  `uvm_object_utils(qspi_indirect_matrix_seq_c)
  rand int unsigned transfer_bytes;
  rand int unsigned lane_count;
  rand int unsigned clock_mode;
  rand int unsigned ddr_mode;

  constraint indirect_transfer_c {
    transfer_bytes inside {1,4,8,16,32,128};
    lane_count inside {1,2,4};
    clock_mode inside {0,1};
    ddr_mode inside {0,1};
  }
  // Select this scenario's legal fixed inputs for the dedicated Verilator list.
  virtual function void qspi_set_directed_stimulus();
    super.qspi_set_directed_stimulus();
    transfer_bytes = 4; lane_count = 1; clock_mode = 0; ddr_mode = 0;
  endfunction

  extern function new(string name = "qspi_indirect_matrix_seq_c");
  extern virtual task body();
  extern function void post_randomize();
endclass : qspi_indirect_matrix_seq_c

// Construct this object and initialize its inherited UVM state.
function qspi_indirect_matrix_seq_c::new(string name = "qspi_indirect_matrix_seq_c");
  super.new(name, "indirect");
endfunction : new

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// Run this scenario: indirect matrix seq. Check failures are reported through UVM.
task qspi_indirect_matrix_seq_c::body();
  int sizes[6] = '{1,4,8,16,32,128};
  qspi_initialize_flash_and_controller();
  qspi_program_expected_image(256);

  // Keep all directed matrix bins; randomize the actual stimulus fields per bin.
  for (int ck = 0; ck < 2; ck++) begin
    for (int rate = 0; rate < 2; rate++) begin
      for (int lanes = 1; lanes <= 4; lanes *= 2) begin
        foreach (sizes[n]) begin
          int requested_bytes = sizes[n];
          if (directed_stimulus) begin
            transfer_bytes = requested_bytes;
            lane_count = lanes;
            clock_mode = ck;
            ddr_mode = rate;
            post_randomize();
          end else if (!this.randomize() with {
            transfer_bytes == requested_bytes;
            lane_count == lanes;
            clock_mode == ck;
            ddr_mode == rate;
          })
          `uvm_fatal("QSPI_RANDOMIZE", "Cannot randomize indirect matrix bin")
          qspi_configure_controller(bit'(clock_mode),bit'(ddr_mode));
          qspi_read_flash_and_check_data(transfer_bytes,qspi_build_read_command(lane_count,bit'(ddr_mode)),
          $sformatf("Micron CKMODE=%0d DDR=%0d lanes=%0d bytes=%0d",
          clock_mode,ddr_mode,lane_count,transfer_bytes));
        end
      end
    end
  end
endtask : body

// Report the selected stimulus so failures can be reproduced from the run log.
function void qspi_indirect_matrix_seq_c::post_randomize();
  `uvm_info("QSPI_STIMULUS", $sformatf("%s transfer_bytes=%0d lane_count=%0d clock_mode=%0d ddr_mode=%0d", get_type_name(), transfer_bytes, lane_count, clock_mode, ddr_mode), UVM_LOW)
endfunction : post_randomize

`endif
