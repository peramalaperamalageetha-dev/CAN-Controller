```verilog
`timescale 1ns/1ps

module can_controller_tb;

    // ============================================================
    // Clock and Reset
    // ============================================================

    reg clk;
    reg reset;

    // ============================================================
    // Transmit Interface
    // ============================================================

    reg        tx_start;
    reg [10:0] tx_id;
    reg [7:0]  tx_data;

    wire       can_tx;
    wire       tx_busy;
    wire       tx_done;

    // ============================================================
    // Receive Interface
    // ============================================================

    wire       can_rx;

    wire       rx_valid;
    wire [10:0] rx_id;
    wire [7:0]  rx_data;
    wire       rx_done;

    // ============================================================
    // CAN BUS LOOPBACK
    // ============================================================
    // For this simple simulation, the transmitted CAN signal
    // is connected directly to the receive input.

    assign can_rx = can_tx;

    // ============================================================
    // Error Counter
    // ============================================================

    integer errors;

    // ============================================================
    // DUT
    // ============================================================

    can_controller DUT (

        .clk       (clk),
        .reset     (reset),

        .tx_start  (tx_start),
        .tx_id     (tx_id),
        .tx_data   (tx_data),

        .can_tx    (can_tx),
        .tx_busy   (tx_busy),
        .tx_done   (tx_done),

        .can_rx    (can_rx),

        .rx_valid  (rx_valid),
        .rx_id     (rx_id),
        .rx_data   (rx_data),
        .rx_done   (rx_done)
    );

    // ============================================================
    // Clock Generation
    // 10 ns clock period
    // ============================================================

    initial begin

        clk = 1'b0;

        forever #5 clk = ~clk;

    end

    // ============================================================
    // Test Procedure
    // ============================================================

    initial begin

        errors = 0;

        // --------------------------------------------------------
        // Initial Values
        // --------------------------------------------------------

        reset    = 1'b1;

        tx_start = 1'b0;
        tx_id    = 11'h000;
        tx_data  = 8'h00;

        $display("");
        $display("================================================");
        $display("             CAN CONTROLLER TESTBENCH");
        $display("================================================");
        $display("");

        // ========================================================
        // RESET
        // ========================================================

        #20;

        reset = 1'b0;

        #20;

        $display("-----------------------------------------------");
        $display("RESET TEST");
        $display("-----------------------------------------------");

        if (tx_busy == 1'b0) begin

            $display("RESET TEST : PASS");

        end

        else begin

            $display("RESET TEST : FAIL");

            errors = errors + 1;

        end

        // ========================================================
        // TEST 1
        // CAN FRAME TRANSMISSION
        // ========================================================

        $display("");
        $display("-----------------------------------------------");
        $display("TEST 1 : CAN FRAME TRANSMISSION");
        $display("-----------------------------------------------");

        tx_id   = 11'h123;
        tx_data = 8'hA5;

        $display("TX Identifier = 0x%03h", tx_id);
        $display("TX Data       = 0x%02h", tx_data);

        tx_start = 1'b1;

        @(posedge clk);

        tx_start = 1'b0;

        // Wait until transmission is complete
        wait(tx_done == 1'b1);

        #10;

        $display("TX DONE = %b", tx_done);

        if (tx_done == 1'b1) begin

            $display("TRANSMISSION TEST : PASS");

        end

        else begin

            $display("TRANSMISSION TEST : FAIL");

            errors = errors + 1;

        end

        // ========================================================
        // TEST 2
        // CAN LOOPBACK RECEIVE
        // ========================================================

        $display("");
        $display("-----------------------------------------------");
        $display("TEST 2 : CAN LOOPBACK RECEIVE");
        $display("-----------------------------------------------");

        // Wait for receiver to complete
        wait(rx_done == 1'b1);

        #10;

        $display("RX Identifier = 0x%03h", rx_id);
        $display("RX Data       = 0x%02h", rx_data);

        if (rx_id == tx_id) begin

            $display("IDENTIFIER TEST : PASS");

        end

        else begin

            $display("IDENTIFIER TEST : FAIL");

            errors = errors + 1;

        end

        if (rx_data == tx_data) begin

            $display("DATA TEST : PASS");

        end

        else begin

            $display("DATA TEST : FAIL");

            errors = errors + 1;

        end

        // ========================================================
        // TEST 3
        // SECOND CAN FRAME
        // ========================================================

        #50;

        $display("");
        $display("-----------------------------------------------");
        $display("TEST 3 : SECOND CAN FRAME");
        $display("-----------------------------------------------");

        tx_id   = 11'h055;
        tx_data = 8'h3C;

        $display("TX Identifier = 0x%03h", tx_id);
        $display("TX Data       = 0x%02h", tx_data);

        tx_start = 1'b1;

        @(posedge clk);

        tx_start = 1'b0;

        wait(tx_done == 1'b1);

        #10;

        wait(rx_done == 1'b1);

        #10;

        $display("RX Identifier = 0x%03h", rx_id);
        $display("RX Data       = 0x%02h", rx_data);

        if (rx_id == tx_id) begin

            $display("SECOND ID TEST : PASS");

        end

        else begin

            $display("SECOND ID TEST : FAIL");

            errors = errors + 1;

        end

        if (rx_data == tx_data) begin

            $display("SECOND DATA TEST : PASS");

        end

        else begin

            $display("SECOND DATA TEST : FAIL");

            errors = errors + 1;

        end

        // ========================================================
        // FINAL RESULT
        // ========================================================

        #50;

        $display("");
        $display("================================================");

        if (errors == 0) begin

            $display("          CAN CONTROLLER TEST : PASS");
            $display("          ALL TESTS PASSED");

        end

        else begin

            $display("          CAN CONTROLLER TEST : FAIL");
            $display("          TOTAL ERRORS = %0d", errors);

        end

        $display("================================================");
        $display("");

        $finish;

    end

    // ============================================================
    // VCD Waveform Generation
    // ============================================================

    initial begin

        $dumpfile("can_waveform.vcd");

        $dumpvars(0, can_controller_tb);

    end

endmodule
```

### Tests included

```text
TEST 1 → Reset verification
TEST 2 → CAN frame transmission
TEST 3 → CAN loopback reception
TEST 4 → 11-bit identifier verification
TEST 5 → 8-bit data verification
TEST 6 → Second CAN frame
```

The testbench uses **CAN loopback**, connecting `can_tx` directly to `can_rx`, so the transmitted frame can be checked by the receiver. It also creates **`can_waveform.vcd`** for GTKWave.

