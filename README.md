# IEEE 1149.1 JTAG controller

Synthesizable Verilog RTL for a device-side IEEE 1149.1 JTAG TAP controller
with a 4-bit IR, 1-bit BYPASS register and parameterized boundary-scan
register. Supports `EXTEST`, `SAMPLE/PRELOAD` and `BYPASS`.

The core uses ordinary fabric ports. It does not replace the dedicated
configuration TAP of an FPGA.

## Source layout

| Path | Purpose |
| --- | --- |
| [`rtl/`](rtl/) | Core RTL (`modules/`) and shared header (`utils/`) |
| [`testbench/`](testbench/) | Self-checking testbench for the full core |
| [`ip/`](ip/) | Packaged Vivado IP repository (`component.xml`) |
| [`docs/SPEC.md`](docs/SPEC.md) | IP specification: ports, instructions, scan order and timing |
| [`docs/jtag_top.bsdl`](docs/jtag_top.bsdl) | Sample IEEE 1149.1-2001 BSDL model for the default `BOUNDARY_WIDTH = 8` configuration, with a symbolic pin map and a 100 MHz reference TCK frequency. |

### RTL modules

| RTL module | Role |
| --- | --- |
| `jtag_defs.vh` | TAP state encoding, IR width, mandatory opcodes and Capture-IR value |
| `jtag_tap_ctrl.v` | 16-state TAP FSM and current-state enables |
| `jtag_ir.v` | IR capture/shift and falling-edge active instruction update (resets to BYPASS) |
| `jtag_ir_decoder.v` | Combinational instruction decoder for DR selection |
| `jtag_dr_bypass.v` | 1-bit BYPASS shift register |
| `jtag_dr_bsr_cell.v` | One boundary cell: capture/shift bit and falling-edge update latch |
| `jtag_dr_bsr.v` | Boundary-scan chain (one cell per I/O pin) and EXTEST output mux |
| `jtag_top.v` | Integration, TDO mux and falling-edge TDO / `tdo_oe` |

## Test and build

The testbench runs in QuestaSim or Icarus Verilog from the repository root:

```sh
# QuestaSim
vlib work
vlog +incdir+rtl/utils rtl/modules/*.v testbench/jtag_top_tb.v
vsim -c jtag_top_tb -do "run -all; quit -f"

# Icarus Verilog
iverilog -g2005 -I rtl/utils -o jtag_top.vvp testbench/jtag_top_tb.v rtl/modules/*.v
vvp -n jtag_top.vvp
```

`jtag_top_tb` accepts `BOUNDARY_WIDTH` (`-GBOUNDARY_WIDTH=13` in QuestaSim,
`-Pjtag_top_tb.BOUNDARY_WIDTH=13` in Icarus) and passes 8/8 tests for widths
1, 8, 13 and 24 (reset/BYPASS, Capture-IR, opcodes `0x2`–`0xF`, IR/DR pause,
TDO timing, SAMPLE/PRELOAD, EXTEST, TMS/TRST_N reset and TAP FSM paths).

Add `ip/` as a user IP repository in Vivado IP Integrator to reuse the
packaged core.

## References

1. IEEE, *IEEE Standard for Test Access Port and Boundary-Scan Architecture*,
   IEEE Std 1149.1-2013.
2. IEEE, [IEEE Std 1149.1-2001](https://standards.ieee.org/ieee/1149.1/1728/), Annex B (BSDL).
3. AMD, *7 Series FPGAs Configuration User Guide*, UG470 (configuration TAP).

## License

This project is licensed under the Apache License 2.0. See [LICENSE](LICENSE)
for details.
