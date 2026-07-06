module w5500_cpu_driver
# (
    parameter DATA_W = 32;
)
(
    input                  clk,
    input                  reset,

    // ---------------------------------
    // Data interface
    // ---------------------------------

    input                  in_valid,
    output                 in_ready,
    input  [DATA_W - 1:0]  in_data,

    // ---------------------------------
    // External SPI interface
    // ---------------------------------

    output                 spi_clk,
    output                 spi_cs_n,
    output                 spi_mosi,
    input                  spi_miso
);

endmodule
