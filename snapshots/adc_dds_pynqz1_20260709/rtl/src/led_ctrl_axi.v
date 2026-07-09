`timescale 1 ns / 1 ps

module led_ctrl_axi #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 5,
    parameter integer DEFAULT_SPEED_DIV = 25000000
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

    output reg [3:0] leds_4bits_tri_o,
    output reg [5:0] rgb_leds_6bits_tri_o,
    input wire [3:0] btns_4bits_tri_i
);
    localparam integer ADDR_LSB = 2;
    localparam integer REG_INDEX_BITS = 3;

    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;

    reg [31:0] ctrl_reg;
    reg [31:0] speed_div_reg;
    reg [31:0] led_value_reg;
    reg [31:0] status_reg;

    reg [31:0] div_count;
    reg [31:0] tick_count;
    reg blink_state;
    reg [1:0] walk_index;
    reg [3:0] btn_sync_0;
    reg [3:0] btn_sync_1;

    wire write_enable;
    wire read_enable;
    wire [REG_INDEX_BITS-1:0] write_index;
    wire [REG_INDEX_BITS-1:0] read_index;
    wire enable;
    wire [2:0] mode;
    wire tick_now;

    assign write_enable = S_AXI_AWREADY && S_AXI_AWVALID && S_AXI_WREADY && S_AXI_WVALID;
    assign read_enable = S_AXI_ARREADY && S_AXI_ARVALID && !S_AXI_RVALID;
    assign write_index = axi_awaddr[ADDR_LSB + REG_INDEX_BITS - 1:ADDR_LSB];
    assign read_index = axi_araddr[ADDR_LSB + REG_INDEX_BITS - 1:ADDR_LSB];
    assign enable = ctrl_reg[0];
    assign mode = ctrl_reg[3:1];
    assign tick_now = (div_count >= speed_div_reg);

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
            ctrl_reg <= 32'h00000000;
            speed_div_reg <= DEFAULT_SPEED_DIV;
            led_value_reg <= 32'h00000000;
        end else if (write_enable) begin
            case (write_index)
                2'h0: ctrl_reg <= S_AXI_WDATA;
                2'h1: speed_div_reg <= S_AXI_WDATA;
                2'h2: led_value_reg <= S_AXI_WDATA;
                default: begin
                    ctrl_reg <= ctrl_reg;
                    speed_div_reg <= speed_div_reg;
                    led_value_reg <= led_value_reg;
                end
            endcase
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
                2'h0: S_AXI_RDATA <= ctrl_reg;
                2'h1: S_AXI_RDATA <= speed_div_reg;
                2'h2: S_AXI_RDATA <= led_value_reg;
                2'h3: S_AXI_RDATA <= status_reg;
                default: S_AXI_RDATA <= 32'h00000000;
            endcase
        end else if (S_AXI_RVALID && S_AXI_RREADY) begin
            S_AXI_RVALID <= 1'b0;
        end
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            div_count <= 32'h00000000;
            tick_count <= 32'h00000000;
            blink_state <= 1'b0;
            walk_index <= 2'b00;
            leds_4bits_tri_o <= 4'h0;
            rgb_leds_6bits_tri_o <= 6'h00;
        end else begin
            if (tick_now) begin
                div_count <= 32'h00000000;
                tick_count <= tick_count + 1'b1;
                blink_state <= ~blink_state;
                walk_index <= walk_index + 1'b1;
            end else begin
                div_count <= div_count + 1'b1;
            end

            if (!enable) begin
                leds_4bits_tri_o <= led_value_reg[3:0];
            end else begin
                case (mode)
                3'd0: leds_4bits_tri_o <= led_value_reg[3:0];
                3'd1: leds_4bits_tri_o <= blink_state ? 4'hF : 4'h0;
                3'd2: leds_4bits_tri_o <= 4'b0001 << walk_index;
                3'd3: leds_4bits_tri_o <= tick_count[3:0];
                default: leds_4bits_tri_o <= led_value_reg[3:0];
                endcase
            end

            rgb_leds_6bits_tri_o <= led_value_reg[9:4];
        end
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            status_reg <= 32'h00000000;
            btn_sync_0 <= 4'h0;
            btn_sync_1 <= 4'h0;
        end else begin
            btn_sync_0 <= btns_4bits_tri_i;
            btn_sync_1 <= btn_sync_0;
            status_reg <= {18'h00000, btn_sync_1, rgb_leds_6bits_tri_o, leds_4bits_tri_o};
        end
    end

endmodule
