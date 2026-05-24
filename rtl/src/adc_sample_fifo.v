`timescale 1 ns / 1 ps

module adc_sample_fifo #(
    parameter integer DATA_WIDTH = 32,
    parameter integer FIFO_DEPTH = 4096,
    parameter integer ADDR_WIDTH = 12
) (
    input wire clk,
    input wire resetn,
    input wire clear,

    input wire sample_valid,
    input wire [11:0] sample_a,
    input wire [11:0] sample_b,
    input wire [3:0] flags_a,
    input wire [3:0] flags_b,

    output wire [DATA_WIDTH-1:0] sample_word_tdata,
    output wire sample_word_tvalid,
    input wire sample_word_tready,

    output wire full,
    output wire empty,
    output reg overflow,
    output reg underflow,
    output reg [31:0] fifo_level,
    output reg [31:0] last_sample_word
);
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;
    reg [ADDR_WIDTH:0] count;

    localparam [ADDR_WIDTH:0] FIFO_DEPTH_COUNT = FIFO_DEPTH;

    wire [DATA_WIDTH-1:0] packed_sample;
    wire do_write;
    wire do_read;

    assign packed_sample = {flags_b, sample_b, flags_a, sample_a};
    assign full = (count == FIFO_DEPTH_COUNT);
    assign empty = (count == {(ADDR_WIDTH+1){1'b0}});
    assign sample_word_tvalid = !empty;
    assign sample_word_tdata = mem[rd_ptr];
    assign do_write = sample_valid && !full;
    assign do_read = sample_word_tvalid && sample_word_tready;

    always @(posedge clk) begin
        if (!resetn || clear) begin
            wr_ptr <= {ADDR_WIDTH{1'b0}};
            rd_ptr <= {ADDR_WIDTH{1'b0}};
            count <= {(ADDR_WIDTH+1){1'b0}};
            overflow <= 1'b0;
            underflow <= 1'b0;
            fifo_level <= 32'd0;
            last_sample_word <= 32'd0;
        end else begin
            if (do_write) begin
                mem[wr_ptr] <= packed_sample;
                wr_ptr <= wr_ptr + 1'b1;
                last_sample_word <= packed_sample;
            end else if (sample_valid && full) begin
                overflow <= 1'b1;
            end

            if (do_read) begin
                rd_ptr <= rd_ptr + 1'b1;
            end

            case ({do_write, do_read})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase

            case ({do_write, do_read})
                2'b10: fifo_level <= fifo_level + 1'b1;
                2'b01: fifo_level <= fifo_level - 1'b1;
                default: fifo_level <= fifo_level;
            endcase
        end
    end
endmodule
