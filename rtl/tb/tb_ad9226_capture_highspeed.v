`timescale 1 ns / 1 ps

module tb_ad9226_capture_highspeed;
    reg clk = 1'b0;
    reg adc_clk_62m5 = 1'b0;
    reg adc_capture_clk_62m5 = 1'b0;
    reg adc_clock_locked = 1'b0;
    reg resetn = 1'b0;

    reg enable = 1'b0;
    reg start_pulse = 1'b0;
    reg clear_pulse = 1'b0;
    reg soft_reset = 1'b0;

    reg [31:0] sample_count_cfg = 32'd1024;
    reg [15:0] adc_half_period_cfg = 16'd1;
    reg [7:0] sample_delay_cfg = 8'd1;
    reg [15:0] decimation_cfg = 16'd1;
    reg [1:0] channel_mask_cfg = 2'b11;
    reg [1:0] capture_mode_cfg = 2'd2;
    reg [1:0] trigger_mode_cfg = 2'd0;
    reg [31:0] pre_delay_cfg = 32'd0;
    reg buffer_select_cfg = 1'b0;

    reg [11:0] adc_a_data = 12'd100;
    reg [11:0] adc_b_data = 12'd700;
    wire adc_a_clk;
    wire adc_b_clk;

    wire sample_valid;
    wire [11:0] sample_a;
    wire [11:0] sample_b;
    wire [3:0] flags_a;
    wire [3:0] flags_b;

    wire busy;
    wire done;
    wire adc_clk_seen;
    wire data_changed_a;
    wire data_changed_b;
    wire near_rail_a;
    wire near_rail_b;
    wire config_error;
    wire [11:0] latest_a;
    wire [11:0] latest_b;
    wire [31:0] sample_counter;
    wire [31:0] saved_counter;
    wire [31:0] capture_last_word;
    wire [2:0] debug_state;

    wire [31:0] tdata;
    wire tvalid;
    wire tready = 1'b1;
    wire tlast;
    wire [3:0] tkeep;
    wire fifo_full;
    wire fifo_empty;
    wire fifo_overflow;
    wire fifo_underflow;
    wire [31:0] fifo_level;
    wire [31:0] fifo_last_word;
    wire [31:0] axis_sent_count;
    wire [31:0] axis_stall_count;
    wire [31:0] tlast_count;
    wire fifo_backpressure_seen;
    wire [31:0] dropped_sample_count;
    wire capture_done_latched;

    integer read_count = 0;
    integer fake_errors = 0;
    integer real_errors = 0;

    ad9226_capture_core #(
        .MAX_SAMPLE_N(65536),
        .SAMPLE_DELAY_MAX(31)
    ) capture_i (
        .clk_125m(clk),
        .adc_clk_62m5(adc_clk_62m5),
        .adc_capture_clk_62m5(adc_capture_clk_62m5),
        .adc_clock_locked(adc_clock_locked),
        .resetn(resetn),
        .enable(enable),
        .start_pulse(start_pulse),
        .clear_pulse(clear_pulse),
        .soft_reset(soft_reset),
        .sample_count_cfg(sample_count_cfg),
        .adc_half_period_cfg(adc_half_period_cfg),
        .sample_delay_cfg(sample_delay_cfg),
        .decimation_cfg(decimation_cfg),
        .channel_mask_cfg(channel_mask_cfg),
        .capture_mode_cfg(capture_mode_cfg),
        .trigger_mode_cfg(trigger_mode_cfg),
        .pre_delay_cfg(pre_delay_cfg),
        .buffer_select_cfg(buffer_select_cfg),
        .adc_a_data(adc_a_data),
        .adc_b_data(adc_b_data),
        .adc_a_clk(adc_a_clk),
        .adc_b_clk(adc_b_clk),
        .sample_valid(sample_valid),
        .sample_a(sample_a),
        .sample_b(sample_b),
        .flags_a(flags_a),
        .flags_b(flags_b),
        .busy(busy),
        .done(done),
        .adc_clk_seen(adc_clk_seen),
        .data_changed_a(data_changed_a),
        .data_changed_b(data_changed_b),
        .near_rail_a(near_rail_a),
        .near_rail_b(near_rail_b),
        .config_error(config_error),
        .latest_a(latest_a),
        .latest_b(latest_b),
        .sample_counter(sample_counter),
        .saved_counter(saved_counter),
        .last_sample_word(capture_last_word),
        .debug_state(debug_state)
    );

    adc_sample_fifo #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(4)
    ) stream_i (
        .clk(clk),
        .resetn(resetn),
        .clear(clear_pulse || soft_reset),
        .sample_valid(sample_valid),
        .sample_a(sample_a),
        .sample_b(sample_b),
        .flags_a(flags_a),
        .flags_b(flags_b),
        .target_count(sample_count_cfg),
        .sample_word_tdata(tdata),
        .sample_word_tvalid(tvalid),
        .sample_word_tready(tready),
        .sample_word_tlast(tlast),
        .sample_word_tkeep(tkeep),
        .full(fifo_full),
        .empty(fifo_empty),
        .overflow(fifo_overflow),
        .underflow(fifo_underflow),
        .fifo_level(fifo_level),
        .last_sample_word(fifo_last_word),
        .axis_sent_count(axis_sent_count),
        .axis_stall_count(axis_stall_count),
        .tlast_count(tlast_count),
        .fifo_backpressure_seen(fifo_backpressure_seen),
        .dropped_sample_count(dropped_sample_count),
        .capture_done_latched(capture_done_latched)
    );

    always #4 clk = ~clk;
    always #8 adc_clk_62m5 = ~adc_clk_62m5;

    initial begin
        #11.5;
        forever #8 adc_capture_clk_62m5 = ~adc_capture_clk_62m5;
    end

    always @(posedge clk) begin
        adc_a_data <= adc_a_data + 12'd7;
        adc_b_data <= adc_b_data + 12'd11;
    end

    always @(posedge clk) begin
        if (resetn && tvalid && tready) begin
            if (tkeep !== 4'hF) begin
                fake_errors = fake_errors + 1;
            end
            if (capture_mode_cfg == 2'd2) begin
                if (tdata[11:0] !== read_count[11:0]) begin
                    fake_errors = fake_errors + 1;
                end
                if (tdata[27:16] !== (12'hFFF - read_count[11:0])) begin
                    fake_errors = fake_errors + 1;
                end
            end else if (capture_mode_cfg == 2'd1) begin
                if (tdata[11:0] === 12'd0 && tdata[27:16] === 12'd0) begin
                    real_errors = real_errors + 1;
                end
            end
            read_count = read_count + 1;
        end
    end

    task pulse_clear;
        begin
            @(posedge clk);
            clear_pulse <= 1'b1;
            @(posedge clk);
            clear_pulse <= 1'b0;
        end
    endtask

    task pulse_start;
        begin
            @(posedge clk);
            start_pulse <= 1'b1;
            @(posedge clk);
            start_pulse <= 1'b0;
        end
    endtask

    task check_clean_axis;
        input [31:0] expected_count;
        input integer errors;
        begin
            if (axis_sent_count !== expected_count ||
                read_count != expected_count ||
                tlast_count !== 32'd1 ||
                dropped_sample_count !== 32'd0 ||
                axis_stall_count !== 32'd0 ||
                fifo_backpressure_seen !== 1'b0 ||
                fifo_overflow !== 1'b0 ||
                errors != 0) begin
                $display("FINAL: FAIL highspeed count=%0d read=%0d sent=%0d tlast=%0d dropped=%0d stall=%0d backpressure=%0d overflow=%0d errors=%0d",
                         expected_count, read_count, axis_sent_count, tlast_count,
                         dropped_sample_count, axis_stall_count, fifo_backpressure_seen,
                         fifo_overflow, errors);
                $finish;
            end
        end
    endtask

    initial begin
        repeat (8) @(posedge clk);
        resetn <= 1'b1;
        adc_clock_locked <= 1'b1;
        enable <= 1'b1;
        repeat (4) @(posedge clk);

        capture_mode_cfg <= 2'd2;
        sample_count_cfg <= 32'd1024;
        adc_half_period_cfg <= 16'd1;
        sample_delay_cfg <= 8'd1;
        decimation_cfg <= 16'd1;
        channel_mask_cfg <= 2'b11;
        read_count = 0;
        fake_errors = 0;
        pulse_clear();
        pulse_start();
        wait (capture_done_latched);
        repeat (8) @(posedge clk);
        check_clean_axis(32'd1024, fake_errors);

        capture_mode_cfg <= 2'd1;
        sample_count_cfg <= 32'd256;
        adc_half_period_cfg <= 16'd1;
        sample_delay_cfg <= 8'd0;
        decimation_cfg <= 16'd1;
        channel_mask_cfg <= 2'b11;
        read_count = 0;
        real_errors = 0;
        pulse_clear();
        pulse_start();
        wait (capture_done_latched);
        repeat (8) @(posedge clk);
        check_clean_axis(32'd256, real_errors);

        if (!adc_clk_seen || config_error) begin
            $display("FINAL: FAIL highspeed status adc_clk_seen=%0d config_error=%0d", adc_clk_seen, config_error);
            $finish;
        end

        $display("FINAL: PASS fixed 62.5 MSPS fake and real AXIS stream");
        $finish;
    end

    initial begin
        repeat (20000) @(posedge clk);
        $display("FINAL: FAIL highspeed simulation timeout");
        $finish;
    end
endmodule
