`timescale 1 ns / 1 ps

module ad9226_capture_core #(
    parameter integer MAX_SAMPLE_N = 65536,
    parameter integer SAMPLE_DELAY_MAX = 31
) (
    input wire clk_125m,
    input wire adc_clk_62m5,
    input wire adc_capture_clk_62m5,
    input wire adc_clock_locked,
    input wire resetn,

    input wire enable,
    input wire start_pulse,
    input wire clear_pulse,
    input wire soft_reset,

    input wire [31:0] sample_count_cfg,
    input wire [15:0] adc_half_period_cfg,
    input wire [7:0] sample_delay_cfg,
    input wire [15:0] decimation_cfg,
    input wire [1:0] channel_mask_cfg,
    input wire [1:0] capture_mode_cfg,
    input wire [1:0] trigger_mode_cfg,
    input wire [31:0] pre_delay_cfg,
    input wire buffer_select_cfg,

    input wire [11:0] adc_a_data,
    input wire [11:0] adc_b_data,
    output wire adc_a_clk,
    output wire adc_b_clk,

    output reg sample_valid,
    output reg [11:0] sample_a,
    output reg [11:0] sample_b,
    output reg [3:0] flags_a,
    output reg [3:0] flags_b,

    output reg busy,
    output reg done,
    output reg adc_clk_seen,
    output reg data_changed_a,
    output reg data_changed_b,
    output reg near_rail_a,
    output reg near_rail_b,
    output reg config_error,

    output reg [11:0] latest_a,
    output reg [11:0] latest_b,
    output reg [31:0] sample_counter,
    output reg [31:0] saved_counter,
    output reg [31:0] last_sample_word,
    output reg [2:0] debug_state
);
    localparam [2:0] ST_IDLE = 3'd0;
    localparam [2:0] ST_ARMED = 3'd1;
    localparam [2:0] ST_PRE_DELAY = 3'd2;
    localparam [2:0] ST_CAPTURING = 3'd3;
    localparam [2:0] ST_DONE = 3'd4;
    localparam [2:0] ST_ERROR = 3'd5;

    localparam [1:0] MODE_WRITER_FAKE = 2'd0;
    localparam [1:0] MODE_REAL_ADC = 2'd1;
    localparam [1:0] MODE_CAPTURE_FAKE = 2'd2;

    (* IOB = "TRUE" *) reg [11:0] adc_a_capture = 12'd0;
    (* IOB = "TRUE" *) reg [11:0] adc_b_capture = 12'd0;
    reg capture_toggle = 1'b0;
    reg [11:0] adc_a_sample_125;
    reg [11:0] adc_b_sample_125;
    reg capture_toggle_seen;
    reg adc_sample_pulse;
    reg [11:0] prev_a;
    reg [11:0] prev_b;

    reg [31:0] sample_count_run;
    reg [15:0] adc_half_period_run;
    reg [7:0] sample_delay_run;
    reg [15:0] decimation_run;
    reg [1:0] channel_mask_run;
    reg [1:0] capture_mode_run;
    reg [1:0] trigger_mode_run;
    reg [31:0] pre_delay_run;
    reg buffer_select_run;

    reg [15:0] decimation_count;
    reg [31:0] pre_delay_count;

    wire [31:0] sample_count_clamped =
        (sample_count_cfg < 32'd1) ? 32'd1 :
        (sample_count_cfg > MAX_SAMPLE_N) ? MAX_SAMPLE_N[31:0] :
        sample_count_cfg;

    wire [15:0] adc_half_period_clamped =
        (adc_half_period_cfg < 16'd1) ? 16'd1 : adc_half_period_cfg;

    wire [7:0] sample_delay_clamped =
        (sample_delay_cfg > SAMPLE_DELAY_MAX[7:0]) ? SAMPLE_DELAY_MAX[7:0] : sample_delay_cfg;

    wire [15:0] decimation_clamped =
        (decimation_cfg < 16'd1) ? 16'd1 : decimation_cfg;

    wire [1:0] channel_mask_clamped =
        (channel_mask_cfg == 2'b00) ? 2'b11 : channel_mask_cfg;

    wire cfg_has_error =
        (sample_count_cfg < 32'd1) ||
        (sample_count_cfg > MAX_SAMPLE_N) ||
        (decimation_cfg < 16'd1) ||
        (channel_mask_cfg == 2'b00);

    wire [11:0] raw_sample_a_next =
        (capture_mode_run == MODE_CAPTURE_FAKE) ? saved_counter[11:0] : adc_a_sample_125;
    wire [11:0] raw_sample_b_next =
        (capture_mode_run == MODE_CAPTURE_FAKE) ? (12'hFFF - saved_counter[11:0]) : adc_b_sample_125;
    wire data_changed_a_next = (raw_sample_a_next != prev_a);
    wire data_changed_b_next = (raw_sample_b_next != prev_b);
    wire near_rail_a_next = (raw_sample_a_next <= 12'd8) || (raw_sample_a_next >= 12'hFF7);
    wire near_rail_b_next = (raw_sample_b_next <= 12'd8) || (raw_sample_b_next >= 12'hFF7);
    wire [11:0] sample_a_next = channel_mask_run[0] ? raw_sample_a_next : 12'd0;
    wire [11:0] sample_b_next = channel_mask_run[1] ? raw_sample_b_next : 12'd0;
    wire [3:0] flags_a_next = {2'b00, data_changed_a_next, near_rail_a_next};
    wire [3:0] flags_b_next = {2'b00, data_changed_b_next, near_rail_b_next};

`ifndef SYNTHESIS
    assign adc_a_clk = (enable && adc_clock_locked) ? adc_clk_62m5 : 1'b0;
    assign adc_b_clk = (enable && adc_clock_locked) ? adc_clk_62m5 : 1'b0;
`else
    ODDR #(
        .DDR_CLK_EDGE("OPPOSITE_EDGE"),
        .INIT(1'b0),
        .SRTYPE("SYNC")
    ) adc_a_clk_oddr_i (
        .Q(adc_a_clk),
        .C(adc_clk_62m5),
        .CE(1'b1),
        .D1(1'b1),
        .D2(1'b0),
        .R((!resetn) || soft_reset || (!enable) || (!adc_clock_locked)),
        .S(1'b0)
    );

    ODDR #(
        .DDR_CLK_EDGE("OPPOSITE_EDGE"),
        .INIT(1'b0),
        .SRTYPE("SYNC")
    ) adc_b_clk_oddr_i (
        .Q(adc_b_clk),
        .C(adc_clk_62m5),
        .CE(1'b1),
        .D1(1'b1),
        .D2(1'b0),
        .R((!resetn) || soft_reset || (!enable) || (!adc_clock_locked)),
        .S(1'b0)
    );
`endif

    // The falling edge of the 258.75-degree clock is 19.5 ns after launch.
    // launch. It leaves margin for FPGA clock-out, ADC tCO, board skew, and IBUF.
    // These first-stage registers stay free of reset/mux logic so Vivado can
    // place them in the input IOBs. The 125 MHz domain ignores them until LOCKED.
    always @(negedge adc_capture_clk_62m5) begin
        adc_a_capture <= adc_a_data;
        adc_b_capture <= adc_b_data;
        capture_toggle <= ~capture_toggle;
    end

    always @(posedge clk_125m) begin
        if (!resetn || soft_reset || !adc_clock_locked) begin
            adc_a_sample_125 <= 12'd0;
            adc_b_sample_125 <= 12'd0;
            capture_toggle_seen <= 1'b0;
            adc_sample_pulse <= 1'b0;
            adc_clk_seen <= 1'b0;
        end else begin
            adc_sample_pulse <= 1'b0;
            if (clear_pulse) begin
                capture_toggle_seen <= capture_toggle;
            end else if (capture_toggle != capture_toggle_seen) begin
                capture_toggle_seen <= capture_toggle;
                adc_a_sample_125 <= adc_a_capture;
                adc_b_sample_125 <= adc_b_capture;
                adc_sample_pulse <= 1'b1;
                adc_clk_seen <= 1'b1;
            end
        end
    end

    always @(posedge clk_125m) begin
        if (!resetn || soft_reset) begin
            sample_count_run <= 32'd1;
            adc_half_period_run <= 16'd6;
            sample_delay_run <= 8'd1;
            decimation_run <= 16'd1;
            channel_mask_run <= 2'b11;
            capture_mode_run <= MODE_WRITER_FAKE;
            trigger_mode_run <= 2'd0;
            pre_delay_run <= 32'd0;
            buffer_select_run <= 1'b0;

            busy <= 1'b0;
            done <= 1'b0;
            config_error <= 1'b0;
            sample_valid <= 1'b0;
            sample_a <= 12'd0;
            sample_b <= 12'd0;
            flags_a <= 4'd0;
            flags_b <= 4'd0;
            latest_a <= 12'd0;
            latest_b <= 12'd0;
            prev_a <= 12'd0;
            prev_b <= 12'd0;
            data_changed_a <= 1'b0;
            data_changed_b <= 1'b0;
            near_rail_a <= 1'b0;
            near_rail_b <= 1'b0;
            sample_counter <= 32'd0;
            saved_counter <= 32'd0;
            last_sample_word <= 32'd0;
            debug_state <= ST_IDLE;
            decimation_count <= 16'd0;
            pre_delay_count <= 32'd0;
        end else begin
            sample_valid <= 1'b0;

            if (clear_pulse) begin
                busy <= 1'b0;
                done <= 1'b0;
                sample_valid <= 1'b0;
                sample_counter <= 32'd0;
                saved_counter <= 32'd0;
                last_sample_word <= 32'd0;
                config_error <= 1'b0;
                data_changed_a <= 1'b0;
                data_changed_b <= 1'b0;
                near_rail_a <= 1'b0;
                near_rail_b <= 1'b0;
                debug_state <= ST_IDLE;
                decimation_count <= 16'd0;
                pre_delay_count <= 32'd0;
            end else if (start_pulse && !busy) begin
                sample_count_run <= sample_count_clamped;
                adc_half_period_run <= adc_half_period_clamped;
                sample_delay_run <= sample_delay_clamped;
                decimation_run <= decimation_clamped;
                channel_mask_run <= channel_mask_clamped;
                capture_mode_run <= capture_mode_cfg;
                trigger_mode_run <= trigger_mode_cfg;
                pre_delay_run <= pre_delay_cfg;
                buffer_select_run <= buffer_select_cfg;

                config_error <= config_error | cfg_has_error;
                done <= (capture_mode_cfg == MODE_WRITER_FAKE);
                busy <= (capture_mode_cfg != MODE_WRITER_FAKE);
                sample_counter <= 32'd0;
                saved_counter <= 32'd0;
                decimation_count <= 16'd0;
                pre_delay_count <= pre_delay_cfg;
                debug_state <= (capture_mode_cfg == MODE_WRITER_FAKE) ? ST_DONE : ST_ARMED;
            end else if (busy && adc_sample_pulse) begin
                sample_counter <= sample_counter + 1'b1;

                if (pre_delay_count != 32'd0) begin
                    pre_delay_count <= pre_delay_count - 1'b1;
                    debug_state <= ST_PRE_DELAY;
                end else begin
                    debug_state <= ST_CAPTURING;

                    if (decimation_count == 16'd0) begin
                        latest_a <= raw_sample_a_next;
                        latest_b <= raw_sample_b_next;
                        data_changed_a <= data_changed_a_next;
                        data_changed_b <= data_changed_b_next;
                        prev_a <= raw_sample_a_next;
                        prev_b <= raw_sample_b_next;
                        near_rail_a <= near_rail_a_next;
                        near_rail_b <= near_rail_b_next;
                        sample_a <= sample_a_next;
                        sample_b <= sample_b_next;
                        flags_a <= flags_a_next;
                        flags_b <= flags_b_next;
                        last_sample_word <= {flags_b_next, sample_b_next, flags_a_next, sample_a_next};
                        sample_valid <= 1'b1;

                        if (saved_counter + 1'b1 >= sample_count_run) begin
                            saved_counter <= sample_count_run;
                            busy <= 1'b0;
                            done <= 1'b1;
                            debug_state <= ST_DONE;
                        end else begin
                            saved_counter <= saved_counter + 1'b1;
                        end

                        decimation_count <= decimation_run - 1'b1;
                    end else begin
                        decimation_count <= decimation_count - 1'b1;
                    end
                end
            end
        end
    end
endmodule
