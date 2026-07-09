module w5500_cpu_driver
# (
    parameter DATA_W = 32
)
(
    input                  clk,
    input                  rst,

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

    logic [ 4:0] debug_ar_block_select;
    logic [15:0] debug_ar_offset_addr;

    assign debug_ar_block_select = 5'h0;
    assign debug_ar_offset_addr  = 16'h0039;

    (* keep *) logic       debug_arready;
    (* keep *) logic       debug_rvalid;
    (* keep *) logic [7:0] debug_rdata;
    (* keep *) logic       debug_rlast;

    assign in_ready = ^ { debug_arready, debug_rvalid, debug_rdata, debug_rlast };

    w5500_axi_over_spi w5500_driver_inst
    (
        .clk             ( clk                   ), // input
        .rst             ( rst                   ), // input

        .awvalid         (                       ), // input  logic
        .awready         (                       ), // output logic
        .aw_block_select (                       ), // input  logic [ 4:0]
        .aw_offset_addr  (                       ), // input  logic [15:0]
        .awlen           (                       ), // input  logic [ 7:0]
        .wvalid          (                       ), // input  logic
        .wready          (                       ), // output logic
        .wdata           (                       ), // input  logic [ 7:0]
        .wlast           (                       ), // input  logic
        .bvalid          (                       ), // output logic
        .bready          (                       ), // input  logic

        .arvalid         ( 1'b1                  ), // input  logic
        .arready         ( debug_arready         ), // output logic
        .ar_block_select ( debug_ar_block_select ), // input  logic [ 4:0]
        .ar_offset_addr  ( debug_ar_offset_addr  ), // input  logic [15:0]
        .arlen           ( 8'd1                  ), // input  logic [ 7:0]
        .rvalid          ( debug_rvalid          ), // output logic
        .rready          ( 1'b1                  ), // input  logic
        .rdata           ( debug_rdata           ), // output logic [ 7:0]
        .rlast           ( debug_rlast           ), // output logic

        .spi_clk         ( spi_clk               ), // output
        .spi_cs_n        ( spi_cs_n              ), // output
        .spi_mosi        ( spi_mosi              ), // output
        .spi_miso        ( spi_miso              )  // input
    );

endmodule
