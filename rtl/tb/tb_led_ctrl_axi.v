`timescale 1 ns / 1 ps

module tb_led_ctrl_axi;
    reg clk = 1'b0;
    reg resetn = 1'b0;

    reg [3:0] awaddr = 4'h0;
    reg [2:0] awprot = 3'b000;
    reg awvalid = 1'b0;
    wire awready;
    reg [31:0] wdata = 32'h0;
    reg [3:0] wstrb = 4'hF;
    reg wvalid = 1'b0;
    wire wready;
    wire [1:0] bresp;
    wire bvalid;
    reg bready = 1'b0;

    reg [3:0] araddr = 4'h0;
    reg [2:0] arprot = 3'b000;
    reg arvalid = 1'b0;
    wire arready;
    wire [31:0] rdata;
    wire [1:0] rresp;
    wire rvalid;
    reg rready = 1'b0;

    wire [3:0] leds;
    reg [31:0] readback;

    localparam [3:0] REG_CTRL = 4'h0;
    localparam [3:0] REG_SPEED_DIV = 4'h4;
    localparam [3:0] REG_LED_VALUE = 4'h8;
    localparam [3:0] REG_STATUS = 4'hC;

    led_ctrl_axi #(
        .DEFAULT_SPEED_DIV(4)
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
        .leds_4bits_tri_o(leds)
    );

    always #5 clk = ~clk;

    initial begin
        repeat (10000) @(posedge clk);
        $display("FINAL: FAIL simulation timeout");
        $finish;
    end

    task axi_write;
        input [3:0] addr;
        input [31:0] data;
        begin
            @(negedge clk);
            awaddr = addr;
            wdata = data;
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
        input [3:0] addr;
        output [31:0] data;
        begin
            @(negedge clk);
            araddr = addr;
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
            data = rdata;
            @(negedge clk);
            rready = 1'b0;
            @(posedge clk);
        end
    endtask

    task expect_led;
        input [3:0] expected;
        begin
            if (leds !== expected) begin
                $display("FINAL: FAIL expected LED=%h got=%h at time=%0t", expected, leds, $time);
                $finish;
            end
        end
    endtask

    initial begin
        repeat (8) @(posedge clk);
        resetn <= 1'b1;
        repeat (4) @(posedge clk);

        axi_write(REG_LED_VALUE, 32'h0000000A);
        axi_write(REG_CTRL, 32'h00000000);
        repeat (2) @(posedge clk);
        expect_led(4'hA);

        axi_write(REG_SPEED_DIV, 32'h00000002);
        axi_write(REG_CTRL, 32'h00000003);
        repeat (8) @(posedge clk);
        if (leds !== 4'h0 && leds !== 4'hF) begin
            $display("FINAL: FAIL blink mode produced LED=%h", leds);
            $finish;
        end

        axi_write(REG_CTRL, 32'h00000005);
        repeat (10) @(posedge clk);
        if (leds === 4'h0) begin
            $display("FINAL: FAIL walk mode stuck at zero");
            $finish;
        end

        axi_write(REG_CTRL, 32'h00000007);
        repeat (12) @(posedge clk);
        axi_read(REG_STATUS, readback);
        if (readback[7:4] === 4'h0) begin
            $display("FINAL: FAIL status tick counter did not advance status=%h", readback);
            $finish;
        end

        $display("FINAL: PASS led_ctrl_axi direct/blink/walk/counter modes");
        $finish;
    end
endmodule
