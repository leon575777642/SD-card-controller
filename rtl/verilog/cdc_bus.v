// Cross-domain bus synchronizer
//  - with a "synced" signal at the sending side
module cdc_bus (
    rst,
    src_clk, src, synced,
    dst_clk, dst);

    parameter WIDTH = 1;

    input  wire                 rst;

    input  wire                 src_clk;
    input  wire [WIDTH - 1:0]   src;
    output wire                 synced;

    input  wire                 dst_clk;
    output reg  [WIDTH - 1:0]   dst;

    reg [WIDTH - 1:0] prev_synced_src, src_f;
    reg src_val, dst_ack;
    wire src_ack, src_val;
    wire [WIDTH - 1:0] dst_hsked;

    cdc_handshake #(
        .WIDTH(WIDTH)
    ) cdc_handshake_inst (
        .rst(rst)
        ,.src_clk(src_clk)
        ,.src(src_f)
        ,.src_val(src_val)
        ,.src_ack(src_ack)
        ,.dst_clk(dst_clk)
        ,.dst(dst_hsked)
        ,.dst_val(dst_val)
        ,.dst_ack(dst_ack)
        );

    localparam STATE_IDLE = 2'd0;
    localparam STATE_SYNC = 2'd1;
    localparam STATE_WAIT = 2'd2;

    reg [1:0] state, state_next;

    always @(posedge src_clk or posedge rst) begin
        if (rst) begin
            state           <= STATE_IDLE;
            prev_synced_src <= {WIDTH{1'b0}};
            src_f           <= {WIDTH{1'b0}};
        end else begin
            state           <= state_next;

            if (state == STATE_IDLE && src != prev_synced_src) begin
                src_f               <= src;
            end

            if (state == STATE_WAIT && src_ack) begin
                prev_synced_src     <= src_f;
            end
        end
    end

    always @* begin
        state_next = state;
        src_val = 1'b0;

        case (state)
            STATE_IDLE: begin
                if (src != prev_synced_src) begin
                    state_next = STATE_SYNC;
                end
            end
            STATE_SYNC: begin
                src_val = 1'b1;
                state_next = STATE_WAIT;
            end
            STATE_WAIT: begin
                if (src_ack) begin
                    state_next = STATE_IDLE;
                end
            end
        endcase
    end

    always @(posedge dst_clk or posedge rst) begin
        if (rst) begin
            dst <= {WIDTH{1'b0}};
        end else begin
            if (dst_val) begin
                dst <= dst_hsked;
            end
        end
    end

    assign synced = (src == prev_synced_src && state == STATE_IDLE);
    assign dst_ack = dst_val;

endmodule
