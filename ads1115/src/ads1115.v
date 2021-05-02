module ads1115 (
    input wire          clk,
    input wire          en,
    input wire  [2:0]   channel,
    input wire          mode, // 0: single shot and 1: continuous
    output reg [15:0]   a0_dout             = 16'd0,
    output reg [15:0]   a1_dout             = 16'd0,
    output reg [15:0]   a2_dout             = 16'd0,
    output reg [15:0]   a3_dout             = 16'd0,
    output wire         scl,
    inout wire          sda
);

/*  Bit[15] OS: Operational Status / Single-Shot Conversion Start
    CAN ONLY BE WRITTEN IN POWER DOWN MODE
    Possible Options:
        WRITE BIT:
            0: No Effect
            1: Begin a single conversation
        READ BIT:
            0: Device is currently performing a conversation
            1: Device is not performing a conversation

    Selection: 0 because it will be set later
*/
reg OS_config = 1'b0;

/*  Bits[14:12] MUX[2:0] Input Multiplexer Configuration
    Possible Options:
        000 : AINP = AIN0 and AINN = AIN1 (default) 
        001 : AINP = AIN0 and AINN = AIN3 
        010 : AINP = AIN1 and AINN = AIN3
        011 : AINP = AIN2 and AINN = AIN3  
        100 : AINP = AIN0 and AINN = GND
        101 : AINP = AIN1 and AINN = GND
        110 : AINP = AIN2 and AINN = GND
        111 : AINP = AIN3 and AINN = GND

    Selection: Use an input wire 'channel' to choose between A0, A1, A2, or A3
*/
reg [2:0] MUX_config = 3'b100;

/*  Bits[11:9] PGA[2:0] Programmable Gain Amplifier Configuration
    Possible Options
        000 : FS = ±6.144V(1) 
        001 : FS = ±4.096V(1) 
        010 : FS = ±2.048V (default) 
        011 : FS = ±1.024V 
        100 : FS = ±0.512V
        101 : FS = ±0.256V
        110 : FS = ±0.256V
        111 : FS = ±0.256V

    Selection: 001 because I need to read up to 3.3 volts
*/
reg [2:0] PGA_config = 3'b001;

/*  Bit[8] MODE - Device Operating Mode
    Possible Options
        0 : Continuous conversion mode
        1 : Power-down single-shot mode (default)

    Selection: 1 because I will set it later
*/
reg MODE_config = 1'b1;

/*  Bits[7:5] DR[2:0] Data Rate
    Possible Options
        000 : 8SPS 
        001 : 16SPS 
        010 : 32SPS 
        011 : 64SPS 
        100 : 128SPS (default)
        101 : 250SPS
        110 : 475SPS
        111 : 860SPS

    Selection: 100 because 128 samples per second is more than sufficient for this.
*/
reg [2:0] DR_config = 3'b100;

/*  Bit[4] COMP_MODE - Comparator mode 
    Possible Options
        0 : Traditional comparator with hysteresis (default)
        1 : Window comparator

    Selection: 0 because I don't need to use the comparitor.
*/
reg COMP_MODE_config = 1'b0;

/*  Bit[3] COMP_POL - Comparitor Polarity
    Possible Options
        0 : Active Low (default)
        1 : Active High

    Selection: 0 because I don't need to use the comparitor 
*/
reg COMP_POL_config = 1'b0;

/*  Bit[2] COMP_LAT - Latching Comparitor
    This controls the polarity of the ALERT/RDY pin
    Possible Options
        0 : Active Low (Default)
        1 : Active High

    Selection: 0 because active low is more reliable for failure detection
*/
reg COMP_LAT_config = 1'b0;

/*  Bits[1:0] COMP_QUE - Comparator queue and disable
    Possible Options
        00 : Assert ALERT after one conversion out of comparator range
        01 : Assert ALERT after two conversions out of comparator range
        10 : Assert ALERT after four conversions out of comparator range
        11 : Disable comparitor (default)

    Selection: 11 because I don't plan to use the comparitor
*/
reg [1:0] COMP_QUE_config = 2'b11;

reg [15:0] ADS1115_CONFIG = 16'd0;

reg     [1:0]   i2c_mode        = 2'd0;
reg             i2c_data_length = 1'b1;
reg     [6:0]   i2c_addr        = 7'b1001001;
reg     [7:0]   i2c_target_reg  = 8'd0;
reg             i2c_rw          = 1'b0;
reg    [15:0]   i2c_din         = 16'd0;
reg             i2c_en          = 1'b0;
wire            i2c_busy;
wire   [15:0]   i2c_dout;
reg    [15:0]   i2c_data        = 16'd0;

i2c_controller i2c_controlleri (
    .en(i2c_en),
    .mode(i2c_mode),
    .clk(clk),
    .peripheral_address(i2c_addr),
    .target_register(i2c_target_reg),
    .rw(i2c_rw),
    .data_length(i2c_data_length),
    .din(i2c_din),
    .dout(i2c_dout),
    .scl(scl),
    .sda(sda),
    .busy(i2c_busy)
);

parameter       READ                        = 1'b1;
parameter       WRITE                       = 1'b0;

parameter       CONTINUOUS_MODE             = 1'b0;
parameter       SINGLESHOT_MODE             = 1'b1;

parameter [2:0] CHANNEL_A0                  = 3'b100;
parameter [2:0] CHANNEL_A1                  = 3'b101;
parameter [2:0] CHANNEL_A2                  = 3'b110;
parameter [2:0] CHANNEL_A3                  = 3'b111;

parameter [7:0] CONVERSION_REGISTER         = 8'b00000000;
parameter [7:0] CONFIG_REGISTER             = 8'b00000001;

parameter [7:0] STATE_IDLE                  = 8'd0;
parameter [7:0] STATE_START                 = 8'd1;
parameter [7:0] STATE_READ_CONFIG           = 8'd2;
parameter [7:0] STATE_CHECK_CONFIG          = 8'd3;
parameter [7:0] STATE_SET_CONVERSION_REG    = 8'd5;
parameter [7:0] STATE_READ_CONVERSION       = 8'd6;
parameter [7:0] STATE_OUTPUT                = 8'd7;
parameter [7:0] STATE_CONTINUOUS_START      = 8'd8;
parameter [7:0] STATE_CONTINUOUS_SET_CONV   = 8'd9; 
parameter [7:0] STATE_CONTINUOUS_READ       = 8'd10;
parameter [7:0] STATE_CONTINUOUS_OUTPUT     = 8'd11;
reg       [7:0] state                       = STATE_IDLE;

reg move_on = 1'b0;



always @(posedge clk)
begin
    case (state)
        STATE_IDLE:
        begin 
            if (en)
            begin
                if (mode == SINGLESHOT_MODE)
                begin
                    MODE_config <= mode;
                    MUX_config <= channel;
                    OS_config <= 1'b1;

                    i2c_target_reg <= CONFIG_REGISTER;
                    i2c_rw <= WRITE;

                    state <= STATE_START;
                end
                
                else 
                if (mode == CONTINUOUS_MODE)
                begin
                    MODE_config <= mode;
                    MUX_config <= channel;
                    OS_config <= 1'b0;

                    i2c_target_reg <= CONFIG_REGISTER;
                    i2c_rw <= WRITE;
                    state <= STATE_CONTINUOUS_START;
                end
            end
        end

        STATE_START:
        begin 

            ADS1115_CONFIG = {OS_config, MUX_config, PGA_config, MODE_config, DR_config, COMP_MODE_config, COMP_POL_config, COMP_LAT_config, COMP_QUE_config};
            i2c_din <= ADS1115_CONFIG;
            i2c_en <= 1'b1;

            if (i2c_busy == 1'b1) // The first time through i2c_busy will be 0.  When it's on, set move_on.
            begin
                move_on <= 1'b1;
            end
            
            
            if ( (i2c_busy == 1'b0) && (move_on == 1'b1 ) ) // When i2c_busy returns low, setup the next state and go there
            begin
                move_on <= 1'b0;
                OS_config <= 1'b0;
                ADS1115_CONFIG = {OS_config, MUX_config, PGA_config, MODE_config, DR_config, COMP_MODE_config, COMP_POL_config, COMP_LAT_config, COMP_QUE_config};
                i2c_target_reg <= CONFIG_REGISTER;
                i2c_rw <= READ;
                state <= STATE_READ_CONFIG;
            end
        end

        STATE_READ_CONFIG:
        begin 
            
            ADS1115_CONFIG = {OS_config, MUX_config, PGA_config, MODE_config, DR_config, COMP_MODE_config, COMP_POL_config, COMP_LAT_config, COMP_QUE_config};
            i2c_din <= ADS1115_CONFIG;
            i2c_en <= 1'b1;

            if (i2c_busy == 1'b1) // The first time through i2c_busy will be 0.  When it's on, set move_on.
            begin
                move_on <= 1'b1;
            end

            if ( (i2c_busy == 1'b0) && (move_on == 1'b1 ) ) // When i2c_busy returns low, setup the next state and go there
            begin
                move_on <= 1'b0;
                state <= STATE_CHECK_CONFIG;
            end
        end

        STATE_CHECK_CONFIG:
        begin             
            
            i2c_data <= i2c_dout;

            if (i2c_data[15] == 1'b0)
            begin
                OS_config <= 1'b0;
                ADS1115_CONFIG = {OS_config, MUX_config, PGA_config, MODE_config, DR_config, COMP_MODE_config, COMP_POL_config, COMP_LAT_config, COMP_QUE_config};
                i2c_target_reg <= CONFIG_REGISTER;
                i2c_rw <= READ;
                state <= STATE_READ_CONFIG;
            end

            else 
            if (i2c_data[15] == 1'b1)
            begin
                OS_config <= 1'b0;
                ADS1115_CONFIG = {OS_config, MUX_config, PGA_config, MODE_config, DR_config, COMP_MODE_config, COMP_POL_config, COMP_LAT_config, COMP_QUE_config};
                i2c_target_reg <= CONVERSION_REGISTER;
                i2c_rw <= WRITE;
                
                state <= STATE_SET_CONVERSION_REG;
            end
        end

        STATE_SET_CONVERSION_REG:
        begin
            i2c_en <= 1'b1;

            if (i2c_busy == 1'b1) // The first time through i2c_busy will be 0.  When it's on, set move_on.
            begin
                move_on <= 1'b1;
            end

            if ( (i2c_busy == 1'b0) && (move_on == 1'b1 ) ) // When i2c_busy returns low, setup the next state and go there
            begin
                move_on <= 1'b0;
                i2c_en <= 1'b0;
                i2c_target_reg <= CONVERSION_REGISTER;
                i2c_rw <= READ;
                state <= STATE_READ_CONVERSION;
            end
        end

        STATE_READ_CONVERSION:
        begin 
            i2c_en <= 1'b1;

            if (i2c_busy == 1'b1) // The first time through i2c_busy will be 0.  When it's on, set move_on.
            begin
                move_on <= 1'b1;
            end

            if ( (i2c_busy == 1'b0) && (move_on == 1'b1 ) ) // When i2c_busy returns low, setup the next state and go there
            begin
                move_on <= 1'b0;
                i2c_data <= i2c_dout;
                state <= STATE_OUTPUT;
            end
        end

        STATE_OUTPUT:
        begin 
            if (channel == CHANNEL_A0)
            begin
                a0_dout <= i2c_data;
                state <= STATE_IDLE;
            end

            else 
            if (channel == CHANNEL_A1)
            begin
                a1_dout <= i2c_data;
                state <= STATE_IDLE;
            end

            else 
            if (channel == CHANNEL_A2)
            begin
                a2_dout <= i2c_data;
                state <= STATE_IDLE;
            end

            else 
            if (channel == CHANNEL_A3)
            begin
                a3_dout <= i2c_data;
                state <= STATE_IDLE;
            end
        end

        STATE_CONTINUOUS_START:
        begin 
            ADS1115_CONFIG = {OS_config, MUX_config, PGA_config, MODE_config, DR_config, COMP_MODE_config, COMP_POL_config, COMP_LAT_config, COMP_QUE_config};
            i2c_din <= ADS1115_CONFIG;
            i2c_en <= 1'b1;

            if (i2c_busy == 1'b1) // The first time through i2c_busy will be 0.  When it's on, set move_on.
            begin
                move_on <= 1'b1;
            end
            
            
            if ( (i2c_busy == 1'b0) && (move_on == 1'b1 ) ) // When i2c_busy returns low, setup the next state and go there
            begin
                i2c_en <= 1'b0;
                move_on <= 1'b0;
                i2c_target_reg <= CONVERSION_REGISTER;
                i2c_rw <= WRITE;
                state <= STATE_CONTINUOUS_SET_CONV;
            end
        end

        STATE_CONTINUOUS_SET_CONV:
        begin 
            i2c_en <= 1'b1;

            if (i2c_busy == 1'b1) // The first time through i2c_busy will be 0.  When it's on, set move_on.
            begin
                move_on <= 1'b1;
            end
            
            
            if ( (i2c_busy == 1'b0) && (move_on == 1'b1 ) ) // When i2c_busy returns low, setup the next state and go there
            begin
                move_on <= 1'b0;
                i2c_target_reg <= CONVERSION_REGISTER;
                i2c_rw <= READ;
                state <= STATE_CONTINUOUS_READ;
            end
        end

        

        STATE_CONTINUOUS_READ:
        begin 
            if (en == 1'b1)
            begin
                if (i2c_busy == 1'b0)
                begin
                    i2c_target_reg <= CONVERSION_REGISTER;
                    i2c_rw <= READ;
                    i2c_en <= 1'b1;
                end

                else 
                if (i2c_busy == 1'b1)
                begin
                    i2c_en <= 1'b0;
                    state <= STATE_CONTINUOUS_OUTPUT;
                end
            end

            else 
            if (en == 1'b0)
            begin
                state <= STATE_IDLE;
            end
        end

        STATE_CONTINUOUS_OUTPUT:
        begin 
            if (i2c_busy == 1'b0)
            begin
                if (channel == CHANNEL_A0)
                begin
                    a0_dout <= i2c_dout;
                    state <= STATE_CONTINUOUS_READ;
                end

                else 
                if (channel == CHANNEL_A1)
                begin
                    a1_dout <= i2c_dout;
                    state <= STATE_CONTINUOUS_READ;
                end

                else 
                if (channel == CHANNEL_A2)
                begin
                    a2_dout <= i2c_dout;
                    state <= STATE_CONTINUOUS_READ;
                end

                else 
                if (channel == CHANNEL_A3)
                begin
                    a3_dout <= i2c_dout;
                    state <= STATE_CONTINUOUS_READ;
                end
            end

            else 
            if (i2c_busy == 1'b1)
            begin
                i2c_en <= 1'b0;
                state <= STATE_CONTINUOUS_OUTPUT;
            end
        end
    endcase
end
endmodule