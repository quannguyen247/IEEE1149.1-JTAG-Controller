`timescale 1ns / 1ps
`include "jtag_defs.vh"

module jtag_top_tb;

    // Testbench parameters
    parameter integer BOUNDARY_WIDTH = 8;
    localparam integer BSR_BITS   = 2 * BOUNDARY_WIDTH;
    localparam integer MAX_BITS   = (BSR_BITS > 32) ? BSR_BITS : 32;
    localparam integer NUM_TESTS  = 8;
    localparam integer TIMEOUT_NS = 2000000;

    // JTAG TAP interface
    reg  tck, tms, tdi, trst_n;
    wire tdo, tdo_oe;

    // System I/O and core interface
    reg  [BOUNDARY_WIDTH-1:0] pin_in, core_out;
    wire [BOUNDARY_WIDTH-1:0] pin_out;

    // Reference model and test counters
    reg [`JTAG_IR_WIDTH-1:0] ir_ref;
    reg [BOUNDARY_WIDTH-1:0] preload_ref;
    reg tdo_bit;
    integer test_idx, pass_count, error_count, test_errors, check_count, report_fd, opcode;

    // DUT instance
    jtag_top #(
        .BOUNDARY_WIDTH(BOUNDARY_WIDTH)
    ) u_dut (
        .tck(tck),
        .tms(tms),
        .tdi(tdi),
        .tdo(tdo),
        .tdo_oe(tdo_oe),
        .trst_n(trst_n),
        .pin_in(pin_in),
        .core_out(core_out),
        .pin_out(pin_out)
    );

    // 50 MHz TCK clock (20 ns period)
    initial begin
        tck = 1'b0;
        forever #10 tck = ~tck;
    end

    // Verify TDO and tdo_oe only change on falling TCK
    always @(tdo or tdo_oe) begin
        if (trst_n && tck !== 1'b0) begin
            $display("[%0t] FAIL: TDO changed outside falling TCK", $time);
            error_count = error_count + 1;
        end
    end

    // Check pin_out muxing and active IR against reference model
    task check_outputs;
        begin
            check_count = check_count + 1;
            if (pin_out !== ((ir_ref == `JTAG_IR_EXTEST) ? preload_ref : core_out)) begin
                $display("[%0t] FAIL: pin_out %h, IR %h", $time, pin_out, ir_ref);
                error_count = error_count + 1;
            end
            if (u_dut.instruction !== ir_ref) begin
                $display("[%0t] FAIL: Active IR %h, expected %h", $time, u_dut.instruction, ir_ref);
                error_count = error_count + 1;
            end
        end
    endtask

    // Drive TMS/TDI on falling edge, sample TDO and check it holds across rising edge (one TCK cycle)
    task tick(input t, input data_in);
        reg held_tdo, held_oe, exp_oe;
        begin
            @(negedge tck);
            tms = t;
            tdi = data_in;
            #1;
            if (u_dut.tap_curr_state == `JTAG_TEST_LOGIC_RESET)
                ir_ref = `JTAG_IR_BYPASS;
            exp_oe = (u_dut.tap_curr_state == `JTAG_SHIFT_DR) || (u_dut.tap_curr_state == `JTAG_SHIFT_IR);
            if (tdo_oe !== exp_oe) begin
                $display("[%0t] FAIL: TDO enable in state %h", $time, u_dut.tap_curr_state);
                error_count = error_count + 1;
            end
            tdo_bit = tdo;
            held_tdo = tdo;
            held_oe = tdo_oe;
            @(posedge tck);
            #1;
            if (tdo !== held_tdo || tdo_oe !== held_oe) begin
                $display("[%0t] FAIL: TDO changed on rising TCK, state %h", $time, u_dut.tap_curr_state);
                error_count = error_count + 1;
            end
            check_outputs;
        end
    endtask

    // Pulse TRST_N low and move to Run-Test/Idle
    task reset_async;
        begin
            #2 trst_n = 1'b0;
            ir_ref = `JTAG_IR_BYPASS;
            preload_ref = 0;
            #1;
            if (u_dut.tap_curr_state !== `JTAG_TEST_LOGIC_RESET || tdo_oe !== 1'b0 || tdo !== 1'b0) begin
                $display("[%0t] FAIL: TRST_N did not reset TAP/TDO", $time);
                error_count = error_count + 1;
            end
            check_outputs;
            tms = 1'b1;
            @(negedge tck);
            #1 trst_n = 1'b1;
            tick(1'b0, 1'b0);
        end
    endtask

    // Move from Run-Test/Idle to Shift-DR (0) or Shift-IR (1)
    task enter_shift(input ir_scan);
        begin
            tick(1'b1, 1'b0);
            if (ir_scan)
                tick(1'b1, 1'b0);
            tick(1'b0, 1'b0);
            tick(1'b0, 1'b0);
        end
    endtask

    // Exit1 -> Pause (4 cycles) -> Exit2 -> Shift
    task pause_resume;
        begin
            repeat (4) tick(1'b0, 1'b0);
            tick(1'b1, 1'b0);
            tick(1'b0, 1'b0);
        end
    endtask

    // Exit1 -> Update (verify falling-edge update) -> Run-Test/Idle
    task finish_scan(input is_ir, input [`JTAG_IR_WIDTH-1:0] next_ir, input [BOUNDARY_WIDTH-1:0] next_preload);
        begin
            tick(1'b1, 1'b0);
            @(negedge tck);
            tms = 1'b0;
            tdi = 1'b0;
            #1;
            if (is_ir)
                ir_ref = next_ir;
            else if (ir_ref == `JTAG_IR_EXTEST || ir_ref == `JTAG_IR_SAMPLE_PRELOAD)
                preload_ref = next_preload;
            check_outputs;
            if (tdo_oe !== 1'b0) begin
                $display("[%0t] FAIL: TDO enabled in Update state", $time);
                error_count = error_count + 1;
            end
            @(posedge tck);
            #1 check_outputs;
        end
    endtask

    // Shift a 4-bit instruction into IR and check Capture-IR == 4'b0001
    task scan_ir(input [`JTAG_IR_WIDTH-1:0] new_ir, input with_pause);
        reg [`JTAG_IR_WIDTH-1:0] ir_capture;
        integer k;
        begin
            enter_shift(1'b1);
            for (k = 0; k < `JTAG_IR_WIDTH; k = k + 1) begin
                tick((k == `JTAG_IR_WIDTH - 1) || (with_pause && k == 1), new_ir[k]);
                ir_capture[k] = tdo_bit;
                if (with_pause && k == 1)
                    pause_resume;
            end
            if (ir_capture !== `JTAG_IR_CAPTURE) begin
                $display("[%0t] FAIL: Capture-IR %b, expected 0001", $time, ir_capture);
                error_count = error_count + 1;
            end
            finish_scan(1'b1, new_ir, preload_ref);
        end
    endtask

    // Shift bit_count bits through selected DR and verify captured TDO data
    task scan_dr(
        input integer bit_count,
        input [MAX_BITS-1:0] wr_data,
        input [MAX_BITS-1:0] exp_data,
        input with_pause
    );
        reg [MAX_BITS-1:0] rd_data;
        integer k;
        begin
            rd_data = 0;
            enter_shift(1'b0);
            for (k = 0; k < bit_count; k = k + 1) begin
                tick((k == bit_count - 1) || (with_pause && k == bit_count / 2 - 1), wr_data[k]);
                rd_data[k] = tdo_bit;
                if (with_pause && k == bit_count / 2 - 1) begin
                    core_out = ~core_out; pin_in = ~pin_in; #1 check_outputs;
                    pause_resume;
                    core_out = ~core_out; pin_in = ~pin_in; #1 check_outputs;
                end
            end
            finish_scan(1'b0, ir_ref, wr_data[BOUNDARY_WIDTH +: BOUNDARY_WIDTH]);
            check_count = check_count + 1;
            for (k = 0; k < bit_count; k = k + 1)
                if (rd_data[k] !== exp_data[k]) begin
                    $display("[%0t] FAIL: Scan bit %0d = %b, expected %b, IR %h", $time, k, rd_data[k], exp_data[k], ir_ref);
                    error_count = error_count + 1;
                end
        end
    endtask

    // Log test result and update pass counter
    task end_test(input [8*48-1:0] name);
        begin
            if (error_count == test_errors)
                pass_count = pass_count + 1;
            if (report_fd != 0)
                $fwrite(report_fd, "Test %0d - %0s | %s\n", test_idx, name, (error_count == test_errors) ? "PASS" : "FAIL");
            test_idx = test_idx + 1;
            test_errors = error_count;
        end
    endtask

    // Simulation watchdog timer
    initial begin
        #TIMEOUT_NS;
        $display("[%0t] FAIL: Timeout", $time);
        if (report_fd != 0) $fclose(report_fd);
        $fatal(1, "JTAG TOP simulation timed out");
    end

    // Main test sequence
    initial begin
        report_fd = $fopen("testbench/jtag_top_result.log", "w");
        if (report_fd == 0)
            report_fd = $fopen("jtag_top_result.log", "w");

        trst_n = 1'b1; tms = 1'b1; tdi = 1'b0;
        pin_in = 'h3C; core_out = 'hA5;
        ir_ref = `JTAG_IR_BYPASS; preload_ref = 0; tdo_bit = 1'b0;
        test_idx = 1; pass_count = 0; error_count = 0; test_errors = 0; check_count = 0;

        // Test 1: Default BYPASS after reset (captures 0, 1-bit delay)
        reset_async;
        scan_dr(17, 'h1A5D3, 'h1A5D3 << 1, 1'b1);
        scan_dr(17, 'h0F391, 'h0F391 << 1, 1'b0);
        end_test("Default BYPASS after reset, pause and recapture");

        // Test 2: Opcodes 0x2..0xF select BYPASS (Pause-IR/Pause-DR on 0xF)
        for (opcode = 2; opcode < 16; opcode = opcode + 1) begin
            scan_ir(opcode[`JTAG_IR_WIDTH-1:0], opcode == 15);
            scan_dr(17, 'h16B5D, 'h16B5D << 1, opcode == 15);
        end
        end_test("BYPASS and unknown opcodes");

        // Test 3: SAMPLE/PRELOAD captures pins and preloads BSR, pin_out follows core_out
        scan_ir(`JTAG_IR_SAMPLE_PRELOAD, 1'b0);
        scan_dr(BSR_BITS, {~core_out, {BOUNDARY_WIDTH{1'b0}}}, {core_out, pin_in}, 1'b1);
        core_out = ~core_out; #1 check_outputs;
        core_out = ~core_out;
        end_test("SAMPLE/PRELOAD capture and preload");

        // Test 4: EXTEST drives preload on Update-IR and updates on Update-DR
        scan_ir(`JTAG_IR_EXTEST, 1'b0);
        core_out = ~preload_ref; pin_in = ~pin_in; #1 check_outputs;
        scan_dr(BSR_BITS, {~preload_ref, {BOUNDARY_WIDTH{1'b0}}}, {pin_out, pin_in}, 1'b1);
        end_test("EXTEST drive and update");

        // Test 5: Partial shift leaves pin_out steady; TRST_N resets to BYPASS
        enter_shift(1'b0);
        tick(1'b0, 1'b1);
        check_outputs;
        reset_async;
        scan_dr(17, 'h13579, 'h13579 << 1, 1'b0);
        end_test("TRST_N during a partial shift");

        // Test 6: Five TMS=1 cycles reset TAP from EXTEST to BYPASS
        scan_ir(`JTAG_IR_EXTEST, 1'b0);
        repeat (5) tick(1'b1, 1'b0);
        tick(1'b0, 1'b0);
        scan_dr(17, 'h1C2E5, 'h1C2E5 << 1, 1'b0);
        end_test("TMS reset from EXTEST");

        // Test 7: Remaining TAP FSM paths
        repeat (2) tick(1'b0, 1'b0);              // Run-Test/Idle hold
        tick(1'b1, 1'b0); tick(1'b0, 1'b0);       // Select-DR -> Capture-DR
        tick(1'b1, 1'b0); tick(1'b0, 1'b0);       // Exit1-DR -> Pause-DR
        tick(1'b1, 1'b0); tick(1'b1, 1'b0);       // Exit2-DR -> Update-DR
        tick(1'b1, 1'b0); tick(1'b1, 1'b0);       // Select-DR -> Select-IR
        tick(1'b0, 1'b0); tick(1'b1, 1'b0);       // Capture-IR -> Exit1-IR
        tick(1'b0, 1'b0); tick(1'b1, 1'b0);       // Pause-IR -> Exit2-IR
        tick(1'b1, 1'b0);                         // Update-IR loads captured 0001
        ir_ref = `JTAG_IR_SAMPLE_PRELOAD;
        tick(1'b1, 1'b0); tick(1'b1, 1'b0);       // Select-DR -> Select-IR
        tick(1'b1, 1'b0); tick(1'b0, 1'b0);       // Test-Logic-Reset -> Run-Test/Idle
        end_test("TAP FSM path coverage");

        // Test 8: Preload is kept when leaving and re-entering EXTEST
        scan_ir(`JTAG_IR_SAMPLE_PRELOAD, 1'b0);
        scan_dr(BSR_BITS, {MAX_BITS{1'b1}}, {core_out, pin_in}, 1'b0);
        scan_ir(`JTAG_IR_EXTEST, 1'b0);
        scan_ir(`JTAG_IR_BYPASS, 1'b0);
        core_out = 0; #1 check_outputs;
        scan_ir(`JTAG_IR_EXTEST, 1'b0);
        check_outputs;
        end_test("Preload kept across instructions");

        if (report_fd != 0) $fclose(report_fd);
        if (error_count == 0 && pass_count == NUM_TESTS) begin
            $display("JTAG TOP PASSED: %0d/%0d TESTS, %0d CHECKS (%0d ERRORS), BOUNDARY_WIDTH=%0d",
                     pass_count, NUM_TESTS, check_count, error_count, BOUNDARY_WIDTH);
            $finish;
        end else begin
            $display("JTAG TOP FAILED: %0d/%0d TESTS, %0d CHECKS (%0d ERRORS), BOUNDARY_WIDTH=%0d",
                     pass_count, NUM_TESTS, check_count, error_count, BOUNDARY_WIDTH);
            $fatal(1, "JTAG TOP testbench failed");
        end
    end

endmodule
