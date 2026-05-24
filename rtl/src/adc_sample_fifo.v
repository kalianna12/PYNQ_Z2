`timescale 1 ns / 1 ps

// AXI-Stream packer/skid stage.
// The deep buffering is provided by the Vivado AXIS Data FIFO IP in the block design.
module adc_sample_fifo #(
    parameter integer DATA_WIDTH = 32,
    parameter integer ADDR_WIDTH = 12,
    parameter integer FIFO_DEPTH = (1 << ADDR_WIDTH)
) (
    input wire clk,
    input wire resetn,
    input wire clear,

    input wire sample_valid,
    input wire [11:0] sample_a,
    input wire [11:0] sample_b,
    input wire [3:0] flags_a,
    input wire [3:0] flags_b,
    input wire [31:0] target_count,

    output wire [DATA_WIDTH-1:0] sample_word_tdata,
    output wire sample_word_tvalid,
    input wire sample_word_tready,
    output wire sample_word_tlast,
    output wire [3:0] sample_word_tkeep,

    output wire full,
    output wire empty,
    output reg overflow,
    output reg underflow,
    output wire [31:0] fifo_level,
    output reg [31:0] last_sample_word,
    output reg [31:0] axis_sent_count,
    output reg [31:0] axis_stall_count,
    output reg [31:0] tlast_count,
    output reg fifo_backpressure_seen,
    output reg [31:0] dropped_sample_count,
    output reg capture_done_latched
);
    reg [DATA_WIDTH-1:0] tdata_r;
    reg tvalid_r;
    reg tlast_r;

    wire [DATA_WIDTH-1:0] packed_sample;
    wire [31:0] target_count_safe;
    wire do_handshake;
    wire can_accept_sample;
    wire accept_sample;
    wire drop_sample;
    wire [31:0] sent_after_handshake;
    wire next_sample_is_last;

    assign packed_sample = {flags_b, sample_b, flags_a, sample_a};
    assign target_count_safe = (target_count == 32'd0) ? 32'd1 : target_count;
    assign do_handshake = tvalid_r && sample_word_tready;
    assign can_accept_sample = (!tvalid_r) || sample_word_tready;
    assign accept_sample = sample_valid && can_accept_sample;
    assign drop_sample = sample_valid && !can_accept_sample;
    assign sent_after_handshake = axis_sent_count + (do_handshake ? 32'd1 : 32'd0);
    assign next_sample_is_last = (sent_after_handshake + 32'd1 >= target_count_safe);

    assign sample_word_tdata = tdata_r;
    assign sample_word_tvalid = tvalid_r;
    assign sample_word_tlast = tvalid_r && tlast_r;
    assign sample_word_tkeep = 4'hF;
    assign full = tvalid_r && !sample_word_tready;
    assign empty = !tvalid_r;
    assign fifo_level = tvalid_r ? 32'd1 : 32'd0;

    always @(posedge clk) begin
        if (!resetn || clear) begin
            tdata_r <= {DATA_WIDTH{1'b0}};
            tvalid_r <= 1'b0;
            tlast_r <= 1'b0;
            overflow <= 1'b0;
            underflow <= 1'b0;
            last_sample_word <= 32'd0;
            axis_sent_count <= 32'd0;
            axis_stall_count <= 32'd0;
            tlast_count <= 32'd0;
            fifo_backpressure_seen <= 1'b0;
            dropped_sample_count <= 32'd0;
            capture_done_latched <= 1'b0;
        end else begin
            if (do_handshake) begin
                axis_sent_count <= axis_sent_count + 32'd1;
                last_sample_word <= tdata_r;
                if (tlast_r) begin
                    tlast_count <= tlast_count + 32'd1;
                    capture_done_latched <= 1'b1;
                end
            end

            if (accept_sample) begin
                tdata_r <= packed_sample;
                tvalid_r <= 1'b1;
                tlast_r <= next_sample_is_last;
            end else if (do_handshake) begin
                tvalid_r <= 1'b0;
                tlast_r <= 1'b0;
            end

            if (drop_sample) begin
                overflow <= 1'b1;
                fifo_backpressure_seen <= 1'b1;
                dropped_sample_count <= dropped_sample_count + 32'd1;
            end

            if (tvalid_r && !sample_word_tready) begin
                axis_stall_count <= axis_stall_count + 32'd1;
                fifo_backpressure_seen <= 1'b1;
            end
        end
    end
endmodule
