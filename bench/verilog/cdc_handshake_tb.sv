`timescale 1ns/1ps

module cdc_handshake_tb;

    parameter T_SRC_CLK = 20;   // 50 MHz -> timescale 1ns
    parameter T_DST_CLK = 203;  // 4.98 MHz -> timescale 1ns

    localparam WIDTH = 8;

    reg                 rst;

    reg                 src_clk;
    reg  [WIDTH - 1:0]  src;
    reg                 src_val;
    wire                src_ack;

    reg                 dst_clk;
    wire [WIDTH - 1:0]  dst;
    wire                dst_val;
    reg                 dst_ack;

    cdc_handshake #(
        .WIDTH(WIDTH)
    ) dut (
        .rst(rst)
        ,.src_clk(src_clk)
        ,.src(src)
        ,.src_val(src_val)
        ,.src_ack(src_ack)
        ,.dst_clk(dst_clk)
        ,.dst(dst)
        ,.dst_val(dst_val)
        ,.dst_ack(dst_ack)
        );

    reg [2:0] src_ptr, dst_ptr;
    reg [WIDTH - 1:0]  sink[3:0];

    always #(T_SRC_CLK/2) src_clk = ~src_clk;
    always #(T_DST_CLK/2) dst_clk = ~dst_clk;

    initial
    begin
        src_clk = 0;
        dst_clk = 0;
        rst = 1;

        sink[0]  = 8'h4f; sink[1]  = 8'h46; sink[2]  = 8'h6e; sink[3]  = 8'h2c;

        $display("cdc_handshake_tb start ...");

        #(2 * T_SRC_CLK + 2 * T_DST_CLK + 71.48);     // random delay
        rst = 0;
    end

    always @(posedge src_clk or posedge rst) begin
        if (rst) begin
            src_ptr <= 0;
            src     <= 0;
            src_val <= 0;
        end else begin
            if (src_ptr == 0) begin
                src_ptr <= 1;
                src     <= sink[src_ptr];
                src_val <= 1;
            end else if (src_ptr < 4) begin
                if (src_ack) begin
                    src_ptr <= src_ptr + 1;
                    src     <= sink[src_ptr];
                    src_val <= 1;
                end else begin
                    src_val <= 0;
                end
            end
        end
    end

    always @(posedge dst_clk or posedge rst) begin
        if (rst) begin
            dst_ptr <= 0;
            dst_ack <= 0;
        end else begin
            if (!dst_ack && dst_val) begin
                dst_ptr <= dst_ptr + 1;
                dst_ack <= 1;

                if (dst != sink[dst_ptr]) begin
                    assert (0);
                    $display("%t expected dst: 0x%h, actual dst: 0x%h",
                        $time, sink[dst_ptr], dst);
                end
            end else begin
                dst_ack <= 0;
            end

            if (dst_ptr == 4) begin
                $display("cdc_handshake_tb finish ...");
                $finish;
            end
        end
    end

endmodule
