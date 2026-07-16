`include "config.svh"

module common_top
# (
    parameter  clk_mhz       = 50,
               w_key         = 4,
               w_sw          = 8,
               w_led         = 8,
               w_digit       = 8,
               w_gpio        = 100,

               screen_width  = 640,
               screen_height = 480,

               w_red         = 4,
               w_green       = 4,
               w_blue        = 4,

               w_x           = $clog2 ( screen_width  ),
               w_y           = $clog2 ( screen_height )
)
(
    input                        clk,
    input                        slow_clk,
    input                        rst,

    // Keys, switches, LEDs

    input        [w_key   - 1:0] key,
    input        [w_sw    - 1:0] sw,
    output logic [w_led   - 1:0] led,

    // A dynamic seven-segment display

    output logic [          7:0] abcdefgh,
    output logic [w_digit - 1:0] digit,

    // Graphics

    input        [w_x     - 1:0] x,
    input        [w_y     - 1:0] y,

    output logic [w_red   - 1:0] red,
    output logic [w_green - 1:0] green,
    output logic [w_blue  - 1:0] blue,

    // Microphone, sound output and UART

    input        [         23:0] mic,
    output       [         15:0] sound,

    input                        uart_rx,
    output                       uart_tx,

    // General-purpose Input/Output

    inout        [w_gpio  - 1:0] gpio
);

    //------------------------------------------------------------------------

    // assign led        = '0;
    // assign abcdefgh   = '0;
    // assign digit      = '0;
       assign red        = '0;
       assign green      = '0;
       assign blue       = '0;
       assign sound      = '0;
       assign uart_tx    = '1;

    //------------------------------------------------------------------------

    // TODO: Implementation

    // logic        sample_valid /*synthesis keep*/;
    // logic [23:0] sample_raw;
    // logic [15:0] sample /*synthesis keep*/;

    // Zaewoo pins
    // inmp441_mic_i2s_receiver_with_valid
    // # (
    //     .clk_mhz ( clk_mhz  )
    // )
    // i_microphone
    // (
    //     .clk          ( clk          ),
    //     .rst          ( rst          ),

    //     .lr_ch        ( 1'b0         ),
    //     .sample_valid ( sample_valid ),
    //     .sample       ( sample       ),

    //     .lr           ( gpio [5]     ),  // P33
    //     .ws           ( gpio [3]     ),  // P31
    //     .sck          ( gpio [1]     ),  // P28
    //     .sd           ( gpio [0]     )   // P30
    // );
    // assign gpio [4] = 1'b0;  // P34 - GND
    // assign gpio [2] = 1'b1;  // P32 - VCC

    // inmp441_mic_i2s_receiver_with_valid
    // # (
    //     .clk_mhz ( clk_mhz  )
    // )
    // i_microphone
    // (
    //     .clk     ( clk      ),
    //     .rst     ( rst      ),

    //     .lr_ch        ( 1'b0         ),
    //     .sample_valid ( sample_valid ),
    //     .sample       ( sample_raw   ),

    //     .lr      ( gpio [0] ), // JP1 pin 1
    //     .ws      ( gpio [2] ), // JP1 pin 3
    //     .sck     ( gpio [4] ), // JP1 pin 5
    //     .sd      ( gpio [5] )  // JP1 pin 6
    // );
    // assign gpio [1] = 1'b0; // GND - JP1 pin 2
    // assign gpio [3] = 1'b1; // VCC - JP1 pin 4

    //------------------------------------------------------------------------

    // localparam CLK_FREQUENCY = 50_000_000;
    // localparam SPI_FREQUENCY = 2_000_000;
    // localparam IDLE_NS = 200;

    // spi #(
    //     .CLK_FREQUENCY ( CLK_FREQUENCY ),
    //     .SPI_FREQUENCY ( SPI_FREQUENCY ),
    //     .IDLE_NS       ( IDLE_NS       )
    // ) spi_i (
    //     .clk         ( clk ),
    //     .reset_n     ( ~rst ),
    //     .tx_request  (  ),
    //     .tx_data     (  ),
    //     .rx_request  (  ),
    //     .rx_data     (  ),
    //     .rx_valid    (  ),
    //     .ack_request (  ),
    //     .active      (  ),
    //     .spi_csn     ( gpio[ 36+10 ] ),
    //     .spi_mosi    ( gpio[ 36+11 ] ), 
    //     .spi_miso    ( gpio[ 36+12 ] ),
    //     .spi_clk     ( gpio[ 36+13 ] )
    // );

    // logic             eth_valid;
    // logic             eth_ready;
    // logic [31:0][7:0] eth_data;

    // logic [63:0] eth_counter, eth_counter_next;

    // counter_timer
    // #(
    //     .MAX_VALUE ( 100_000_000 )
    // ) 
    // cnt_inst
    // (
    //     .clk          ( clk                ), // input
    //     .rst          ( rst                ), // input
    //     .soft_rst     (                 ), // input
    //     .start        (                 ), // input
    //     .tick_valid   ( '1                ), // input
    //     .finished     (                 ), // output logic
    //     .counter      ( eth_counter                ), // output logic [CNT_W-1:0]
    //     .counter_next ( eth_counter_next                )  // output logic [CNT_W-1:0]
    // );

    // localparam int BIT_N = 13;
    // logic eth_strobe;

    // assign eth_strobe = { eth_counter[BIT_N], eth_counter_next[BIT_N] } == 2'b10;

    // assign led[6] = eth_counter[BIT_N];
    // assign led[7] = eth_strobe;
    // assign eth_valid = sw[5] & (eth_strobe | sw[6]);
    // assign led[8] = gpio[ 36 + 10 ];

    // w5500_ucpu_driver
    // # (
    //     .DATA_W ( 32 )
    // )
    // w5500_adapter_inst
    // (
    //     .clk      ( clk ),
    //     .rst      ( rst ),

    //     .in_valid ( eth_valid ),
    //     .in_ready ( eth_ready ),
    //     .in_data  (    ),

    //     .out_data ( abcdefgh ),

    //     .spi_cs_n ( gpio[ 36+10 ] ),
    //     .spi_mosi ( gpio[ 36+11 ] ),
    //     .spi_miso ( gpio[ 36+12 ] ),
    //     .spi_clk  ( gpio[ 36+13 ] )
    // );

    // GPIO 36 pins, 0 to 35; ARDUINO pins

    // assign led[5] = eth_ready & sw[2];

    // assign digit = 8'd1;

    //------------------------------------------------------------------------
    
    // assign sample = { sample_raw[23], sample_raw[ 0 +: 17] };
    // assign sample = sample_raw;

    // assign led[1] = ^ { sample_valid, sample };

    //------------------------------------------------------------------------
    // Logic Analyzer for I2S INMP441
    //------------------------------------------------------------------------

    // logic_analyzer la_inst (
    //     .acq_clk        ( clk          ), // input
    //     .storage_enable ( sample_valid ), // input
    //     .acq_data_in    ( sample_cnt   ) // input [23:0]
    //     // .acq_trigger_in (  )  // input [31:0]
    // );

    // virtual_probe probe0_i
    // (
    //     .source ( ),
    //     .probe  ( clk_cnt )
    // );

    // virtual_probe probe1_i
    // (
    //     .source ( ),
    //     .probe  ( sample_cnt )
    // );

    //------------------------------------------------------------------------
    // Logic Analyzer for SPI W5500
    //------------------------------------------------------------------------

    (* keep *) logic spi_clk;
    (* keep *) logic spi_cs_n;
    (* keep *) logic spi_mosi;
    (* keep *) logic spi_miso;
    (* keep *) logic spi_int;
    (* keep *) logic pll_clk_56mhz;
    (* keep *) logic pll_clk_14mhz;

    // quartus_pll pll_inst (
    //     .inclk0 ( clk           ),
    //     .c0     ( pll_clk_56mhz ),
    //     .c1     ( pll_clk_14mhz )
    // );

    // assign spi_cs_n = gpio[ 36+10 ];
    // assign spi_mosi = gpio[ 36+11 ];
    // assign spi_miso = gpio[ 36+12 ];
    // assign spi_clk  = gpio[ 36+13 ];
    // assign spi_int  = '0 ;

    assign spi_cs_n = gpio[ 29 ];
    assign spi_mosi = gpio[ 31 ];
    assign spi_miso = gpio[ 33 ];
    assign spi_clk  = gpio[ 35 ];
    assign spi_int  = '0 ;

    logic [100:0] temp1, temp2, temp3;

    always_ff @( posedge clk )
    begin
        temp1 <= { spi_clk, spi_cs_n, spi_mosi, spi_miso, spi_int };
    end
    
    // always_ff @( posedge pll_clk_56mhz )
    // begin
    //     temp2 <= { spi_clk, spi_cs_n, spi_mosi, spi_miso, spi_int };
    // end
    
    // always_ff @( posedge pll_clk_14mhz )
    // begin
    //     temp3 <= { spi_clk, spi_cs_n, spi_mosi, spi_miso, spi_int };
    // end

    assign led[4] = ^ { temp1, temp2, temp3 };

    assign led[8] = sw[8];

    //------------------------------------------------------------------------

endmodule
