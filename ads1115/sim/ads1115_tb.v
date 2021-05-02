`timescale 1ns/1ps

module ads1115_tb();

reg         tb_clk      = 1'b1;
reg         tb_en       = 1'b1;
wire        tb_a0_dout;
wire        tb_a1_dout;
wire        tb_a2_dout;
wire        tb_a3_dout;

// Test these
reg [2:0]   tb_channel  = 3'd100;
reg         tb_mode     = 1'b0;

ads1115 ads1115i (
    .clk(tb_clk),
    .en(tb_en),
    .channel(tb_channel),
    .mode(tb_mode), // 1: single shot and 0: continuous
    .a0_dout(tb_a0_dout),
    .a1_dout(tb_a1_dout),
    .a2_dout(tb_a1_dout),
    .a3_dout(tb_a1_dout),
    .scl(scl),
    .sda(sda)
);

always
begin
    #1 tb_clk <= ~tb_clk;
end


endmodule

