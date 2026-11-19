`timescale 1ns / 1ps
`include "jtag_defs.vh"

module jtag_ir_decoder (
    input wire [`JTAG_IR_WIDTH-1:0] instruction,

    // Data-register selection
    output wire select_extest,
    output wire select_sample_preload,
    output wire select_bypass
);

    // Unknown opcodes select BYPASS
    assign select_extest = (instruction == `JTAG_IR_EXTEST);
    assign select_sample_preload = (instruction == `JTAG_IR_SAMPLE_PRELOAD);
    assign select_bypass = !(select_extest || select_sample_preload);

endmodule
