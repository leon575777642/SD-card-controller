// Cross-domain synchronizer
//  - if WIDTH is greater than 1, the bits are independently synced. do not use
//      this directly for bus signals.
module cdc_bits (
    src_clk, src,
    dst_clk, dst
    );

    parameter WIDTH = 1;

    input  wire                 src_clk;
    input  wire [WIDTH - 1:0]   src;

    input  wire                 dst_clk;
    output wire [WIDTH - 1:0]   dst;

`ifdef USE_XILINX_XPM
    xpm_cdc_array_single #(
        .DEST_SYNC_FF(4)
        ,.WIDTH(WIDTH)
        ,.SRC_INPUT_REG(1)
    ) xpm_cdc_array_single_inst (
        .src_clk(src_clk)
        ,.src_in(src)
        ,.dest_clk(dst_clk)
        ,.dest_out(dst)
        );
`else
    reg [WIDTH - 1:0]   dst_f;
    assign dst = dst_f;

    genvar i;
    generate for (i = 0; i < WIDTH; i = i + 1) begin: cdc_bit
        reg bit_f[3:0];   // 4-stage synchronizer

        always @(posedge src_clk) begin
            bit_f[0]    <=  src[i];
        end

        always @(posedge dst_clk) begin
            bit_f[1]    <=  bit_f[0];
            bit_f[2]    <=  bit_f[1];
            bit_f[3]    <=  bit_f[2];
            dst_f[i]    <=  bit_f[3];
        end
    end endgenerate
`endif

endmodule
