module ads1115 (
    input wire          clk,
    input wire          en,
    output wire [15:0]  dout,
    output wire         scl,
    inout wire          sda
);


reg     [1:0]   i2c_mode        = 2'd0;
reg     [6:0]   i2c_addr        = 7'b1001001;
reg     [7:0]   i2c_target_reg  = 8'd0;
reg             i2c_rw          = 1'b0;
reg    [15:0]   i2c_din         = 16'd0;
reg             i2c_en          = 1'b0;
wire            i2c_busy;

i2c_controller i2c_controlleri (
    .en(i2c_en),
    .mode(i2c_mode),
    .clk(clk),
    .peripheral_address(i2c_addr),
    .target_register(i2c_target_reg),
    .rw(i2c_rw),
    .din(i2c_din),
    .dout(dout),
    .scl(scl),
    .sda(sda),
    .busy(i2c_busy)
);



parameter STATE_CONFIG  = 1'b0;
parameter STATE_DATA    = 1'b1;

reg state = STATE_CONFIG;

always @(posedge clk)
begin
    if (en)
    begin
        case (state)

            STATE_CONFIG:
            begin
                i2c_addr <= 7'b1001001;
                i2c_target_reg <= 8'b00000001;
                i2c_din <= 16'b1000010010000011; 
                i2c_rw <= 1'b0;
                i2c_en <= 1'b1;
            end

            STATE_DATA:
            begin
                i2c_addr <= 7'b1001001; 
                i2c_target_reg <= 8'b00000000; 
                i2c_rw <= 1'b1;
                i2c_en <= 1'b1;
            end
        endcase
    end
end

reg read_start = 1'b0;

always @(negedge i2c_busy)
begin
    if (en)
    begin
        if (read_start)
        begin
            state <= STATE_DATA;
        end
        else 
        begin
            read_start <= 1'b1;
        end
    end
end

endmodule