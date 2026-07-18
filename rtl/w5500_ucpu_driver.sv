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

    logic [ 4:0] debug_ar_block_select;
    logic [15:0] debug_ar_offset_addr;

    assign debug_ar_block_select = 5'h0;
    assign debug_ar_offset_addr  = 16'h0039;

               logic       debug_arvalid;
    (* keep *) logic       debug_arready;
    (* keep *) logic       debug_rvalid;
    (* keep *) logic [7:0] debug_rdata;
    (* keep *) logic       debug_rlast;


    // initial
    // begin
    //     @ (negedge rst);
        
    //     repeat (100) @ (posedge clk);

    //     debug_arvalid = 1'b1;

    //     repeat (100) @ (posedge clk);

    //     repeat (5)
    //     begin
    //         debug_arvalid = ~ debug_arvalid;
    //         repeat (1000) @ (posedge clk);
    //     end
    // end

    assign debug_arvalid = in_valid;

    // assign in_ready = ^ { debug_arready, debug_rvalid, debug_rdata, debug_rlast };
    assign in_ready = debug_arready;

    assign out_valid = debug_rvalid;
    assign out_data  = debug_rdata;

    w5500_axi_over_spi w5500_driver_inst
    (
        .clk             ( clk                   ), // input
        .rst             ( rst                   ), // input

        .awvalid         ( '0                    ), // input  logic
        .awready         (                       ), // output logic
        .aw_block_select (                       ), // input  logic [ 4:0]
        .aw_offset_addr  (                       ), // input  logic [15:0]
        .awlen           (                       ), // input  logic [ 7:0]
        .wvalid          ( '0                    ), // input  logic
        .wready          (                       ), // output logic
        .wdata           (                       ), // input  logic [ 7:0]
        .wlast           (                       ), // input  logic
        .bvalid          (                       ), // output logic
        .bready          (                       ), // input  logic

        .arvalid         ( debug_arvalid         ), // input  logic
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
