/* This module should take in a 100Mhz clock and output the following
    Standard mode   : 100 Khz
    Fast mode       : 400 Khz
*/

module i2c_clk(
    input wire          en,
    input wire          clk,
    input wire [1:0]    mode,
    output reg          sclk    = 1'b1,
    output reg          dclk    = 1'b1
);

reg quarter_clk = 1'b0;

parameter [1:0] MODE_STANDARD   = 2'd0;
parameter [1:0] MODE_FAST       = 2'd1;
reg       [1:0] MODE_STATE      = MODE_STANDARD;

reg      [15:0] clock_counter   = 16'd0;

// Generate a clock at 4x the desired hz
always @(posedge clk)
begin
    MODE_STATE <= mode;
    if (en)
    begin
        case (MODE_STATE)
            MODE_STANDARD:      // 2.5 us bit width
            begin
                if (clock_counter < 16'd624)
                begin
                    clock_counter <= clock_counter + 1'b1;
                end
                else begin
                    clock_counter <= 16'd0;
                    quarter_clk <= ~quarter_clk;
                end
            end

            MODE_FAST:
            begin
                if (clock_counter < 16'd155)
                begin
                    clock_counter <= clock_counter + 1'b1;
                end
                else begin
                    clock_counter <= 16'd0;
                    quarter_clk <= ~quarter_clk;
                end
            end
        endcase
    end
end

reg [1:0] step_counter = 2'd0;

// Generate sclk and sdclk
always @(posedge quarter_clk)
begin
    step_counter <= step_counter + 1'b1;
    case (step_counter)
        2'd0:
        begin
            dclk <= 1'b0;
            sclk <= 1'b1;
        end
        2'd1:
        begin
            dclk <= 1'b0;
            sclk <= 1'b0;
        end
        2'd2:
        begin
            dclk <= 1'b1;
            sclk <= 1'b0;
        end
        2'd3:
        begin
            dclk <= 1'b1;
            sclk <= 1'b1;
        end
        default: step_counter <= 2'd0;
    endcase
end


endmodule