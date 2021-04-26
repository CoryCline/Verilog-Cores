module i2c_master (
    input wire          en,
    input wire [1:0]    mode,
    input wire          clk,
    input wire [6:0]    slave_address,
    input wire [7:0]    target_register,
    input wire          rw,
    input wire [15:0]   din,
    output reg [15:0]   dout,
    output reg          scl = 1'b1,
    output reg          sda = 1'b1,
    output reg          busy = 1'b0
);

wire i2c_dclk;
i2c_clk i2c_clki (
    .en(en),
    .clk(clk),
    .mode(mode),
    .sclk(i2c_sclk),
    .dclk(i2c_dclk)
);

parameter   [7:0] STATE_START           = 8'd0;
parameter   [7:0] STATE_ADDR            = 8'd1;
parameter   [7:0] STATE_TARGET_REG      = 8'd2;
parameter   [7:0] STATE_WRITE_BYTE_ONE  = 8'd3;
parameter   [7:0] STATE_READ_BYTE_ONE   = 8'd4;
parameter   [7:0] STATE_WRITE_BYTE_TWO  = 8'd5;
parameter   [7:0] STATE_READ_BYTE_TWO   = 8'd6;
parameter   [7:0] STATE_STOP            = 8'd7;

reg         [7:0] state                 = STATE_START;
reg         [3:0] bit_cnt               = 4'd0;
reg         [7:0] slave_addr_plus_rw    = 8'd0;
reg         [7:0] target_reg            = 8'd0;
reg         [7:0] byte_one              = 8'd0;
reg         [7:0] byte_two              = 8'd0;
reg               i2c_clock_enable      = 1'b0;

always @(posedge clk)
begin
    if (en)
    begin
        if (i2c_clock_enable)
        begin
            scl <= i2c_sclk;
        end
        else 
        begin
            scl <= 1'b1;
        end
    end
end

always @(posedge i2c_dclk)
begin
    if (en)
    begin
        case (state)
            STATE_START:
            begin
                sda <= 1'b0;
                busy <= 1'b1;
                state <= STATE_ADDR;
                slave_addr_plus_rw = {slave_address, rw};
                target_reg <= target_register;
                byte_one <= din[15:8];
                byte_two <= din[7:0];
            end

            STATE_ADDR:
            begin
                if (en)
                begin
                    i2c_clock_enable <= 1'b1;

                    bit_cnt <= bit_cnt + 1'b1;

                    if (bit_cnt == 4'd8)
                    begin
                        bit_cnt <= 4'd0;
                        sda <= 1'bz;

                        state <= STATE_TARGET_REG;
                    end
                    else 
                    begin
                        sda <= slave_addr_plus_rw[7];
                        slave_addr_plus_rw <= {slave_addr_plus_rw[6:0], slave_addr_plus_rw[7]};
                    end
                end
            end

            STATE_TARGET_REG:
            begin
                if (en)
                begin
                    bit_cnt <= bit_cnt + 1'b1;

                    if (bit_cnt == 4'd8)
                    begin
                        bit_cnt <= 4'd0;
                        sda <= 1'bz;

                        if (rw == 0) // read
                        begin
                            state <= STATE_READ_BYTE_ONE;
                        end
                        else 
                        if (rw == 1) // write
                        begin
                            state <= STATE_WRITE_BYTE_ONE;
                        end
                    end
                    else 
                    begin
                        sda <= target_reg[7];
                        target_reg <= {target_reg[6:0], target_reg[7]};
                    end
                end
            end

            STATE_WRITE_BYTE_ONE:
            begin
                if (en)
                begin
                    bit_cnt <= bit_cnt + 1'b1;

                    if (bit_cnt == 4'd8)
                    begin
                        sda <= 1'bz;
                        bit_cnt <= 4'd0;
                        state <= STATE_WRITE_BYTE_TWO;
                    end
                    else 
                    begin
                        sda <= byte_one[7];
                        byte_one <= {byte_one[6:0], byte_one[7]};
                    end
                end
            end

            STATE_READ_BYTE_ONE:
            begin
                if (en)
                begin
                    bit_cnt <= bit_cnt + 1'b1;

                    if (bit_cnt == 4'd8)
                    begin
                        sda <= 1'bz;
                        bit_cnt <= 4'd0;
                        state <= STATE_READ_BYTE_TWO;
                    end
                    else 
                    begin
                        byte_one <= {byte_one[7:1], sda};
                    end
                end
            end

            STATE_WRITE_BYTE_TWO:
            begin
                if (en)
                begin
                    bit_cnt <= bit_cnt + 1'b1;

                    if (bit_cnt == 4'd8)
                    begin
                        sda <= 1'bz;
                        bit_cnt <= 4'd0;
                        state <= STATE_STOP;
                    end
                    else 
                    begin
                        sda <= byte_two[7];
                        byte_two <= {byte_two[6:0], byte_two[7]};
                    end
                end
            end

            STATE_READ_BYTE_TWO:
            begin
                if (en)
                begin
                    bit_cnt <= bit_cnt + 1'b1;

                    if (bit_cnt == 4'd8)
                    begin
                        sda <= 1'bz;
                        bit_cnt <= 4'd0;
                        state <= STATE_STOP;
                    end
                    else 
                    begin
                        byte_two <= {byte_two[7:1], sda};
                    end
                end
            end
            
            STATE_STOP:
            begin
                busy <= 1'b0;
                sda <= 1'b1;
                i2c_clock_enable <= 1'b0;
                state <= STATE_START;
                dout <= {byte_one, byte_two};
            end
        endcase
    end
end


endmodule