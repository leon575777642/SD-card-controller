// Cross-domain bus synchronizer with full hand-shake protocol
module cdc_handshake (
    rst,
    src_clk, src, src_val, src_ack,
    dst_clk, dst, dst_val, dst_ack
    );

    parameter WIDTH = 1;

    input  wire                 rst;

    input  wire                 src_clk;
    input  wire [WIDTH - 1:0]   src;
    input  wire                 src_val;
    output wire                 src_ack;

    input  wire                 dst_clk;
    output wire [WIDTH - 1:0]   dst;
    output wire                 dst_val;
    input  wire                 dst_ack;

`ifdef USE_XILINX_XPM
    xpm_cdc_handshake #(
        .DEST_EXT_HSK(1)
        ,.DEST_SYNC_FF(2)
        ,.SRC_SYNC_FF(2)
        ,.WIDTH(WIDTH)
    ) xpm_cdc_handshake_inst (
        ,.src_clk(src_clk)
        ,.src_in(src)
        ,.src_send(src_val)
        ,.dest_ack(src_ack)
        ,.dest_clk(dst_clk)
        ,.dest_out(dst)
        ,.src_rcv(dst_ack)
        ,.dest_req(dst_val)
        );
`else
    //  src -> dst: use FIFO
    //  dst -> src: use cdc_pulse or cdc_bits(1)
    reg [WIDTH - 1:0] src_f, dst_f;

    reg wr_en, rd_en;
    wire full, empty;
    wire [WIDTH - 1:0] fifo_dout;

    async_fifo #(
        .WIDTH(WIDTH)
        ,.DEPTH_LOG2(1)     // DEPTH = 2
    ) async_fifo_inst (
        .rst(rst)
        ,.wr_clk(src_clk)
        ,.wr_en(wr_en)
        ,.din(src_f)
        ,.full(full)
        ,.rd_clk(dst_clk)
        ,.rd_en(rd_en)
        ,.dout(fifo_dout)
        ,.empty(empty)
        );

    reg dst_acked;
    wire dst_acked_sync;

    cdc_pulse cdc_pulse_inst (
        .rst(rst)
        ,.src_clk(dst_clk)
        ,.src(dst_acked)
        ,.dst_clk(src_clk)
        ,.dst(dst_acked_sync)
        );

    // sender side
    localparam SRC_STATE_IDLE = 2'd0;
    localparam SRC_STATE_SEND = 2'd1;
    localparam SRC_STATE_WAIT = 2'd2;

    reg [1:0] src_state, src_state_next;
    reg src_ack_f;

    always @(posedge src_clk or posedge rst) begin
        if (rst) begin
            src_state   <=  SRC_STATE_IDLE;
            src_f       <=  {WIDTH{1'b0}};
        end else begin
            src_state   <=  src_state_next;

            if (src_state == SRC_STATE_IDLE && src_val) begin
                src_f   <=  src;
            end
        end
    end

    always @* begin
        src_state_next = src_state;
        wr_en       =   1'b0;
        src_ack_f   =   1'b0;

        case (src_state)
            SRC_STATE_IDLE:
                if (src_val) begin
                    src_state_next = SRC_STATE_SEND;
                end
            SRC_STATE_SEND:
                if (!full) begin
                    wr_en = 1'b1;
                    src_state_next = SRC_STATE_WAIT;
                end
            SRC_STATE_WAIT:
                if (dst_acked_sync) begin
                    src_ack_f = 1'b1;
                    src_state_next = SRC_STATE_IDLE;
                end
        endcase
    end

    assign src_ack = src_ack_f;
    
    // receiver side
    localparam DST_STATE_IDLE = 2'd0;
    localparam DST_STATE_FIFO_RD = 2'd1;
    localparam DST_STATE_DATA_READY = 2'd2;

    reg [1:0] dst_state, dst_state_next;
    reg dst_val_f;

    always @(posedge dst_clk or posedge rst) begin
        if (rst) begin
            dst_state   <=  DST_STATE_IDLE;
            dst_f       <=  {WIDTH{1'b0}};
            dst_acked   <=  1'b0;
        end else begin
            dst_state   <=  dst_state_next;

            if (dst_state == DST_STATE_FIFO_RD) begin
                dst_f   <=  fifo_dout;
            end

            if (dst_state == DST_STATE_DATA_READY && dst_ack) begin
                dst_acked   <=  1'b1;
            end else begin
                dst_acked   <=  1'b0;
            end
        end
    end

    always @* begin
        dst_state_next = dst_state;
        rd_en = 1'b0;
        dst_val_f = 1'b0;

        case (dst_state)
            DST_STATE_IDLE:
                if (!empty) begin
                    dst_state_next = DST_STATE_FIFO_RD;
                    rd_en = 1'b1;
                end
            DST_STATE_FIFO_RD:
                dst_state_next = DST_STATE_DATA_READY;
            DST_STATE_DATA_READY: begin
                dst_val_f = 1'b1;
                if (dst_ack) begin
                    dst_state_next = DST_STATE_IDLE;
                end
            end
        endcase
    end

    assign dst = dst_f;
    assign dst_val = dst_val_f;
`endif

endmodule
