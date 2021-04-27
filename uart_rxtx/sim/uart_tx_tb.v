`timescale  1ns/1ps

module uart_tx_tb();

reg tb_clk = 1'b1;

uart_tx txi (
    .clk(tb_clk),
    .en(1'b1),
    .data_in(8'haa)
);


always
begin
    #5 tb_clk <= ~tb_clk;
end

endmodule