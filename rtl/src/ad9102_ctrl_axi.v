`timescale 1 ns / 1 ps

module ad9102_ctrl_axi #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 6,
    parameter integer DEFAULT_SPI_DIV = 7
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

    output reg ad9102_cs_n,
    input wire ad9102_sdo,
    output reg ad9102_sdio,
    output reg ad9102_sclk,
    input wire ad9102_clk_cmos_in,
    output reg ad9102_trigger_n,
    output reg ad9102_reset_n
);
    localparam integer ADDR_LSB = 2;
    localparam integer REG_INDEX_BITS = 4;

    localparam [2:0] SPI_IDLE  = 3'd0;
    localparam [2:0] SPI_SETUP = 3'd1;
    localparam [2:0] SPI_HIGH  = 3'd2;
    localparam [2:0] SPI_LOW   = 3'd3;
    localparam [2:0] SPI_HOLD  = 3'd4;

    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;

    reg [14:0] spi_addr_reg;
    reg [15:0] spi_wdata_reg;
    reg [15:0] spi_rdata_reg;
    reg [15:0] spi_div_reg;
    reg [31:0] command_count;
    reg [31:0] error_count;

    reg spi_busy;
    reg spi_done;
    reg spi_is_read;
    reg [2:0] spi_state;
    reg [5:0] spi_bit_count;
    reg [15:0] spi_div_count;
    reg [31:0] spi_tx_shift;
    reg [31:0] spi_rx_shift;

    (* ASYNC_REG = "TRUE" *) reg clk_cmos_sync_0;
    (* ASYNC_REG = "TRUE" *) reg clk_cmos_sync_1;

    wire write_enable;
    wire read_enable;
    wire [REG_INDEX_BITS-1:0] write_index;
    wire [REG_INDEX_BITS-1:0] read_index;
    wire spi_tick;

    assign write_enable = S_AXI_AWREADY && S_AXI_AWVALID &&
                          S_AXI_WREADY && S_AXI_WVALID;
    assign read_enable = S_AXI_ARREADY && S_AXI_ARVALID && !S_AXI_RVALID;
    assign write_index = axi_awaddr[ADDR_LSB + REG_INDEX_BITS - 1:ADDR_LSB];
    assign read_index = axi_araddr[ADDR_LSB + REG_INDEX_BITS - 1:ADDR_LSB];
    assign spi_tick = (spi_div_count >= spi_div_reg);

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
                4'h0: S_AXI_RDATA <= 32'h00000000;
                4'h1: S_AXI_RDATA <= {
                    24'h000000,
                    clk_cmos_sync_1,
                    ad9102_reset_n,
                    ad9102_trigger_n,
                    spi_is_read,
                    spi_done,
                    spi_busy,
                    2'b00
                };
                4'h2: S_AXI_RDATA <= {17'h00000, spi_addr_reg};
                4'h3: S_AXI_RDATA <= {16'h0000, spi_wdata_reg};
                4'h4: S_AXI_RDATA <= {16'h0000, spi_rdata_reg};
                4'h5: S_AXI_RDATA <= {16'h0000, spi_div_reg};
                4'h6: S_AXI_RDATA <= {
                    30'h00000000, ad9102_reset_n, ad9102_trigger_n
                };
                4'h7: S_AXI_RDATA <= 32'd180000000;
                4'h8: S_AXI_RDATA <= 32'hAD910201;
                4'h9: S_AXI_RDATA <= command_count;
                4'hA: S_AXI_RDATA <= error_count;
                default: S_AXI_RDATA <= 32'h00000000;
            endcase
        end else if (S_AXI_RVALID && S_AXI_RREADY) begin
            S_AXI_RVALID <= 1'b0;
        end
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            clk_cmos_sync_0 <= 1'b0;
            clk_cmos_sync_1 <= 1'b0;
        end else begin
            clk_cmos_sync_0 <= ad9102_clk_cmos_in;
            clk_cmos_sync_1 <= clk_cmos_sync_0;
        end
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            spi_addr_reg <= 15'h0000;
            spi_wdata_reg <= 16'h0000;
            spi_rdata_reg <= 16'h0000;
            spi_div_reg <= DEFAULT_SPI_DIV[15:0];
            command_count <= 32'h00000000;
            error_count <= 32'h00000000;
            spi_busy <= 1'b0;
            spi_done <= 1'b0;
            spi_is_read <= 1'b0;
            spi_state <= SPI_IDLE;
            spi_bit_count <= 6'd0;
            spi_div_count <= 16'd0;
            spi_tx_shift <= 32'h00000000;
            spi_rx_shift <= 32'h00000000;
            ad9102_cs_n <= 1'b1;
            ad9102_sdio <= 1'b0;
            ad9102_sclk <= 1'b0;
            ad9102_trigger_n <= 1'b1;
            ad9102_reset_n <= 1'b1;
        end else begin
            if (write_enable) begin
                case (write_index)
                    4'h0: begin
                        if (S_AXI_WDATA[2]) begin
                            spi_done <= 1'b0;
                        end
                        if (S_AXI_WDATA[0]) begin
                            if (!spi_busy) begin
                                spi_busy <= 1'b1;
                                spi_done <= 1'b0;
                                spi_is_read <= S_AXI_WDATA[1];
                                spi_state <= SPI_SETUP;
                                spi_bit_count <= 6'd0;
                                spi_div_count <= 16'd0;
                                spi_tx_shift <= {
                                    S_AXI_WDATA[1],
                                    spi_addr_reg,
                                    spi_wdata_reg
                                };
                                spi_rx_shift <= 32'h00000000;
                                ad9102_cs_n <= 1'b0;
                                ad9102_sclk <= 1'b0;
                                ad9102_sdio <= S_AXI_WDATA[1];
                                command_count <= command_count + 1'b1;
                            end else begin
                                error_count <= error_count + 1'b1;
                            end
                        end
                    end
                    4'h2: spi_addr_reg <= S_AXI_WDATA[14:0];
                    4'h3: spi_wdata_reg <= S_AXI_WDATA[15:0];
                    4'h5: spi_div_reg <= S_AXI_WDATA[15:0];
                    4'h6: begin
                        ad9102_trigger_n <= S_AXI_WDATA[0];
                        ad9102_reset_n <= S_AXI_WDATA[1];
                    end
                    4'hA: begin
                        if (S_AXI_WDATA[0]) begin
                            error_count <= 32'h00000000;
                        end
                    end
                    default: begin
                    end
                endcase
            end

            if (spi_busy) begin
                if (spi_tick) begin
                    spi_div_count <= 16'd0;
                    case (spi_state)
                        SPI_SETUP: begin
                            ad9102_sclk <= 1'b1;
                            spi_rx_shift <= {spi_rx_shift[30:0], ad9102_sdo};
                            spi_state <= SPI_HIGH;
                        end
                        SPI_HIGH: begin
                            ad9102_sclk <= 1'b0;
                            if (spi_bit_count == 6'd31) begin
                                spi_state <= SPI_HOLD;
                            end else begin
                                spi_bit_count <= spi_bit_count + 1'b1;
                                spi_tx_shift <= {spi_tx_shift[30:0], 1'b0};
                                ad9102_sdio <= spi_tx_shift[30];
                                spi_state <= SPI_LOW;
                            end
                        end
                        SPI_LOW: begin
                            ad9102_sclk <= 1'b1;
                            spi_rx_shift <= {spi_rx_shift[30:0], ad9102_sdo};
                            spi_state <= SPI_HIGH;
                        end
                        SPI_HOLD: begin
                            ad9102_cs_n <= 1'b1;
                            ad9102_sclk <= 1'b0;
                            ad9102_sdio <= 1'b0;
                            spi_rdata_reg <= spi_rx_shift[15:0];
                            spi_busy <= 1'b0;
                            spi_done <= 1'b1;
                            spi_state <= SPI_IDLE;
                        end
                        default: begin
                            spi_busy <= 1'b0;
                            spi_done <= 1'b1;
                            spi_state <= SPI_IDLE;
                            ad9102_cs_n <= 1'b1;
                            ad9102_sclk <= 1'b0;
                        end
                    endcase
                end else begin
                    spi_div_count <= spi_div_count + 1'b1;
                end
            end
        end
    end

endmodule
