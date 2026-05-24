`timescale 1 ns / 1 ps

module adc_ctrl_axi #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 7,
    parameter [31:0] VERSION_VALUE = 32'h00010000
) (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 S_AXI_ACLK CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXI, ASSOCIATED_RESET S_AXI_ARESETN" *)
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
    output reg S_AXI_AWREADY,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WDATA" *)
    input wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *)
    input wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WVALID" *)
    input wire S_AXI_WVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WREADY" *)
    output reg S_AXI_WREADY,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BRESP" *)
    output reg [1:0] S_AXI_BRESP,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BVALID" *)
    output reg S_AXI_BVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BREADY" *)
    input wire S_AXI_BREADY,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *)
    input wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARPROT" *)
    input wire [2:0] S_AXI_ARPROT,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *)
    input wire S_AXI_ARVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *)
    output reg S_AXI_ARREADY,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RDATA" *)
    output reg [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RRESP" *)
    output reg [1:0] S_AXI_RRESP,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RVALID" *)
    output reg S_AXI_RVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RREADY" *)
    input wire S_AXI_RREADY,

    output reg enable,
    output reg start_pulse,
    output reg clear_pulse,
    output reg soft_reset,
    output reg [31:0] sample_count_cfg,
    output reg [15:0] adc_half_period_cfg,
    output reg [7:0] sample_delay_cfg,
    output reg [15:0] decimation_cfg,
    output reg [1:0] channel_mask_cfg,
    output reg [1:0] capture_mode_cfg,
    output reg [1:0] trigger_mode_cfg,
    output reg [31:0] pre_delay_cfg,
    output reg buffer_select_cfg,
    output reg [3:0] led_value,
    output reg led_ps_override,

    input wire busy,
    input wire done,
    input wire adc_clk_seen,
    input wire fifo_full,
    input wire fifo_empty,
    input wire fifo_overflow,
    input wire near_rail_a,
    input wire near_rail_b,
    input wire writer_busy,
    input wire writer_done,
    input wire error,
    input wire core_done,
    input wire data_changed_a,
    input wire data_changed_b,
    input wire [11:0] latest_a,
    input wire [11:0] latest_b,
    input wire [31:0] sample_counter,
    input wire [31:0] fifo_level,
    input wire [31:0] saved_counter,
    input wire [31:0] last_sample_word,
    input wire [2:0] debug_state,
    input wire [31:0] axis_sent_count,
    input wire [31:0] axis_stall_count,
    input wire [31:0] tlast_count,
    input wire fifo_backpressure_seen,
    input wire [31:0] dropped_sample_count,
    input wire capture_done_latched,
    input wire [31:0] error_flags_in,

    output reg [31:0] error_flags_latched,
    output reg [3:0] leds_4bits_tri_o
);
    localparam integer ADDR_LSB = 2;
    localparam integer REG_INDEX_BITS = 5;

    localparam [REG_INDEX_BITS-1:0] REG_CTRL = 5'h00;
    localparam [REG_INDEX_BITS-1:0] REG_STATUS = 5'h01;
    localparam [REG_INDEX_BITS-1:0] REG_SAMPLE_COUNT = 5'h02;
    localparam [REG_INDEX_BITS-1:0] REG_ADC_HALF = 5'h03;
    localparam [REG_INDEX_BITS-1:0] REG_SAMPLE_DELAY = 5'h04;
    localparam [REG_INDEX_BITS-1:0] REG_DECIMATION = 5'h05;
    localparam [REG_INDEX_BITS-1:0] REG_CHANNEL_MASK = 5'h06;
    localparam [REG_INDEX_BITS-1:0] REG_CAPTURE_MODE = 5'h07;
    localparam [REG_INDEX_BITS-1:0] REG_TRIGGER_MODE = 5'h08;
    localparam [REG_INDEX_BITS-1:0] REG_PRE_DELAY = 5'h09;
    localparam [REG_INDEX_BITS-1:0] REG_BUFFER_SELECT = 5'h0A;
    localparam [REG_INDEX_BITS-1:0] REG_LATEST_A = 5'h0B;
    localparam [REG_INDEX_BITS-1:0] REG_LATEST_B = 5'h0C;
    localparam [REG_INDEX_BITS-1:0] REG_SAMPLE_COUNTER = 5'h0D;
    localparam [REG_INDEX_BITS-1:0] REG_FIFO_LEVEL = 5'h0E;
    localparam [REG_INDEX_BITS-1:0] REG_ERROR_FLAGS = 5'h0F;
    localparam [REG_INDEX_BITS-1:0] REG_LED_CTRL = 5'h10;
    localparam [REG_INDEX_BITS-1:0] REG_VERSION = 5'h11;
    localparam [REG_INDEX_BITS-1:0] REG_SAVED_COUNTER = 5'h12;
    localparam [REG_INDEX_BITS-1:0] REG_LAST_SAMPLE_WORD = 5'h13;
    localparam [REG_INDEX_BITS-1:0] REG_DEBUG_STATE = 5'h14;
    localparam [REG_INDEX_BITS-1:0] REG_AXIS_SENT_COUNT = 5'h15;
    localparam [REG_INDEX_BITS-1:0] REG_AXIS_STALL_COUNT = 5'h16;
    localparam [REG_INDEX_BITS-1:0] REG_TLAST_COUNT = 5'h17;
    localparam [REG_INDEX_BITS-1:0] REG_FIFO_BACKPRESSURE = 5'h18;
    localparam [REG_INDEX_BITS-1:0] REG_DROPPED_SAMPLE_COUNT = 5'h19;
    localparam [REG_INDEX_BITS-1:0] REG_CAPTURE_DONE_LATCHED = 5'h1A;
    localparam [REG_INDEX_BITS-1:0] REG_CORE_DONE = 5'h1B;

    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;

    wire write_enable;
    wire read_enable;
    wire [REG_INDEX_BITS-1:0] write_index;
    wire [REG_INDEX_BITS-1:0] read_index;
    wire [31:0] status_word;

    assign write_enable = S_AXI_AWREADY && S_AXI_AWVALID && S_AXI_WREADY && S_AXI_WVALID;
    assign read_enable = S_AXI_ARREADY && S_AXI_ARVALID && !S_AXI_RVALID;
    assign write_index = axi_awaddr[ADDR_LSB + REG_INDEX_BITS - 1:ADDR_LSB];
    assign read_index = axi_araddr[ADDR_LSB + REG_INDEX_BITS - 1:ADDR_LSB];
    assign status_word = {
        15'd0,
        core_done,
        capture_done_latched,
        fifo_backpressure_seen,
        (dropped_sample_count != 32'd0),
        data_changed_b,
        data_changed_a,
        error,
        writer_done,
        writer_busy,
        near_rail_b,
        near_rail_a,
        fifo_overflow,
        fifo_empty,
        fifo_full,
        adc_clk_seen,
        done,
        busy
    };

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_AWREADY <= 1'b0;
            axi_awaddr <= {C_S_AXI_ADDR_WIDTH{1'b0}};
        end else if (!S_AXI_AWREADY && S_AXI_AWVALID && S_AXI_WVALID) begin
            S_AXI_AWREADY <= 1'b1;
            axi_awaddr <= S_AXI_AWADDR;
        end else begin
            S_AXI_AWREADY <= 1'b0;
        end
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_WREADY <= 1'b0;
        end else if (!S_AXI_WREADY && S_AXI_WVALID && S_AXI_AWVALID) begin
            S_AXI_WREADY <= 1'b1;
        end else begin
            S_AXI_WREADY <= 1'b0;
        end
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_BVALID <= 1'b0;
            S_AXI_BRESP <= 2'b00;
        end else if (write_enable && !S_AXI_BVALID) begin
            S_AXI_BVALID <= 1'b1;
            S_AXI_BRESP <= 2'b00;
        end else if (S_AXI_BVALID && S_AXI_BREADY) begin
            S_AXI_BVALID <= 1'b0;
        end
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            enable <= 1'b0;
            start_pulse <= 1'b0;
            clear_pulse <= 1'b0;
            soft_reset <= 1'b0;
            sample_count_cfg <= 32'd1024;
            adc_half_period_cfg <= 16'd6;
            sample_delay_cfg <= 8'd1;
            decimation_cfg <= 16'd1;
            channel_mask_cfg <= 2'b11;
            capture_mode_cfg <= 2'd0;
            trigger_mode_cfg <= 2'd0;
            pre_delay_cfg <= 32'd0;
            buffer_select_cfg <= 1'b0;
            led_value <= 4'd0;
            led_ps_override <= 1'b0;
            error_flags_latched <= 32'd0;
        end else begin
            start_pulse <= 1'b0;
            clear_pulse <= 1'b0;
            error_flags_latched <= error_flags_latched | error_flags_in;

            if (write_enable) begin
                case (write_index)
                    REG_CTRL: begin
                        enable <= S_AXI_WDATA[0];
                        start_pulse <= S_AXI_WDATA[1];
                        clear_pulse <= S_AXI_WDATA[2];
                        soft_reset <= S_AXI_WDATA[6];
                    end
                    REG_SAMPLE_COUNT: sample_count_cfg <= S_AXI_WDATA;
                    REG_ADC_HALF: adc_half_period_cfg <= S_AXI_WDATA[15:0];
                    REG_SAMPLE_DELAY: sample_delay_cfg <= S_AXI_WDATA[7:0];
                    REG_DECIMATION: decimation_cfg <= S_AXI_WDATA[15:0];
                    REG_CHANNEL_MASK: channel_mask_cfg <= S_AXI_WDATA[1:0];
                    REG_CAPTURE_MODE: capture_mode_cfg <= S_AXI_WDATA[1:0];
                    REG_TRIGGER_MODE: trigger_mode_cfg <= S_AXI_WDATA[1:0];
                    REG_PRE_DELAY: pre_delay_cfg <= S_AXI_WDATA;
                    REG_BUFFER_SELECT: buffer_select_cfg <= S_AXI_WDATA[0];
                    REG_ERROR_FLAGS: error_flags_latched <= (error_flags_latched | error_flags_in) & ~S_AXI_WDATA;
                    REG_LED_CTRL: begin
                        led_value <= S_AXI_WDATA[3:0];
                        led_ps_override <= S_AXI_WDATA[8];
                    end
                    default: begin
                    end
                endcase
            end

            if (clear_pulse || soft_reset) begin
                error_flags_latched <= 32'd0;
            end
        end
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_ARREADY <= 1'b0;
            axi_araddr <= {C_S_AXI_ADDR_WIDTH{1'b0}};
        end else if (!S_AXI_ARREADY && S_AXI_ARVALID) begin
            S_AXI_ARREADY <= 1'b1;
            axi_araddr <= S_AXI_ARADDR;
        end else begin
            S_AXI_ARREADY <= 1'b0;
        end
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_RVALID <= 1'b0;
            S_AXI_RRESP <= 2'b00;
            S_AXI_RDATA <= 32'h00000000;
        end else if (read_enable) begin
            S_AXI_RVALID <= 1'b1;
            S_AXI_RRESP <= 2'b00;
            case (read_index)
                REG_CTRL: S_AXI_RDATA <= {25'd0, soft_reset, 1'b0, 1'b0, 1'b0, clear_pulse, start_pulse, enable};
                REG_STATUS: S_AXI_RDATA <= status_word;
                REG_SAMPLE_COUNT: S_AXI_RDATA <= sample_count_cfg;
                REG_ADC_HALF: S_AXI_RDATA <= {16'd0, adc_half_period_cfg};
                REG_SAMPLE_DELAY: S_AXI_RDATA <= {24'd0, sample_delay_cfg};
                REG_DECIMATION: S_AXI_RDATA <= {16'd0, decimation_cfg};
                REG_CHANNEL_MASK: S_AXI_RDATA <= {30'd0, channel_mask_cfg};
                REG_CAPTURE_MODE: S_AXI_RDATA <= {30'd0, capture_mode_cfg};
                REG_TRIGGER_MODE: S_AXI_RDATA <= {30'd0, trigger_mode_cfg};
                REG_PRE_DELAY: S_AXI_RDATA <= pre_delay_cfg;
                REG_BUFFER_SELECT: S_AXI_RDATA <= {31'd0, buffer_select_cfg};
                REG_LATEST_A: S_AXI_RDATA <= {20'd0, latest_a};
                REG_LATEST_B: S_AXI_RDATA <= {20'd0, latest_b};
                REG_SAMPLE_COUNTER: S_AXI_RDATA <= sample_counter;
                REG_FIFO_LEVEL: S_AXI_RDATA <= fifo_level;
                REG_ERROR_FLAGS: S_AXI_RDATA <= error_flags_latched;
                REG_LED_CTRL: S_AXI_RDATA <= {23'd0, led_ps_override, 4'd0, led_value};
                REG_VERSION: S_AXI_RDATA <= VERSION_VALUE;
                REG_SAVED_COUNTER: S_AXI_RDATA <= saved_counter;
                REG_LAST_SAMPLE_WORD: S_AXI_RDATA <= last_sample_word;
                REG_DEBUG_STATE: S_AXI_RDATA <= {29'd0, debug_state};
                REG_AXIS_SENT_COUNT: S_AXI_RDATA <= axis_sent_count;
                REG_AXIS_STALL_COUNT: S_AXI_RDATA <= axis_stall_count;
                REG_TLAST_COUNT: S_AXI_RDATA <= tlast_count;
                REG_FIFO_BACKPRESSURE: S_AXI_RDATA <= {31'd0, fifo_backpressure_seen};
                REG_DROPPED_SAMPLE_COUNT: S_AXI_RDATA <= dropped_sample_count;
                REG_CAPTURE_DONE_LATCHED: S_AXI_RDATA <= {31'd0, capture_done_latched};
                REG_CORE_DONE: S_AXI_RDATA <= {31'd0, core_done};
                default: S_AXI_RDATA <= 32'h00000000;
            endcase
        end else if (S_AXI_RVALID && S_AXI_RREADY) begin
            S_AXI_RVALID <= 1'b0;
        end
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            leds_4bits_tri_o <= 4'd0;
        end else if (led_ps_override) begin
            leds_4bits_tri_o <= led_value;
        end else begin
            leds_4bits_tri_o <= {error, done, busy, adc_clk_seen};
        end
    end
endmodule
