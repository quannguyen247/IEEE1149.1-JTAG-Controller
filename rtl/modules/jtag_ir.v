`timescale 1ns / 1ps
`include "jtag_defs.vh"

module jtag_ir (
    input wire tck,
    input wire tdi,
    input wire trst_n,

    // Control signals from TAP controller
    input wire test_logic_reset,
    input wire capture_ir,
    input wire shift_ir,
    input wire update_ir,

    // Serial IR output and active instruction
    output wire ir_out,
    output reg [`JTAG_IR_WIDTH-1:0] instruction
);

    // IR shift register, LSB leaves on TDO first
    reg [`JTAG_IR_WIDTH-1:0] ir_shift;

    assign ir_out = ir_shift[0];

    // Capture "0001" and shift right on rising TCK (TDI enters at the MSB)
    always @(posedge tck or negedge trst_n) begin
        if (!trst_n)
            ir_shift <= `JTAG_IR_CAPTURE;
        else if (test_logic_reset || capture_ir)
            ir_shift <= `JTAG_IR_CAPTURE;
        else if (shift_ir)
            ir_shift <= {tdi, ir_shift[`JTAG_IR_WIDTH-1:1]};
    end

    // Load the new instruction on falling TCK in Update-IR, reset selects BYPASS
    always @(negedge tck or negedge trst_n) begin
        if (!trst_n)
            instruction <= `JTAG_IR_BYPASS;
        else if (test_logic_reset)
            instruction <= `JTAG_IR_BYPASS;
        else if (update_ir)
            instruction <= ir_shift;
    end

endmodule
