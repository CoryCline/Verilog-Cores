`timescale 1ns/1ps

module i2c_controller_tb();

reg tb_clk = 1'b1;
reg tb_en  = 1'b0;
wire tb_dout;
wire tb_scl;
wire tb_sda;
wire tb_busy;


i2c_controller i2c_controlleri (
    .en(tb_en),
    .mode(2'd1),
    .clk(tb_clk),
    .peripheral_address(7'b1001001),
    .target_register(8'b10010110),
    .rw(1'b1),
    .din(16'b1010101011001100),
    .dout(tb_dout),
    .scl(tb_scl),
    .sda(tb_sda),
    .busy(tb_busy)
);

always @(negedge tb_busy)
begin
    tb_en <= 1'b0;
    #100000 tb_en <= 1'b1;
end

always
begin
    #1 tb_clk <= ~tb_clk;
end

initial 
begin
    #10000 tb_en <= 1'b1;
end

endmodule