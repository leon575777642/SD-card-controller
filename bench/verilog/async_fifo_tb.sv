`timescale 1ns/1ps

// fast-write, slow-read testbench
module async_fifo_tb;

    parameter T_WR_CLK = 20;    // 50 MHz -> timescale 1ns
    parameter T_RD_CLK = 203;   // 4.98 MHz -> timescale 1ns

    localparam WIDTH = 8;
    localparam DEPTH_LOG2 = 2;

    reg                 rst;

    reg                 wr_clk;
    reg                 wr_en;
    reg  [WIDTH - 1:0]  din;
    wire                full;

    reg                 rd_clk;
    reg                 rd_en;
    wire [WIDTH - 1:0]  dout;
    wire                empty;

    async_fifo #(
        .WIDTH(WIDTH)
        ,.DEPTH_LOG2(DEPTH_LOG2)
    ) dut (
        .rst(rst)
        ,.wr_clk(wr_clk)
        ,.wr_en(wr_en)
        ,.din(din)
        ,.full(full)
        ,.rd_clk(rd_clk)
        ,.rd_en(rd_en)
        ,.dout(dout)
        ,.empty(empty)
        );

    reg [4:0] wr_ptr, rd_ptr;
    reg [WIDTH - 1:0]  sink[31:0];

    localparam STATE_INIT = 3'd0;
    localparam STATE_WRITE_N_READ = 3'd1;
    localparam STATE_WRITE_TIL_FULL = 3'd2;
    localparam STATE_READ_TIL_EMPTY = 3'd3;
    localparam STATE_RAND_WRITE_PROMPT_READ = 3'd4;
    localparam STATE_PROMPT_WRITE_RAND_READ = 3'd5;
    localparam STATE_DONE = 3'd6;
    reg [2:0] state;

    always #(T_WR_CLK/2) wr_clk = ~wr_clk;
    always #(T_RD_CLK/2) rd_clk = ~rd_clk;

    initial
    begin
        wr_clk = 0;
        rd_clk = 0;
        rst = 1;

        sink[0]  = 8'h4f; sink[1]  = 8'h46; sink[2]  = 8'h6e; sink[3]  = 8'h2c;
        sink[4]  = 8'h75; sink[5]  = 8'h14; sink[6]  = 8'h07; sink[7]  = 8'h62;
        sink[8]  = 8'h75; sink[9]  = 8'h4f; sink[10] = 8'h40; sink[11] = 8'h2;
        sink[12] = 8'h0e; sink[13] = 8'h64; sink[14] = 8'h33; sink[15] = 8'h38;
        sink[16] = 8'h3d; sink[17] = 8'h1b; sink[18] = 8'h38; sink[19] = 8'h52;
        sink[20] = 8'h61; sink[21] = 8'h0a; sink[22] = 8'h79; sink[23] = 8'h4d;
        sink[24] = 8'h03; sink[25] = 8'h0b; sink[26] = 8'h80; sink[27] = 8'h6b;
        sink[28] = 8'h19; sink[29] = 8'h26; sink[30] = 8'h7b; sink[31] = 8'h17;

        $display("async_fifo_tb start ...");

        #(2 * T_WR_CLK + 2 * T_RD_CLK + 71.48);     // random delay
        rst = 0;
    end

    always @(posedge wr_clk or posedge rst) begin
        if (rst) begin
            wr_ptr  <= 0;
            wr_en   <= 0;
            din     <= 0;
        end else begin
            case (state)
                STATE_WRITE_N_READ,
                STATE_WRITE_TIL_FULL,
                STATE_PROMPT_WRITE_RAND_READ: begin
                    if (!wr_en && !full) begin
                        wr_ptr  <=  wr_ptr + 1;
                        wr_en   <=  1'b1;
                        din     <=  sink[wr_ptr];
                    end else begin
                        wr_en   <=  1'b0;
                    end
                end
                STATE_RAND_WRITE_PROMPT_READ: begin
                    if (!wr_en && !full && ($urandom() % 100 > 50)) begin
                        wr_ptr  <=  wr_ptr + 1;
                        wr_en   <=  1'b1;
                        din     <=  sink[wr_ptr];
                    end else begin
                        wr_en   <=  1'b0;
                    end
                end
                default:
                    wr_en   <= 1'b0;
            endcase
        end
    end

    reg rd_en_f;
    reg [WIDTH - 1:0] rd_expected, rd_expected_f;
    reg [4:0] prev_rd_ptr;
    always @(posedge rd_clk or posedge rst) begin
        if (rst) begin
            rd_ptr  <= 0;
            rd_en   <= 0;
            rd_en_f <= 0;
            rd_expected <= 0;
            rd_expected_f <= 0;
            state   <= STATE_INIT;
            prev_rd_ptr <= 0;
        end else begin
            case (state)
                STATE_WRITE_N_READ,
                STATE_READ_TIL_EMPTY,
                STATE_RAND_WRITE_PROMPT_READ: begin
                    if (!rd_en && !empty) begin
                        rd_ptr  <=  rd_ptr + 1;
                        rd_en   <=  1'b1;
                        rd_expected   <=  sink[rd_ptr];
                    end else begin
                        rd_en   <=  1'b0;
                    end
                end
                STATE_PROMPT_WRITE_RAND_READ: begin
                    if (!rd_en && !empty && ($urandom() % 100 > 50)) begin
                        rd_ptr  <=  rd_ptr + 1;
                        rd_en   <=  1'b1;
                        rd_expected   <=  sink[rd_ptr];
                    end else begin
                        rd_en   <=  1'b0;
                    end
                end
                default:
                    rd_en   <= 1'b0;
            endcase

            rd_en_f         <= rd_en;
            rd_expected_f   <= rd_expected;

            if (rd_en_f && (rd_expected_f != dout)) begin
                assert(0);
                $display("%t state: %s, expected dout: 0x%h, actual dout: 0x%h, wr_ptr: %d, rd_ptr, %d",
                    $time,                    
                    state == STATE_INIT ? "STATE_INIT" :
                            state == STATE_WRITE_N_READ ? "STATE_WRITE_N_READ" :
                            state == STATE_WRITE_TIL_FULL ? "STATE_WRITE_TIL_FULL" :
                            state == STATE_READ_TIL_EMPTY ? "STATE_READ_TIL_EMPTY" :
                            state == STATE_RAND_WRITE_PROMPT_READ ? "STATE_RAND_WRITE_PROMPT_READ" :
                            state == STATE_PROMPT_WRITE_RAND_READ ? "STATE_PROMPT_WRITE_RAND_READ" :
                            state == STATE_DONE ? "STATE_DONE" : "UNKNOWN",
                    rd_expected_f, dout, wr_ptr, rd_ptr);
            end

            case (state)
                STATE_INIT:
                    state <= STATE_WRITE_N_READ;
                STATE_WRITE_N_READ:
                    if (rd_ptr == 8) begin
                        state <= STATE_WRITE_TIL_FULL;
                    end
                STATE_WRITE_TIL_FULL:
                    if (full) begin
                        state <= STATE_READ_TIL_EMPTY;
                    end
                STATE_READ_TIL_EMPTY:
                    if (empty) begin
                        state <= STATE_RAND_WRITE_PROMPT_READ;
                        prev_rd_ptr <= rd_ptr;
                    end
                STATE_RAND_WRITE_PROMPT_READ:
                    if (prev_rd_ptr - 1 == rd_ptr) begin
                        state <= STATE_PROMPT_WRITE_RAND_READ;
                        prev_rd_ptr <= rd_ptr;
                    end
                STATE_PROMPT_WRITE_RAND_READ:
                    if (prev_rd_ptr - 1 == rd_ptr) begin
                        state <= STATE_DONE;
                    end
                STATE_DONE: begin
                    $display("async_fifo_tb finish ...");
                    $finish;
                end
            endcase
        end
    end

endmodule
