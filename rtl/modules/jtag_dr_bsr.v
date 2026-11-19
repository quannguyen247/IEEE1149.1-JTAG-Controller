`timescale 1ns / 1ps

module jtag_dr_bsr #(
    parameter integer BOUNDARY_WIDTH = 8
)(
    input wire tck,
    input wire trst_n,

    // Control signals from TAP controller & IR decoder
    input wire capture_dr,
    input wire shift_dr,
    input wire update_dr,
    input wire select_extest,

    // Serial scan interface
    input wire serial_in,
    output wire serial_out,

    // System I/O and core interface
    input wire [BOUNDARY_WIDTH-1:0] pin_in,
    input wire [BOUNDARY_WIDTH-1:0] core_out,
    output wire [BOUNDARY_WIDTH-1:0] pin_out
);

    // Internal signals
    wire [2*BOUNDARY_WIDTH:0] scan_chain;
    wire [BOUNDARY_WIDTH-1:0] preload_out;
    wire [BOUNDARY_WIDTH-1:0] unused_input_update;
    wire unused_ok = &{1'b0, unused_input_update};

    // Connect serial scan path
    assign scan_chain[2*BOUNDARY_WIDTH] = serial_in;
    assign serial_out = scan_chain[0];

    // Output mux: EXTEST drives preload_out, otherwise core_out
    assign pin_out = select_extest ? preload_out : core_out;

    genvar i;
    generate
        for (i = 0; i < BOUNDARY_WIDTH; i = i + 1) begin : g_cell
            jtag_dr_bsr_cell u_input (
                .tck(tck),
                .trst_n(trst_n),
                .capture_dr(capture_dr),
                .shift_dr(shift_dr),
                .update_dr(1'b0),
                .capture_value(pin_in[i]),
                .serial_in(scan_chain[i+1]),
                .serial_out(scan_chain[i]),
                .update_value(unused_input_update[i])
            );

            jtag_dr_bsr_cell u_output (
                .tck(tck),
                .trst_n(trst_n),
                .capture_dr(capture_dr),
                .shift_dr(shift_dr),
                .update_dr(update_dr),
                .capture_value(pin_out[i]),
                .serial_in(scan_chain[BOUNDARY_WIDTH+i+1]),
                .serial_out(scan_chain[BOUNDARY_WIDTH+i]),
                .update_value(preload_out[i])
            );
        end
    endgenerate

endmodule
