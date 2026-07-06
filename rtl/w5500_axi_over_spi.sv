module w5500_axi_over_spi
(
    input         clk,
    input         reset,

    // ---------------------------------
    // AXI-like control and data interface
    // ---------------------------------

    input         awvalid,
    output        awready,
    input  [31:0] awaddr,
    // input  [ 7:0] awlen, // Cound be used instead of wlast

    input         wvalid,
    output        wready,
    input  [ 7:0] wdata,
    input         wlast,

    output        bvalid,
    input         bready,

    input         arvalid,
    output        arready,
    input  [31:0] araddr,
    input  [ 7:0] arlen,

    output        rvalid,
    input         rready,
    output [ 7:0] rdata,
    output        rlast,

    // ---------------------------------
    // External SPI interface
    // ---------------------------------

    output        spi_clk,
    output        spi_cs_n,
    output        spi_mosi,
    input         spi_miso
);

    // -------------------------------------------------------------------------

    typedef enum logic [3:0] {
        ST_IDLE          = 4'd0,
        ST_WAIT_REQ_DATA = 4'd1, // When aw or ar requests comes
        ST_SPI_REQ_ADDR  = 4'd2,
        ST_SPI_REQ_WRITE = 4'd3,
        ST_SPI_REQ_READ  = 4'd4,
        ST_RESP_DATA     = 4'd5
    } state_t;

    state_t state, next_state;

    // -------------------------------------------------------------------------

endmodule
