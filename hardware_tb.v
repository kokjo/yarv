`timescale 1 ns / 1 ps

module hardware_tb;
    reg clk = 1;
    always #5 clk = !clk;

    wire led;
    wire flash_csb;
    wire flash_clk;
    wire flash_io0;
    wire flash_io1;
    wire flash_io2;
    wire flash_io3;

    hardware dut (
        .clk_16mhz(clk),
        .user_led(led),
        .flash_csb(flash_csb),
        .flash_clk(flash_clk),
        .flash_io0(flash_io0),
        .flash_io1(flash_io1),
        .flash_io2(flash_io2),
        .flash_io3(flash_io3)
    );

    spiflash flash (
        .csb(flash_csb),
        .clk(flash_clk),
        .io0(flash_io0),
        .io1(flash_io1),
        .io2(flash_io2),
        .io3(flash_io3)
    );

    initial begin
        $dumpfile("hardware_tb.vcd");
        $dumpvars(0, hardware_tb);

        repeat (100) begin
            repeat (10000) @(posedge clk);
            $display("+10000 cycles");
        end

        $finish;
    end
endmodule
