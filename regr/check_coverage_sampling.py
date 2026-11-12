#!/usr/bin/env python3
"""Check covergroup gating without an SMT solver; does not simulate the QSPI DUT."""
import argparse
from pathlib import Path
import subprocess
import tempfile


def counters(path):
    result = {}
    for line in path.read_text().splitlines():
        if not line.startswith("C '"):
            continue
        metadata, count = line[3:].rsplit("' ", 1)
        fields = dict(item.split('\x02', 1) for item in metadata.split('\x01') if '\x02' in item)
        if 'qspi_coverage_c::' in fields.get('h', ''):
            result[fields['h']] = int(count)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path)
    args = parser.parse_args()
    output = (args.out or Path(tempfile.mkdtemp(prefix='qspi_coverage_'))).resolve()
    output.mkdir(parents=True, exist_ok=True)
    root = Path(__file__).resolve().parents[1]
    bench = output / 'check.sv'
    # This small stand-in only supplies the component constructor/factory macro.
    # The actual production covergroup source is compiled without modification.
    bench.write_text('''`define uvm_component_utils(T)
class uvm_component;
  function new(string name="",uvm_component parent=null); endfunction
endclass
`include "qspi_coverage.svh"
module check;
  qspi_coverage_c coverage;
  bit passed;
  initial begin
    coverage=new("coverage");
    passed=!$test$plusargs("fail_only");
    coverage.feature_cg.sample(2,passed);
    coverage.read_cg.sample(4,32,1,1,0,passed);
    coverage.irq_cg.sample(2,1,2,passed);
    coverage.abort_cg.sample(2,passed);
    coverage.polling_cg.sample(13,passed);
    coverage.frame_cg.sample(4,4,31,passed);
    coverage.delay_cg.sample(3,3,3,passed);
    $finish;
  end
endmodule
''')
    command = ['verilator', '--binary', '--timing', '--coverage-user', '-Wno-fatal',
               '--top-module', 'check', '--Mdir', str(output / 'obj'),
               '-I' + str(root / 'env'), str(bench)]
    with (output / 'compile.log').open('w') as log:
        subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True)
    results = {}
    for name in ('fail', 'pass'):
        command = [str(output / 'obj/Vcheck'),
                   '+verilator+coverage+file+' + str(output / (name + '.dat'))]
        if name == 'fail':
            command.append('+fail_only')
        with (output / (name + '.log')).open('w') as log:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True)
        results[name] = counters(output / (name + '.dat'))
    suffixes = ('feature_cg.verified.indirect', 'read_cg.width.quad_lane',
                'read_cg.length.b32', 'read_cg.clock_mode.mode3',
                'irq_cg.flag.txftf', 'abort_cg.recovered.memory_mapped_pending_ahb',
                'polling_cg.verified.wip_to_ready', 'frame_cg.dummy.maximum',
                'delay_cg.setup_time.three')
    for suffix in suffixes:
        keys = [key for key in results['pass'] if key.endswith(suffix)]
        if len(keys) != 1:
            raise RuntimeError(f'Expected one bin matching {suffix}, found {keys}')
        key = keys[0]
        if results['fail'][key] != 0 or results['pass'][key] != 1:
            raise RuntimeError(f'Incorrect pass/fail gating for {key}')
    if any(value for key, value in results['pass'].items() if 'read_cg.xip_matrix.' in key):
        raise RuntimeError('Indirect sample incorrectly hit XIP cross coverage')
    print(f'PASS: nine checked bins reject failed samples and accept passing samples; XIP cross stays unhit. Logs: {output}')


if __name__ == '__main__':
    main()
