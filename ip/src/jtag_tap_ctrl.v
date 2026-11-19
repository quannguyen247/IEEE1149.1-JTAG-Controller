`timescale 1ns / 1ps
`include "jtag_defs.vh"

module jtag_tap_ctrl (
    input wire tck,
    input wire tms,
    input wire trst_n,

    // Current TAP state enable flags
    output wire test_logic_reset,
    output wire capture_dr,
    output wire shift_dr,
    output wire update_dr,
    output wire capture_ir,
    output wire shift_ir,
    output wire update_ir,

    // Current TAP state
    output reg [`JTAG_STATE_WIDTH-1:0] tap_curr_state
);

    reg [`JTAG_STATE_WIDTH-1:0] tap_next_state;

    assign test_logic_reset = (tap_curr_state == `JTAG_TEST_LOGIC_RESET);
    assign capture_dr = (tap_curr_state == `JTAG_CAPTURE_DR);
    assign shift_dr = (tap_curr_state == `JTAG_SHIFT_DR);
    assign update_dr = (tap_curr_state == `JTAG_UPDATE_DR);
    assign capture_ir = (tap_curr_state == `JTAG_CAPTURE_IR);
    assign shift_ir = (tap_curr_state == `JTAG_SHIFT_IR);
    assign update_ir = (tap_curr_state == `JTAG_UPDATE_IR);

    always @(*) begin
        case (tap_curr_state)
            `JTAG_TEST_LOGIC_RESET: tap_next_state = tms ? `JTAG_TEST_LOGIC_RESET : `JTAG_RUN_TEST_IDLE;
            `JTAG_RUN_TEST_IDLE: tap_next_state = tms ? `JTAG_SELECT_DR_SCAN : `JTAG_RUN_TEST_IDLE;
            `JTAG_SELECT_DR_SCAN: tap_next_state = tms ? `JTAG_SELECT_IR_SCAN : `JTAG_CAPTURE_DR;
            `JTAG_CAPTURE_DR: tap_next_state = tms ? `JTAG_EXIT1_DR : `JTAG_SHIFT_DR;
            `JTAG_SHIFT_DR: tap_next_state = tms ? `JTAG_EXIT1_DR : `JTAG_SHIFT_DR;
            `JTAG_EXIT1_DR: tap_next_state = tms ? `JTAG_UPDATE_DR : `JTAG_PAUSE_DR;
            `JTAG_PAUSE_DR: tap_next_state = tms ? `JTAG_EXIT2_DR : `JTAG_PAUSE_DR;
            `JTAG_EXIT2_DR: tap_next_state = tms ? `JTAG_UPDATE_DR : `JTAG_SHIFT_DR;
            `JTAG_UPDATE_DR: tap_next_state = tms ? `JTAG_SELECT_DR_SCAN : `JTAG_RUN_TEST_IDLE;
            `JTAG_SELECT_IR_SCAN: tap_next_state = tms ? `JTAG_TEST_LOGIC_RESET : `JTAG_CAPTURE_IR;
            `JTAG_CAPTURE_IR: tap_next_state = tms ? `JTAG_EXIT1_IR : `JTAG_SHIFT_IR;
            `JTAG_SHIFT_IR: tap_next_state = tms ? `JTAG_EXIT1_IR : `JTAG_SHIFT_IR;
            `JTAG_EXIT1_IR: tap_next_state = tms ? `JTAG_UPDATE_IR : `JTAG_PAUSE_IR;
            `JTAG_PAUSE_IR: tap_next_state = tms ? `JTAG_EXIT2_IR : `JTAG_PAUSE_IR;
            `JTAG_EXIT2_IR: tap_next_state = tms ? `JTAG_UPDATE_IR : `JTAG_SHIFT_IR;
            `JTAG_UPDATE_IR: tap_next_state = tms ? `JTAG_SELECT_DR_SCAN : `JTAG_RUN_TEST_IDLE;
            default: tap_next_state = `JTAG_TEST_LOGIC_RESET;
        endcase
    end

    always @(posedge tck or negedge trst_n) begin
        if (!trst_n)
            tap_curr_state <= `JTAG_TEST_LOGIC_RESET;
        else
            tap_curr_state <= tap_next_state;
    end

endmodule
