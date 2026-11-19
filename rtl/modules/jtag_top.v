`timescale 1ns / 1ps
`include "jtag_defs.vh"

module jtag_top #(
    parameter integer BOUNDARY_WIDTH = 8
)(
    // JTAG TAP interface
    input wire tck,
    input wire tms,
    input wire tdi,
    output reg tdo,
    output reg tdo_oe,
    input wire trst_n,

    // System I/O and core interface
    input wire [BOUNDARY_WIDTH-1:0] pin_in,
    input wire [BOUNDARY_WIDTH-1:0] core_out,
    output wire [BOUNDARY_WIDTH-1:0] pin_out
);

    // Current TAP state & enable flags
    wire [`JTAG_STATE_WIDTH-1:0] tap_curr_state;
    wire test_logic_reset;
    wire capture_dr, shift_dr, update_dr;
    wire capture_ir, shift_ir, update_ir;

    // Instruction and data-register selects
    wire [`JTAG_IR_WIDTH-1:0] instruction;
    wire select_extest, select_sample_preload, select_bypass;
    wire select_bsr;

    // Serial outputs of each register
    wire ir_out, bypass_out, bsr_out;
    wire dr_out;
    wire unused_ok = &{1'b0, tap_curr_state};

    // Select BSR (EXTEST or SAMPLE/PRELOAD) or BYPASS as the active DR output
    assign select_bsr = select_extest || select_sample_preload;
    assign dr_out = select_bsr ? bsr_out : bypass_out;

    // 16-state TAP controller
    jtag_tap_ctrl u_tap_ctrl (
        .tck(tck),
        .tms(tms),
        .trst_n(trst_n),
        .test_logic_reset(test_logic_reset),
        .capture_dr(capture_dr),
        .shift_dr(shift_dr),
        .update_dr(update_dr),
        .capture_ir(capture_ir),
        .shift_ir(shift_ir),
        .update_ir(update_ir),
        .tap_curr_state(tap_curr_state)
    );

    // 4-bit instruction register
    jtag_ir u_ir (
        .tck(tck),
        .tdi(tdi),
        .trst_n(trst_n),
        .test_logic_reset(test_logic_reset),
        .capture_ir(capture_ir),
        .shift_ir(shift_ir),
        .update_ir(update_ir),
        .ir_out(ir_out),
        .instruction(instruction)
    );

    // Instruction decoder (EXTEST, SAMPLE/PRELOAD, BYPASS)
    jtag_ir_decoder u_ir_decoder (
        .instruction(instruction),
        .select_extest(select_extest),
        .select_sample_preload(select_sample_preload),
        .select_bypass(select_bypass)
    );

    // 1-bit BYPASS data register (default after reset)
    jtag_dr_bypass u_dr_bypass (
        .tck(tck),
        .tdi(tdi),
        .trst_n(trst_n),
        .capture_dr(capture_dr),
        .shift_dr(shift_dr),
        .select_bypass(select_bypass),
        .bypass_out(bypass_out)
    );

    // Boundary-scan data register
    jtag_dr_bsr #(
        .BOUNDARY_WIDTH(BOUNDARY_WIDTH)
    ) u_dr_bsr (
        .tck(tck),
        .trst_n(trst_n),
        .capture_dr(capture_dr && select_bsr),
        .shift_dr(shift_dr && select_bsr),
        .update_dr(update_dr && select_bsr),
        .select_extest(select_extest),
        .serial_in(tdi),
        .serial_out(bsr_out),
        .pin_in(pin_in),
        .core_out(core_out),
        .pin_out(pin_out)
    );

    // TDO output stage (updated on falling edge of TCK in Shift-IR/Shift-DR)
    always @(negedge tck or negedge trst_n) begin
        if (!trst_n) begin
            tdo <= 1'b0;
            tdo_oe <= 1'b0;
        end else begin
            tdo_oe <= shift_ir || shift_dr;
            if (shift_ir)
                tdo <= ir_out;
            else if (shift_dr)
                tdo <= dr_out;
            else
                tdo <= 1'b0;
        end
    end

endmodule
