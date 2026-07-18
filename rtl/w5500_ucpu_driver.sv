// µCPU (micro cpu) module for driving communication with W5500 Lite module
// using the SPI interface

module w5500_ucpu_driver
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

    output                 out_valid,
    output [         7:0]  out_data,

    // ---------------------------------
    // External SPI interface
    // ---------------------------------

    output                 spi_clk,
    output                 spi_cs_n,
    output                 spi_mosi,
    input                  spi_miso
);

    // -------------------------------------------------------------------------

    logic        axi_awvalid;
    logic        axi_awready;
    logic [ 4:0] axi_aw_block_select;
    logic [15:0] axi_aw_offset_addr;
    logic [ 7:0] axi_awlen;
    logic        axi_wvalid;
    logic        axi_wready;
    logic [ 7:0] axi_wdata;
    logic        axi_wlast;
    logic        axi_bvalid;
    logic        axi_bready;
    logic        axi_arvalid;
    logic        axi_arready;
    logic [ 4:0] axi_ar_block_select;
    logic [15:0] axi_ar_offset_addr;
    logic [ 7:0] axi_arlen;
    logic        axi_rvalid;
    logic        axi_rready;
    logic [ 7:0] axi_rdata;
    logic        axi_rlast;

    // -------------------------------------------------------------------------

    typedef enum {
        WAIT, // BLOCK_UNTIL
        NOP,
        MOVE_BYTE,
        SPI_WRITE_REQ,
        SPI_WRITE_DATA,
        SPI_READ_RED,
        SPI_READ_DATA,
        JUMP
    } opcode_t;

    assign axi_awvalid         = in_valid;
    assign axi_aw_block_select =  5'h5;
    assign axi_aw_offset_addr  = 16'h11;

    assign axi_awlen           = 8'd2;
    assign axi_wvalid          = 1'b1;
    assign axi_wlast           = 1'b1;
    assign axi_wdata           = 8'hAB;

    assign axi_bready          = 1'b1;

    assign axi_arvalid = in_valid;
    assign in_ready  = axi_arready;

    assign axi_ar_block_select =  5'h0;
    assign axi_ar_offset_addr  = 16'h0039;

    assign out_valid = axi_rvalid;
    assign out_data  = axi_rdata;

    // -------------------------------------------------------------------------

    w5500_axi_over_spi w5500_driver_inst
    (
        .clk             ( clk                 ), // input
        .rst             ( rst                 ), // input

        .awvalid         ( axi_awvalid         ), // input  logic
        .awready         ( axi_awready         ), // output logic
        .aw_block_select ( axi_aw_block_select ), // input  logic [ 4:0]
        .aw_offset_addr  ( axi_aw_offset_addr  ), // input  logic [15:0]
        .awlen           ( axi_awlen           ), // input  logic [ 7:0]
        .wvalid          ( axi_wvalid          ), // input  logic
        .wready          ( axi_wready          ), // output logic
        .wdata           ( axi_wdata           ), // input  logic [ 7:0]
        .wlast           ( axi_wlast           ), // input  logic
        .bvalid          ( axi_bvalid          ), // output logic
        .bready          ( axi_bready          ), // input  logic
        .arvalid         ( axi_arvalid         ), // input  logic
        .arready         ( axi_arready         ), // output logic
        .ar_block_select ( axi_ar_block_select ), // input  logic [ 4:0]
        .ar_offset_addr  ( axi_ar_offset_addr  ), // input  logic [15:0]
        .arlen           ( axi_arlen           ), // input  logic [ 7:0]
        .rvalid          ( axi_rvalid          ), // output logic
        .rready          ( axi_rready          ), // input  logic
        .rdata           ( axi_rdata           ), // output logic [ 7:0]
        .rlast           ( axi_rlast           ), // output logic

        .spi_clk         ( spi_clk             ), // output
        .spi_cs_n        ( spi_cs_n            ), // output
        .spi_mosi        ( spi_mosi            ), // output
        .spi_miso        ( spi_miso            )  // input
    );

endmodule
