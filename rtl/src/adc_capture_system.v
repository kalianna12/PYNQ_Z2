`timescale 1 ns / 1 ps

module adc_capture_system #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 7
) (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 S_AXI_ACLK CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXI:M_AXIS_SAMPLE, ASSOCIATED_RESET S_AXI_ARESETN" *)
    input wire S_AXI_ACLK,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 S_AXI_ARESETN RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input wire S_AXI_ARESETN,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWADDR" *)
    input wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWPROT" *)
    input wire [2:0] S_AXI_AWPROT,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *)
    input wire S_AXI_AWVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *)
    output wire S_AXI_AWREADY,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WDATA" *)
    input wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *)
    input wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WVALID" *)
    input wire S_AXI_WVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WREADY" *)
    output wire S_AXI_WREADY,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BRESP" *)
    output wire [1:0] S_AXI_BRESP,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BVALID" *)
    output wire S_AXI_BVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BREADY" *)
    input wire S_AXI_BREADY,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *)
    input wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARPROT" *)
    input wire [2:0] S_AXI_ARPROT,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *)
    input wire S_AXI_ARVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *)
    output wire S_AXI_ARREADY,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RDATA" *)
    output wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RRESP" *)
    output wire [1:0] S_AXI_RRESP,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RVALID" *)
    output wire S_AXI_RVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RREADY" *)
    input wire S_AXI_RREADY,

    input wire [11:0] adc_a_data,
    input wire [11:0] adc_b_data,
    input wire adc_a_ora,
    input wire adc_b_orb,
    output wire adc_a_clk,
    output wire adc_b_clk,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS_SAMPLE TDATA" *)
    output wire [31:0] M_AXIS_SAMPLE_TDATA,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS_SAMPLE TVALID" *)
    output wire M_AXIS_SAMPLE_TVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS_SAMPLE TREADY" *)
    input wire M_AXIS_SAMPLE_TREADY,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS_SAMPLE TLAST" *)
    output wire M_AXIS_SAMPLE_TLAST,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS_SAMPLE TKEEP" *)
    output wire [3:0] M_AXIS_SAMPLE_TKEEP
);
    wire enable;
    wire start_pulse;
    wire clear_pulse;
    wire soft_reset;
    wire [31:0] sample_count_cfg;
    wire [15:0] adc_half_period_cfg;
    wire [7:0] sample_delay_cfg;
    wire [15:0] decimation_cfg;
    wire [1:0] channel_mask_cfg;
    wire [1:0] capture_mode_cfg;
    wire [1:0] trigger_mode_cfg;
    wire [31:0] pre_delay_cfg;
    wire buffer_select_cfg;
    wire [3:0] led_value;
    wire led_ps_override;
    wire [3:0] unused_adc_leds;

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
    wire [31:0] capture_last_sample_word;
    wire [2:0] debug_state;

    wire [31:0] sample_word_tdata;
    wire sample_word_tvalid;
    wire sample_word_tready;
    wire sample_word_tlast;
    wire [3:0] sample_word_tkeep;
    wire fifo_full;
    wire fifo_empty;
    wire fifo_overflow;
    wire fifo_underflow;
    wire [31:0] fifo_level;
    wire [31:0] fifo_last_sample_word;
    wire [31:0] axis_sent_count;
    wire [31:0] axis_stall_count;
    wire [31:0] tlast_count;
    wire fifo_backpressure_seen;
    wire [31:0] dropped_sample_count;
    wire capture_done_latched;
    wire [31:0] axis_target_count;
    wire [31:0] error_flags_in;
    wire [31:0] error_flags_latched;
    wire fatal_error;
    reg adc_a_ora_d0;
    reg adc_a_ora_d1;
    reg adc_b_orb_d0;
    reg adc_b_orb_d1;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            adc_a_ora_d0 <= 1'b0;
            adc_a_ora_d1 <= 1'b0;
            adc_b_orb_d0 <= 1'b0;
            adc_b_orb_d1 <= 1'b0;
        end else begin
            adc_a_ora_d0 <= adc_a_ora;
            adc_a_ora_d1 <= adc_a_ora_d0;
            adc_b_orb_d0 <= adc_b_orb;
            adc_b_orb_d1 <= adc_b_orb_d0;
        end
    end

    assign sample_word_tready = M_AXIS_SAMPLE_TREADY;
    assign M_AXIS_SAMPLE_TDATA = sample_word_tdata;
    assign M_AXIS_SAMPLE_TVALID = sample_word_tvalid;
    assign M_AXIS_SAMPLE_TLAST = sample_word_tlast;
    assign M_AXIS_SAMPLE_TKEEP = sample_word_tkeep;
    assign axis_target_count =
        (sample_count_cfg < 32'd1) ? 32'd1 :
        (sample_count_cfg > 32'd65536) ? 32'd65536 :
        sample_count_cfg;
    assign fatal_error = fifo_overflow || (dropped_sample_count != 32'd0) || config_error;
    assign error_flags_in = {
        24'd0,
        fifo_backpressure_seen,
        (dropped_sample_count != 32'd0),
        config_error,
        1'b0,
        (near_rail_b | adc_b_orb_d1),
        (near_rail_a | adc_a_ora_d1),
        fifo_underflow,
        fifo_overflow
    };

    adc_ctrl_axi #(
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
        .VERSION_VALUE(32'h00010000)
    ) ctrl_i (
        .S_AXI_ACLK(S_AXI_ACLK),
        .S_AXI_ARESETN(S_AXI_ARESETN),
        .S_AXI_AWADDR(S_AXI_AWADDR),
        .S_AXI_AWPROT(S_AXI_AWPROT),
        .S_AXI_AWVALID(S_AXI_AWVALID),
        .S_AXI_AWREADY(S_AXI_AWREADY),
        .S_AXI_WDATA(S_AXI_WDATA),
        .S_AXI_WSTRB(S_AXI_WSTRB),
        .S_AXI_WVALID(S_AXI_WVALID),
        .S_AXI_WREADY(S_AXI_WREADY),
        .S_AXI_BRESP(S_AXI_BRESP),
        .S_AXI_BVALID(S_AXI_BVALID),
        .S_AXI_BREADY(S_AXI_BREADY),
        .S_AXI_ARADDR(S_AXI_ARADDR),
        .S_AXI_ARPROT(S_AXI_ARPROT),
        .S_AXI_ARVALID(S_AXI_ARVALID),
        .S_AXI_ARREADY(S_AXI_ARREADY),
        .S_AXI_RDATA(S_AXI_RDATA),
        .S_AXI_RRESP(S_AXI_RRESP),
        .S_AXI_RVALID(S_AXI_RVALID),
        .S_AXI_RREADY(S_AXI_RREADY),
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
        .led_value(led_value),
        .led_ps_override(led_ps_override),
        .busy(busy),
        .done(capture_done_latched),
        .adc_clk_seen(adc_clk_seen),
        .fifo_full(fifo_full),
        .fifo_empty(fifo_empty),
        .fifo_overflow(fifo_overflow),
        .near_rail_a(near_rail_a),
        .near_rail_b(near_rail_b),
        .writer_busy(1'b0),
        .writer_done(1'b0),
        .error(fatal_error),
        .core_done(done),
        .data_changed_a(data_changed_a),
        .data_changed_b(data_changed_b),
        .latest_a(latest_a),
        .latest_b(latest_b),
        .sample_counter(sample_counter),
        .fifo_level(fifo_level),
        .saved_counter(saved_counter),
        .last_sample_word(fifo_last_sample_word),
        .debug_state(debug_state),
        .axis_sent_count(axis_sent_count),
        .axis_stall_count(axis_stall_count),
        .tlast_count(tlast_count),
        .fifo_backpressure_seen(fifo_backpressure_seen),
        .dropped_sample_count(dropped_sample_count),
        .capture_done_latched(capture_done_latched),
        .error_flags_in(error_flags_in),
        .error_flags_latched(error_flags_latched),
        .leds_4bits_tri_o(unused_adc_leds)
    );

    ad9226_capture_core #(
        .MAX_SAMPLE_N(262144),
        .SAMPLE_DELAY_MAX(31)
    ) capture_i (
        .clk_125m(S_AXI_ACLK),
        .resetn(S_AXI_ARESETN),
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
        .last_sample_word(capture_last_sample_word),
        .debug_state(debug_state)
    );

    adc_sample_fifo #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(12)
    ) fifo_i (
        .clk(S_AXI_ACLK),
        .resetn(S_AXI_ARESETN),
        .clear(clear_pulse || soft_reset),
        .sample_valid(sample_valid),
        .sample_a(sample_a),
        .sample_b(sample_b),
        .flags_a(flags_a),
        .flags_b(flags_b),
        .target_count(axis_target_count),
        .sample_word_tdata(sample_word_tdata),
        .sample_word_tvalid(sample_word_tvalid),
        .sample_word_tready(sample_word_tready),
        .sample_word_tlast(sample_word_tlast),
        .sample_word_tkeep(sample_word_tkeep),
        .full(fifo_full),
        .empty(fifo_empty),
        .overflow(fifo_overflow),
        .underflow(fifo_underflow),
        .fifo_level(fifo_level),
        .last_sample_word(fifo_last_sample_word),
        .axis_sent_count(axis_sent_count),
        .axis_stall_count(axis_stall_count),
        .tlast_count(tlast_count),
        .fifo_backpressure_seen(fifo_backpressure_seen),
        .dropped_sample_count(dropped_sample_count),
        .capture_done_latched(capture_done_latched)
    );
endmodule
