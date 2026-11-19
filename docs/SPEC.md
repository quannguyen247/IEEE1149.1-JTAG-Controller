# JTAG controller specification

## 1. Overview

`jtag_top` is a device-side IEEE 1149.1 TAP. It contains:

- `jtag_tap_ctrl`: 16-state TAP controller.
- `jtag_ir`: 4-bit instruction register.
- `jtag_ir_decoder`: instruction decoder for data-register selection.
- `jtag_dr_bypass`: 1-bit BYPASS register.
- `jtag_dr_bsr`: boundary-scan register (one `jtag_dr_bsr_cell` per I/O pin) and EXTEST output mux.
- `jtag_dr_bsr_cell`: single boundary-scan cell with rising-edge capture/shift stage and falling-edge update latch.

Shared constants are defined in `rtl/utils/jtag_defs.vh`. All logic runs on TCK. TRST_N is an asynchronous active-low reset.

## 2. Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `BOUNDARY_WIDTH` | `8` | Width of `pin_in`, `core_out`, and `pin_out` (`BOUNDARY_WIDTH` input pins and `BOUNDARY_WIDTH` output pins, must be >= 1) |

## 3. Ports

| Port | Dir | Width | Description |
| --- | --- | --- | --- |
| `tck` | In | 1 | Test clock |
| `tms` | In | 1 | Test mode select, sampled on rising TCK |
| `tdi` | In | 1 | Test data in, sampled on rising TCK |
| `tdo` | Out | 1 | Test data out, changes on falling TCK (0 outside Shift-IR/Shift-DR) |
| `tdo_oe` | Out | 1 | TDO output enable for an external tri-state pad buffer |
| `trst_n` | In | 1 | Test reset, asynchronous active low |
| `pin_in` | In | `BOUNDARY_WIDTH` | Input pin values to sample |
| `core_out` | In | `BOUNDARY_WIDTH` | Functional output values from the core logic |
| `pin_out` | Out | `BOUNDARY_WIDTH` | Output pins, driven by `core_out` or the preloaded value under EXTEST |

Inputs and outputs use separate vectors. Bidirectional pads need extra
output-enable cells that this core does not include.

## 4. Instructions

| IR | Instruction | Selected DR | Length |
| --- | --- | --- | --- |
| `0x0` | EXTEST | Boundary register (`pin_out` driven by update latches) | `2 * BOUNDARY_WIDTH` |
| `0x1` | SAMPLE/PRELOAD | Boundary register (`pin_out` follows `core_out`) | `2 * BOUNDARY_WIDTH` |
| `0xF` | BYPASS | BYPASS register (captures 0) | 1 |
| Other | Unimplemented | BYPASS register | 1 |

Capture-IR loads `4'b0001`. After TRST_N or Test-Logic-Reset, the active
instruction is BYPASS.

## 5. Scan order

IR and DR shift LSB first. Bit 0 leaves on TDO while TDI enters at the MSB.

The boundary register is laid out as:

```text
BSR[BOUNDARY_WIDTH-1:0]                 = pin_in  (input cells)
BSR[2*BOUNDARY_WIDTH-1:BOUNDARY_WIDTH]  = pin_out (output cells)
```

To preload a test pattern, select SAMPLE/PRELOAD, shift in the full boundary
value, and pass through Update-DR to latch the upper half into the output
cells. Switching to EXTEST puts those latched values on `pin_out`, and later
EXTEST scans refresh `pin_out` on each Update-DR.

## 6. Timing and reset

| Action | Edge | TAP state |
| --- | --- | --- |
| TAP state change (by TMS) | Rising TCK | Any |
| IR / DR capture | Rising TCK | Capture-IR / Capture-DR |
| IR / DR shift | Rising TCK | Shift-IR / Shift-DR |
| Active instruction update | Falling TCK | Update-IR |
| Boundary output latch update | Falling TCK | Update-DR |
| TDO and `tdo_oe` | Falling TCK | Shift-IR / Shift-DR |

Capture and shift act on the state before the rising edge, so the last shift
happens on the edge that exits Shift with TMS = 1. Because TDO and `tdo_oe`
update on falling TCK, that last bit stays valid and enabled into Exit1.
BYPASS delays TDI by one shift cycle. SAMPLE/PRELOAD never takes over
`pin_out`, and shifting under EXTEST holds `pin_out` steady until Update-DR.

- TRST_N low: enters Test-Logic-Reset and selects BYPASS. It loads `4'b0001`
  into IR and clears BYPASS, the boundary cells, the update latches, TDO, and
  `tdo_oe`.
- Five rising TCK edges with TMS = 1: reaches Test-Logic-Reset from any state
  and switches back to BYPASS on the next falling edge, so `pin_out` follows
  `core_out` again. The boundary update latches keep their values.
