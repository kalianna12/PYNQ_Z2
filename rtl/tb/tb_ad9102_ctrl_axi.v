`timescale 1 ns / 1 ps

module tb_ad9102_ctrl_axi;
    reg clk = 1'b0;
    reg resetn = 1'b0;
    always #4 clk = ~clk;

    reg [5:0] awaddr = 0;
    reg [2:0] awprot = 0;
    reg awvalid = 0;
    wire awready;
    reg [31:0] wdata = 0;
    reg [3:0] wstrb = 4'hF;
    reg wvalid = 0;
    wire wready;
    wire [1:0] bresp;
    wire bvalid;
    reg bready = 0;
    reg [5:0] araddr = 0;
    reg [2:0] arprot = 0;
    reg arvalid = 0;
    wire arready;
    wire [31:0] rdata;
    wire [1:0] rresp;
    wire rvalid;
    reg rready = 0;

    wire cs_n;
    reg sdo = 0;
    wire sdio;
    wire sclk;
    reg clk_cmos_in = 0;
    wire trigger_n;
    wire ad9102_reset_n;

    reg [31:0] observed;
    integer observed_bits;
    reg [31:0] response = 32'h0000BEEF;
    integer response_bit;
    reg capture_enable = 0;

    ad9102_ctrl_axi #(
        .DEFAULT_SPI_DIV(1)
    ) dut (
        .S_AXI_ACLK(clk),
        .S_AXI_ARESETN(resetn),
        .S_AXI_AWADDR(awaddr),
        .S_AXI_AWPROT(awprot),
        .S_AXI_AWVALID(awvalid),
        .S_AXI_AWREADY(awready),
        .S_AXI_WDATA(wdata),
        .S_AXI_WSTRB(wstrb),
        .S_AXI_WVALID(wvalid),
        .S_AXI_WREADY(wready),
        .S_AXI_BRESP(bresp),
        .S_AXI_BVALID(bvalid),
        .S_AXI_BREADY(bready),
        .S_AXI_ARADDR(araddr),
        .S_AXI_ARPROT(arprot),
        .S_AXI_ARVALID(arvalid),
        .S_AXI_ARREADY(arready),
        .S_AXI_RDATA(rdata),
        .S_AXI_RRESP(rresp),
        .S_AXI_RVALID(rvalid),
        .S_AXI_RREADY(rready),
        .ad9102_cs_n(cs_n),
        .ad9102_sdo(sdo),
        .ad9102_sdio(sdio),
        .ad9102_sclk(sclk),
        .ad9102_clk_cmos_in(clk_cmos_in),
        .ad9102_trigger_n(trigger_n),
        .ad9102_reset_n(ad9102_reset_n)
    );

    task axi_write;
        input [5:0] address;
        input [31:0] value;
        begin
            @(negedge clk);
            awaddr = address;
            wdata = value;
            awvalid = 1'b1;
            wvalid = 1'b1;
            bready = 1'b1;
            while (!(awready && wready)) begin
                @(posedge clk);
            end
            @(negedge clk);
            awvalid = 1'b0;
            wvalid = 1'b0;
            while (!bvalid) begin
                @(posedge clk);
            end
            @(negedge clk);
            bready = 1'b0;
            @(posedge clk);
        end
    endtask

    task axi_read;
        input [5:0] address;
        output [31:0] value;
        begin
            @(negedge clk);
            araddr = address;
            arvalid = 1'b1;
            rready = 1'b1;
            while (!arready) begin
                @(posedge clk);
            end
            @(negedge clk);
            arvalid = 1'b0;
            while (!rvalid) begin
                @(posedge clk);
            end
            value = rdata;
            @(negedge clk);
            rready = 1'b0;
            @(posedge clk);
        end
    endtask

    always @(negedge cs_n) begin
        observed = 32'h00000000;
        observed_bits = 0;
        response_bit = 31;
        sdo = response[31];
        capture_enable = 1'b1;
    end

    always @(posedge sclk) begin
        if (!cs_n && capture_enable) begin
            observed = {observed[30:0], sdio};
            observed_bits = observed_bits + 1;
        end
    end

    always @(negedge sclk) begin
        if (!cs_n && response_bit > 0) begin
            response_bit = response_bit - 1;
            sdo = response[response_bit];
        end
    end

    always @(posedge cs_n) begin
        capture_enable = 1'b0;
    end

    reg [31:0] readback;
    initial begin
        repeat (5) @(posedge clk);
        resetn = 1'b1;
        repeat (3) @(posedge clk);

        axi_write(6'h08, 32'h00001234);
        axi_write(6'h0C, 32'h0000ABCD);
        axi_write(6'h00, 32'h00000001);
        @(posedge cs_n);
        #1;
        if (observed_bits != 32 || observed != 32'h1234ABCD) begin
            $fatal(1, "write SPI frame mismatch: bits=%0d frame=%08x",
                   observed_bits, observed);
        end

        axi_write(6'h08, 32'h00001234);
        axi_write(6'h0C, 32'h00000000);
        axi_write(6'h00, 32'h00000003);
        @(posedge cs_n);
        repeat (2) @(posedge clk);
        axi_read(6'h10, readback);
        if (observed_bits != 32 || observed != 32'h92340000) begin
            $fatal(1, "read SPI frame mismatch: bits=%0d frame=%08x",
                   observed_bits, observed);
        end
        if (readback[15:0] != 16'hBEEF) begin
            $fatal(1, "read SPI payload mismatch: %04x", readback[15:0]);
        end

        axi_write(6'h18, 32'h00000000);
        repeat (2) @(posedge clk);
        if (trigger_n !== 1'b0 || ad9102_reset_n !== 1'b0) begin
            $fatal(1, "GPIO control mismatch");
        end

        $display("PASS: AD9102 AXI/SPI frame, readback, and GPIO control");
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "simulation timeout");
    end

endmodule
