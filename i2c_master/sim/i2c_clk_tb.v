`timescale 1ns/1ps

module i2c_clk_tb();

reg tb_clk =1'b1;

i2c_clk i2c_clki (
    .en(1'b1),
    .clk(tb_clk),
    .mode(2'd0)
);

always
begin
    #1 tb_clk <= ~tb_clk;
end

endmodule

