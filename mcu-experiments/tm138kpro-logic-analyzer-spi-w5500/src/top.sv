module top
(
    input  sys_clk_50mhz,   // (P16) EMC_CLK 50MHz
    input  som_usr_sys_rst, // (U4)
    // input  som_jtag_recfg,  // (AE16)

    // output [2:0] twi_mux_cfg, // SFP0 sel 3'b000, SFP1 sel 3'b100
    // inout twi_mux_scl,
    // inout twi_mux_sda,

    output sfp0_tx_disable,
    input  sfp0_rx_loss,

    output sfp1_tx_disable,
    input  sfp1_rx_loss,

    input  [3:0] dock_btn, // dock buttons
    output [5:0] dock_led, // dock leds

    inout  [41:0] gpio     // dock gpio (sdram)
);
    
    // PLL0 -> Q1_refclk 1 // better for 125mhz m.2

    // PLL1 -> Q1_refclk 0 // Preferred
    // PLL1 CLK0.2 -> USR_CLK (N22)

    // SFP0 -> Q1 L0
    // SFP1 -> Q1 L1

    assign dock_led[3] = ^ dock_btn;

    assign sfp0_tx_disable = 1'b0;
    assign sfp1_tx_disable = 1'b0;

    assign dock_led[0] = ~sfp0_rx_loss;
    assign dock_led[1] = ~sfp1_rx_loss;

    logic [63:0] blink_wire;

    assign dock_led[2] = blink_wire[25];

    counter i_blinker (
        .clk     ( sys_clk_50mhz   ),
        .rst     ( som_usr_sys_rst ),
        .trig    ( '1              ),
        .counter ( blink_wire      )
    );

    // -------------------------------------------------------------------------

    logic spi_clk;
    logic spi_cs_n;
    logic spi_mosi;
    logic spi_miso;
    logic spi_int;

    logic pll_clk_56mhz;
    logic pll_clk_14mhz;

    Gowin_PLL pll_inst (
        .clkin   ( sys_clk_50mhz ),
        .clkout0 ( pll_clk_56mhz ),
        .clkout1 ( pll_clk_14mhz )
    );

    assign spi_clk  = gpio[33];
    assign spi_cs_n = gpio[34];
    assign spi_mosi = gpio[35];
    assign spi_miso = gpio[36];
    assign spi_int  = gpio[37];

    // -------------------------------------------------------------------------

endmodule
