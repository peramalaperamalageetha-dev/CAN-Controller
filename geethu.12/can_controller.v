```verilog
`timescale 1ns/1ps

module can_controller (
    input  wire        clk,
    input  wire        reset,

    // -------------------------------
    // Transmit Interface
    // -------------------------------
    input  wire        tx_start,
    input  wire [10:0] tx_id,
    input  wire [7:0]  tx_data,

    output reg         can_tx,
    output reg         tx_busy,
    output reg         tx_done,

    // -------------------------------
    // Receive Interface
    // -------------------------------
    input  wire        can_rx,

    output reg         rx_valid,
    output reg [10:0]  rx_id,
    output reg [7:0]   rx_data,
    output reg         rx_done
);

    // ============================================================
    // CAN Controller Parameters
    // ============================================================

    localparam TX_IDLE = 3'd0;
    localparam TX_SOF  = 3'd1;
    localparam TX_ID   = 3'd2;
    localparam TX_DLC  = 3'd3;
    localparam TX_DATA = 3'd4;
    localparam TX_CRC  = 3'd5;
    localparam TX_ACK  = 3'd6;
    localparam TX_EOF  = 3'd7;

    // ============================================================
    // Transmit Registers
    // ============================================================

    reg [2:0]  tx_state;
    reg [10:0] id_reg;
    reg [7:0]  data_reg;

    reg [4:0]  bit_count;
    reg [3:0]  data_count;

    reg [7:0]  crc_reg;

    // ============================================================
    // Receive Registers
    // ============================================================

    reg [3:0]  rx_state;
    reg [4:0]  rx_bit_count;

    reg [10:0] rx_id_reg;
    reg [7:0]  rx_data_reg;

    reg [7:0]  rx_crc;
    reg [7:0]  rx_crc_received;

    // ============================================================
    // Receive State Machine
    // ============================================================

    localparam RX_IDLE = 4'd0;
    localparam RX_ID   = 4'd1;
    localparam RX_DLC  = 4'd2;
    localparam RX_DATA = 4'd3;
    localparam RX_CRC  = 4'd4;
    localparam RX_ACK  = 4'd5;
    localparam RX_EOF  = 4'd6;

    // ============================================================
    // CRC-8 Function
    // Polynomial = x^8 + x^2 + x + 1
    // ============================================================

    function [7:0] crc8_next;
        input [7:0] crc;
        input       data_bit;

        reg feedback;

        begin

            feedback = crc[7] ^ data_bit;

            crc8_next[7] = crc[6];
            crc8_next[6] = crc[5];
            crc8_next[5] = crc[4];
            crc8_next[4] = crc[3];
            crc8_next[3] = crc[2];
            crc8_next[2] = crc[1] ^ feedback;
            crc8_next[1] = crc[0] ^ feedback;
            crc8_next[0] = feedback;

        end
    endfunction

    // ============================================================
    // CAN TRANSMITTER
    // ============================================================

    always @(posedge clk or posedge reset) begin

        if (reset) begin

            can_tx    <= 1'b1;
            tx_busy   <= 1'b0;
            tx_done   <= 1'b0;

            tx_state  <= TX_IDLE;

            id_reg    <= 11'b0;
            data_reg  <= 8'b0;

            bit_count <= 0;
            data_count <= 0;

            crc_reg   <= 8'b0;

        end

        else begin

            tx_done <= 1'b0;

            case (tx_state)

                // ------------------------------------------------
                // IDLE
                // ------------------------------------------------

                TX_IDLE: begin

                    can_tx  <= 1'b1;
                    tx_busy <= 1'b0;

                    if (tx_start) begin

                        tx_busy <= 1'b1;

                        id_reg   <= tx_id;
                        data_reg <= tx_data;

                        crc_reg <= 8'h00;

                        bit_count  <= 10;
                        data_count <= 0;

                        tx_state <= TX_SOF;

                    end

                end

                // ------------------------------------------------
                // START OF FRAME
                // CAN dominant bit = 0
                // ------------------------------------------------

                TX_SOF: begin

                    can_tx <= 1'b0;

                    tx_state <= TX_ID;

                end

                // ------------------------------------------------
                // 11-bit Identifier
                // MSB first
                // ------------------------------------------------

                TX_ID: begin

                    can_tx <= id_reg[bit_count];

                    crc_reg <= crc8_next(
                        crc_reg,
                        id_reg[bit_count]
                    );

                    if (bit_count == 0) begin

                        bit_count <= 3;

                        tx_state <= TX_DLC;

                    end

                    else begin

                        bit_count <= bit_count - 1'b1;

                    end

                end

                // ------------------------------------------------
                // DLC = 1 byte
                // 0001
                // ------------------------------------------------

                TX_DLC: begin

                    can_tx <= (bit_count == 0) ? 1'b1 : 1'b0;

                    crc_reg <= crc8_next(
                        crc_reg,
                        (bit_count == 0) ? 1'b1 : 1'b0
                    );

                    if (bit_count == 0) begin

                        bit_count <= 7;

                        tx_state <= TX_DATA;

                    end

                    else begin

                        bit_count <= bit_count - 1'b1;

                    end

                end

                // ------------------------------------------------
                // 8-bit Data
                // ------------------------------------------------

                TX_DATA: begin

                    can_tx <= data_reg[bit_count];

                    crc_reg <= crc8_next(
                        crc_reg,
                        data_reg[bit_count]
                    );

                    if (bit_count == 0) begin

                        bit_count <= 7;

                        tx_state <= TX_CRC;

                    end

                    else begin

                        bit_count <= bit_count - 1'b1;

                    end

                end

                // ------------------------------------------------
                // CRC-8
                // ------------------------------------------------

                TX_CRC: begin

                    can_tx <= crc_reg[bit_count];

                    if (bit_count == 0) begin

                        tx_state <= TX_ACK;

                    end

                    else begin

                        bit_count <= bit_count - 1'b1;

                    end

                end

                // ------------------------------------------------
                // ACK Slot
                // Receiver drives dominant 0
                //
                // This simplified controller generates
                // a dominant ACK for demonstration.
                // ------------------------------------------------

                TX_ACK: begin

                    can_tx <= 1'b0;

                    tx_state <= TX_EOF;

                    bit_count <= 6;

                end

                // ------------------------------------------------
                // End Of Frame
                // 7 recessive bits
                // ------------------------------------------------

                TX_EOF: begin

                    can_tx <= 1'b1;

                    if (bit_count == 0) begin

                        tx_busy <= 1'b0;
                        tx_done <= 1'b1;

                        tx_state <= TX_IDLE;

                    end

                    else begin

                        bit_count <= bit_count - 1'b1;

                    end

                end

                default: begin

                    tx_state <= TX_IDLE;
                    can_tx   <= 1'b1;
                    tx_busy  <= 1'b0;

                end

            endcase

        end

    end

    // ============================================================
    // CAN RECEIVER
    // ============================================================

    always @(posedge clk or posedge reset) begin

        if (reset) begin

            rx_state <= RX_IDLE;

            rx_bit_count <= 0;

            rx_id_reg   <= 0;
            rx_data_reg <= 0;

            rx_crc <= 0;
            rx_crc_received <= 0;

            rx_id   <= 0;
            rx_data <= 0;

            rx_valid <= 1'b0;
            rx_done  <= 1'b0;

        end

        else begin

            rx_valid <= 1'b0;
            rx_done  <= 1'b0;

            case (rx_state)

                // ------------------------------------------------
                // Wait for Start Of Frame
                // ------------------------------------------------

                RX_IDLE: begin

                    if (can_rx == 1'b0) begin

                        rx_bit_count <= 10;

                        rx_crc <= 8'h00;

                        rx_state <= RX_ID;

                    end

                end

                // ------------------------------------------------
                // Receive Identifier
                // ------------------------------------------------

                RX_ID: begin

                    rx_id_reg[rx_bit_count] <= can_rx;

                    rx_crc <= crc8_next(
                        rx_crc,
                        can_rx
                    );

                    if (rx_bit_count == 0) begin

                        rx_bit_count <= 3;

                        rx_state <= RX_DLC;

                    end

                    else begin

                        rx_bit_count <= rx_bit_count - 1'b1;

                    end

                end

                // ------------------------------------------------
                // Receive DLC
                // ------------------------------------------------

                RX_DLC: begin

                    rx_crc <= crc8_next(
                        rx_crc,
                        can_rx
                    );

                    if (rx_bit_count == 0) begin

                        rx_bit_count <= 7;

                        rx_state <= RX_DATA;

                    end

                    else begin

                        rx_bit_count <= rx_bit_count - 1'b1;

                    end

                end

                // ------------------------------------------------
                // Receive Data
                // ------------------------------------------------

                RX_DATA: begin

                    rx_data_reg[rx_bit_count] <= can_rx;

                    rx_crc <= crc8_next(
                        rx_crc,
                        can_rx
                    );

                    if (rx_bit_count == 0) begin

                        rx_bit_count <= 7;

                        rx_state <= RX_CRC;

                    end

                    else begin

                        rx_bit_count <= rx_bit_count - 1'b1;

                    end

                end

                // ------------------------------------------------
                // Receive CRC
                // ------------------------------------------------

                RX_CRC: begin

                    rx_crc_received[rx_bit_count] <= can_rx;

                    if (rx_bit_count == 0) begin

                        rx_state <= RX_ACK;

                    end

                    else begin

                        rx_bit_count <= rx_bit_count - 1'b1;

                    end

                end

                // ------------------------------------------------
                // ACK
                // ------------------------------------------------

                RX_ACK: begin

                    rx_state <= RX_EOF;

                    rx_bit_count <= 6;

                end

                // ------------------------------------------------
                // End Of Frame
                // ------------------------------------------------

                RX_EOF: begin

                    if (rx_bit_count == 0) begin

                        rx_id   <= rx_id_reg;
                        rx_data <= rx_data_reg;

                        rx_valid <= 1'b1;
                        rx_done  <= 1'b1;

                        rx_state <= RX_IDLE;

                    end

                    else begin

                        rx_bit_count <= rx_bit_count - 1'b1;

                    end

                end

                default: begin

                    rx_state <= RX_IDLE;

                end

            endcase

        end

    end

endmodule
```
