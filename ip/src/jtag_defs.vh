`ifndef JTAG_DEFS
`define JTAG_DEFS

// Register widths
`define JTAG_STATE_WIDTH 4
`define JTAG_IR_WIDTH 4

// TAP controller states
`define JTAG_TEST_LOGIC_RESET 4'h0
`define JTAG_RUN_TEST_IDLE 4'h1
`define JTAG_SELECT_DR_SCAN 4'h2
`define JTAG_CAPTURE_DR 4'h3
`define JTAG_SHIFT_DR 4'h4
`define JTAG_EXIT1_DR 4'h5
`define JTAG_PAUSE_DR 4'h6
`define JTAG_EXIT2_DR 4'h7
`define JTAG_UPDATE_DR 4'h8
`define JTAG_SELECT_IR_SCAN 4'h9
`define JTAG_CAPTURE_IR 4'hA
`define JTAG_SHIFT_IR 4'hB
`define JTAG_EXIT1_IR 4'hC
`define JTAG_PAUSE_IR 4'hD
`define JTAG_EXIT2_IR 4'hE
`define JTAG_UPDATE_IR 4'hF

// Instruction register
`define JTAG_IR_EXTEST 4'h0
`define JTAG_IR_SAMPLE_PRELOAD 4'h1
`define JTAG_IR_BYPASS 4'hF
`define JTAG_IR_CAPTURE 4'b0001

`endif
