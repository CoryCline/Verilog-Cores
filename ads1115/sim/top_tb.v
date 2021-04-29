`timescale 1ns/1ps

module top_tb();

reg tb_clk = 1'b1;

top topi (
    .clk(tb_clk)
);

always
begin
    #1 tb_clk <= ~tb_clk;
end

endmodule