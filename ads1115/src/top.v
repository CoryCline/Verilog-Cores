module top(
    input wire clk,
    inout wire sda,
    output wire scl
);


ads1115 ads1115i  (
    .clk(clk),
    .en(1'b1),
    .sda(sda),
    .scl(scl)
);

endmodule