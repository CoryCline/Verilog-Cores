module i2c_controller (
    input wire          en,
    input wire [1:0]    mode,
    input wire          clk,
    input wire [6:0]    peripheral_address,
    input wire [7:0]    target_register,
    input wire          rw,
    input wire [15:0]   din,
    output reg [15:0]   dout,
    output wire         scl,
    inout wire          sda,
    output reg          busy = 1'b0
);


reg sda_idle = 1'b1;
reg sda_output = 1'b1;
assign sda = sda_idle ? 1'bz : sda_output;

reg scl_idle = 1'b1;
reg scl_output = 1'b1;
assign scl = scl_idle ? 1'bz : scl_output;

wire i2c_dclk;
wire i2c_sclk;
i2c_clk i2c_clki (
    .en(en),
    .clk(clk),
    .mode(mode),
    .sclk(i2c_sclk),
    .dclk(i2c_dclk)
);

parameter   [7:0] STATE_IDLE            = 8'd0;
parameter   [7:0] STATE_READY           = 8'd1;
parameter   [7:0] STATE_START           = 8'd2;
parameter   [7:0] STATE_ADDR            = 8'd3;
parameter   [7:0] STATE_TARGET_REG      = 8'd4;
parameter   [7:0] STATE_WRITE_BYTE_ONE  = 8'd5;
parameter   [7:0] STATE_READ_BYTE_ONE   = 8'd6;
parameter   [7:0] STATE_WRITE_BYTE_TWO  = 8'd7;
parameter   [7:0] STATE_READ_BYTE_TWO   = 8'd8;
parameter   [7:0] STATE_STOP            = 8'd9;

reg         [7:0] state                 = STATE_IDLE;
reg         [3:0] bit_cnt               = 4'd0;
reg         [7:0] peripheral_addr_plus_rw    = 8'd0;
reg         [7:0] target_reg            = 8'd0;
reg         [7:0] byte_one              = 8'd0;
reg         [7:0] byte_two              = 8'd0;
reg               i2c_clock_enable      = 1'b0;
reg         [7:0] scl_enable            = 1'b0;

reg read_cycle_state = 1'b0;
reg rw_override = 1'b1;

always @(posedge clk)
begin
    if (en)
    begin
        if (scl_enable)
        begin
            scl_idle <= 1'b0;
            scl_output <= i2c_sclk;
        end
        else 
        begin
            scl_idle <= 1'b10;
            scl_output <= 1'b1;
        end
    end
end

always @(negedge i2c_sclk)
begin
    if (en)
    begin
        if (i2c_clock_enable)
        begin
            scl_enable <= 1'b1;
        end
        else 
        begin
            scl_enable <= 1'b0;
        end
    end
end


always @(posedge i2c_dclk)
begin
    case (state)
        STATE_IDLE:
        begin
            sda_idle <= 1'b0;
            sda_output <= 1'b1;
            busy <= 1'b0;
            i2c_clock_enable <= 1'b0;

            if (en)
            begin
                state <= STATE_READY;
            end
        end

        STATE_READY:
        begin
            sda_idle <= 1'b0;
            sda_output <= 1'b1;
            i2c_clock_enable <= 1'b0;
            state <= STATE_START;
        end

        STATE_START:
        begin
            i2c_clock_enable <= 1'b1;
            sda_idle <= 1'b0;
            sda_output <= 1'b0;
            busy <= 1'b1;
            state <= STATE_ADDR;

            if ( (rw == 1) && (rw_override == 1'b1) )
            begin
                peripheral_addr_plus_rw = {peripheral_address, 1'b0};
                rw_override <= 1'b0;
            end
            else
            begin
                peripheral_addr_plus_rw = {peripheral_address, rw};
            end
            target_reg <= target_register;
            byte_one <= din[15:8];
            byte_two <= din[7:0];
        end

        STATE_ADDR:
        begin
            if (en)
            begin
                bit_cnt <= bit_cnt + 1'b1;

                if (bit_cnt == 4'd8)
                begin
                    bit_cnt <= 4'd0;
                    sda_idle <= 1'b1;

                    if (read_cycle_state == 1'b1)
                    begin
                        state <= STATE_READ_BYTE_ONE;
                    end
                    else 
                    begin
                        state <= STATE_TARGET_REG;
                    end
                    
                end
                else 
                begin
                    sda_idle <= 1'b0;
                    sda_output <= peripheral_addr_plus_rw[7];
                    peripheral_addr_plus_rw <= {peripheral_addr_plus_rw[6:0], peripheral_addr_plus_rw[7]};
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
                    sda_idle <= 1'b1;

                    if (rw == 1) // read
                    begin
                        read_cycle_state <= 1'b1;
                        state <= STATE_STOP;
                    end
                    else 
                    if (rw == 0) // write
                    begin
                        state <= STATE_WRITE_BYTE_ONE;
                    end
                end
                else 
                begin
                    sda_idle <= 1'b0;
                    sda_output <= target_reg[7];
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
                    sda_idle <= 1'b0;
                    bit_cnt <= 4'd0;
                    state <= STATE_WRITE_BYTE_TWO;
                end
                else 
                begin
                    sda_idle <= 1'b0;
                    sda_output <= byte_one[7];
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
                    sda_output <= 1'b0;
                    sda_idle <= 1'b0;
                    bit_cnt <= 4'd0;
                    state <= STATE_READ_BYTE_TWO;
                end
                else 
                begin
                    sda_idle <= 1'b1;
                    byte_one <= {byte_one[6:0], sda};
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
                    sda_idle <= 1'b1;
                    bit_cnt <= 4'd0;
                    state <= STATE_STOP;
                end
                else 
                begin
                    sda_idle <= 1'b0;
                    sda_output <= byte_two[7];
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
                    sda_output <= 1'b0;
                    sda_idle <= 1'b0;
                    bit_cnt <= 4'd0;
                    dout <= {byte_one, byte_two};
                    state <= STATE_STOP;
                end
                else 
                begin
                    sda_idle <= 1'b1;
                    byte_two <= {byte_two[6:0], sda};
                end
            end
        end
        
        STATE_STOP:
        begin
            sda_idle <= 1'b0;
            sda_output <= 1'b1;
            busy <= 1'b0;
            i2c_clock_enable <= 1'b0;
            state <= STATE_IDLE;
        end
    endcase
end


endmodule