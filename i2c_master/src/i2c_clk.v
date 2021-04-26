/* This module should take in a 100Mhz clock and output the following
    Standard mode   : 100 Khz
    Fast mode       : 400 Khz
*/

module i2c_clk(
    input wire          en,                                 // Enabled the clock module
    input wire          clk,                                // 100 Mhz input clock
    input wire [1:0]    mode,                               // Manages the I2C bus speed
    output reg          sclk    = 1'b1,                     // This is the resulting clock for SCL
    output reg          dclk    = 1'b1                      // This is the resulting clock for SDA
);

parameter [1:0] MODE_STANDARD   = 2'd0;                     // Standard mode at 100 Khz
parameter [1:0] MODE_FAST       = 2'd1;                     // Fast mode at 400 Khz
reg       [1:0] MODE_STATE      = MODE_STANDARD;            // Default to standard mode

reg      [15:0] clock_counter   = 16'd0;                    // This is used to generate a clock at 4X the desired bus speed
reg             quarter_clk     = 1'b0;                     // This is the resulting clock at 4X the desired speed

always @(posedge clk)                                       // This loop generates the clock at 4X the desired bus speed
begin
    MODE_STATE <= mode;                                         // Grab the mode from the input wire
    if (en)                                                     // Run all of this when en is HIGH
    begin
        case (MODE_STATE)                                           // Generate a clock based on the mode
            MODE_STANDARD:                                              // Standard mode at 100 Khz
            begin
                if (clock_counter < 16'd624)                                // 624 ticks generates a 400 Khz clock
                begin
                    clock_counter <= clock_counter + 1'b1;                      // Increment clock_counter
                end
                else begin                                                  // The counter has reached 624 ticks
                    clock_counter <= 16'd0;                                     // Reset clock_counter to 0
                    quarter_clk <= ~quarter_clk;                                // Toggle quarter_clk
                end
            end

            MODE_FAST:
            begin
                if (clock_counter < 16'd155)                                // 155 ticks generates a 1.6 Mhz clock
                begin
                    clock_counter <= clock_counter + 1'b1;                      // Increment clock_counter
                end
                else begin                                                  // The counter has reached 155 ticks
                    clock_counter <= 16'd0;                                     // Reset clock_counter to 0
                    quarter_clk <= ~quarter_clk;                                // Toggle quarter_clk
                end
            end
        endcase
    end
end

reg [1:0] step_counter = 2'd0;                              // Used to count to 3 to track the 4 states of the staggered clock

always @(posedge quarter_clk)                               // This loop is used to generate the final sclk and dclk signals
begin
    step_counter <= step_counter + 1'b1;                        // Increment step_counter by 1
    case (step_counter)                                             // This is checking states 0 - 3 to assign the clock levels
        2'd0:                                                           // In this state dclk should be LOW and sclk should be HIGH
        begin
            dclk <= 1'b0;                                                   // dclk LOW
            sclk <= 1'b1;                                                   // sclk HIGH
        end
        2'd1:                                                           // In this state dclk should be LOW and sclk should be LOW
        begin
            dclk <= 1'b0;                                                   // dclk LOW
            sclk <= 1'b0;                                                   // sclk LOW
        end
        2'd2:                                                           // In this state dclk should be HIGH and sclk should be LOW
        begin
            dclk <= 1'b1;                                                   // dclk HIGH
            sclk <= 1'b0;                                                   // sclk LOW
        end
        2'd3:                                                           // In this state dclk should be HIGH and sclk should be HIGH
        begin
            dclk <= 1'b1;                                                   // dclk HIGH
            sclk <= 1'b1;                                                   // sclk HIGH
        end
        default: step_counter <= 2'd0;                                  // In this state reset the step_counter
    endcase
end


endmodule