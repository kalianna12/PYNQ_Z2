`timescale 1 ns / 1 ps

module tb_ad9226_capture_chain;
    reg clk = 1'b0;
    reg resetn = 1'b0;

    reg enable = 1'b0;
    reg start_pulse = 1'b0;
    reg clear_pulse = 1'b0;
    reg soft_reset = 1'b0;

    reg [31:0] sample_count_cfg = 32'd8;
    reg [15:0] adc_half_period_cfg = 16'd2;
    reg [7:0] sample_delay_cfg = 8'd0;
    reg [15:0] decimation_cfg = 16'd1;
    reg [1:0] channel_mask_cfg = 2'b11;
    reg [1:0] capture_mode_cfg = 2'd2;
    reg [1:0] trigger_mode_cfg = 2'd0;
    reg [31:0] pre_delay_cfg = 32'd0;
    reg buffer_select_cfg = 1'b0;

    reg [11:0] adc_a_data = 12'd100;
    reg [11:0] adc_b_data = 12'd900;
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
    reg tready = 1'b1;
    wire fifo_full;
    wire fifo_empty;
    wire fifo_overflow;
    wire fifo_underflow;
    wire [31:0] fifo_level;
    wire [31:0] fifo_last_word;

    integer read_count = 0;
    integer mode2_errors = 0;
    integer real_errors = 0;
    integer overflow_clk_edges = 0;
    reg seen_mode2 = 1'b0;
    reg seen_real = 1'b0;
    reg [31:0] saved_after_pre_delay = 32'd0;
    reg adc_clk_prev = 1'b0;

    ad9226_capture_core #(
        .MAX_SAMPLE_N(65536),
        .SAMPLE_DELAY_MAX(31),
        .USE_ODDR_FAST(0)
    ) capture_i (
        .clk_125m(clk),
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
        .FIFO_DEPTH(16),
        .ADDR_WIDTH(4)
    ) fifo_i (
        .clk(clk),
        .resetn(resetn),
        .clear(clear_pulse || soft_reset),
        .sample_valid(sample_valid),
        .sample_a(sample_a),
        .sample_b(sample_b),
        .flags_a(flags_a),
        .flags_b(flags_b),
        .sample_word_tdata(tdata),
        .sample_word_tvalid(tvalid),
        .sample_word_tready(tready),
        .full(fifo_full),
        .empty(fifo_empty),
        .overflow(fifo_overflow),
        .underflow(fifo_underflow),
        .fifo_level(fifo_level),
        .last_sample_word(fifo_last_word)
    );

    always #4 clk = ~clk;

    always @(posedge clk) begin
        adc_a_data <= adc_a_data + 12'd3;
        adc_b_data <= adc_b_data + 12'd5;
    end

    always @(posedge clk) begin
        if (resetn && tvalid && tready) begin
            if (capture_mode_cfg == 2'd2) begin
                seen_mode2 <= 1'b1;
                if (tdata[11:0] !== read_count[11:0]) begin
                    mode2_errors = mode2_errors + 1;
                end
                if (tdata[27:16] !== (12'hFFF - read_count[11:0])) begin
                    mode2_errors = mode2_errors + 1;
                end
            end else if (capture_mode_cfg == 2'd1) begin
                seen_real <= 1'b1;
                if (tdata[11:0] === 12'd0) begin
                    real_errors = real_errors + 1;
                end
                if (tdata[27:16] !== 12'd0) begin
                    real_errors = real_errors + 1;
                end
            end
            read_count = read_count + 1;
        end
    end

    always @(posedge clk) begin
        if (resetn && !adc_clk_prev && adc_a_clk && fifo_full) begin
            overflow_clk_edges = overflow_clk_edges + 1;
        end
        adc_clk_prev <= adc_a_clk;
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

    initial begin
        repeat (8) @(posedge clk);
        resetn <= 1'b1;
        repeat (4) @(posedge clk);

        enable <= 1'b1;

        capture_mode_cfg <= 2'd2;
        channel_mask_cfg <= 2'b11;
        sample_count_cfg <= 32'd8;
        adc_half_period_cfg <= 16'd1;
        read_count = 0;
        mode2_errors = 0;
        pulse_clear();
        pulse_start();
        wait (done);
        repeat (8) @(posedge clk);
        if (!seen_mode2 || saved_counter !== 32'd8 || read_count != 8 || mode2_errors != 0) begin
            $display("FINAL: FAIL mode2 fake stream saved=%0d reads=%0d errors=%0d", saved_counter, read_count, mode2_errors);
            $finish;
        end
        if (sample_counter !== saved_counter) begin
            $display("FINAL: FAIL mode2 sample_counter=%0d saved=%0d", sample_counter, saved_counter);
            $finish;
        end

        capture_mode_cfg <= 2'd2;
        channel_mask_cfg <= 2'b11;
        sample_count_cfg <= 32'd5;
        decimation_cfg <= 16'd3;
        pre_delay_cfg <= 32'd16;
        read_count = 0;
        saved_after_pre_delay = 32'd0;
        pulse_clear();
        pulse_start();
        repeat (12) @(posedge clk);
        saved_after_pre_delay = saved_counter;
        wait (done);
        repeat (8) @(posedge clk);
        if (saved_after_pre_delay !== 32'd0 || saved_counter !== 32'd5 || sample_counter <= saved_counter) begin
            $display("FINAL: FAIL decimation/pre_delay sample=%0d saved=%0d early_saved=%0d", sample_counter, saved_counter, saved_after_pre_delay);
            $finish;
        end
        decimation_cfg <= 16'd1;
        pre_delay_cfg <= 32'd0;

        capture_mode_cfg <= 2'd2;
        channel_mask_cfg <= 2'b11;
        sample_count_cfg <= 32'd24;
        tready <= 1'b0;
        overflow_clk_edges = 0;
        pulse_clear();
        pulse_start();
        wait (done);
        repeat (32) @(posedge clk);
        if (!fifo_overflow || !fifo_full || overflow_clk_edges == 0) begin
            $display("FINAL: FAIL overflow overflow=%0d full=%0d clk_edges=%0d", fifo_overflow, fifo_full, overflow_clk_edges);
            $finish;
        end
        tready <= 1'b1;
        repeat (24) @(posedge clk);

        capture_mode_cfg <= 2'd1;
        channel_mask_cfg <= 2'b01;
        sample_count_cfg <= 32'd4;
        read_count = 0;
        real_errors = 0;
        pulse_clear();
        pulse_start();
        wait (done);
        repeat (8) @(posedge clk);
        if (!seen_real || saved_counter !== 32'd4 || read_count != 4 || real_errors != 0) begin
            $display("FINAL: FAIL real mode saved=%0d reads=%0d errors=%0d", saved_counter, read_count, real_errors);
            $finish;
        end

        channel_mask_cfg <= 2'b00;
        sample_count_cfg <= 32'd2;
        read_count = 0;
        pulse_clear();
        pulse_start();
        wait (done);
        repeat (4) @(posedge clk);
        if (!config_error) begin
            $display("FINAL: FAIL channel_mask=0 did not set config_error");
            $finish;
        end

        if (!adc_clk_seen || fifo_overflow || fifo_underflow) begin
            $display("FINAL: FAIL status adc_clk_seen=%0d overflow=%0d underflow=%0d", adc_clk_seen, fifo_overflow, fifo_underflow);
            $finish;
        end

        $display("FINAL: PASS ad9226 capture fake/real/fifo overflow/decimation/pre_delay config rules");
        $finish;
    end

    initial begin
        repeat (20000) @(posedge clk);
        $display("FINAL: FAIL ad9226 capture simulation timeout");
        $finish;
    end
endmodule
