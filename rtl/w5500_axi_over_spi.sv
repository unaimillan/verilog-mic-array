module w5500_axi_over_spi
(
    input         clk,
    input         rst,

    // ---------------------------------
    // AXI-like control and data interface
    // ---------------------------------

    // input         awvalid,
    // output        awready,
    // input  [31:0] awaddr,
    // input  [ 7:0] awlen, // Cound be used instead of wlast

    // input         wvalid,
    // output        wready,
    // input  [ 7:0] wdata,
    // input         wlast,

    // output        bvalid,
    // input         bready,

    input         arvalid,
    output        arready,
    input  [31:0] araddr,
    // input  [ 7:0] arlen,

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
        ST_PROCESS_REQ,
        ST_SPI_SEND_ADDR,
        ST_SPI_READ_DATA,
        ST_SEND_RESP
        
    } state_t;

    state_t state, next_state;

    logic       spi_addr_transfer_active;
    logic       spi_addr_transfer_done;
    logic [1:0] spi_addr_ptr;

    logic spi_read_transfer_active;
    logic spi_read_transfer_done;

    logic result_read_transfer_active;
    logic result_read_transfer_done;

    // -------------------------------------------------------------------------

    logic       spi_rx_request;
    logic       spi_tx_request;
    logic       spi_ack_request;
    logic       spi_rx_valid;
    logic [7:0] spi_tx_data;
    logic [7:0] spi_rx_data;

    // -------------------------------------------------------------------------

    logic [15:0] spi_req_addr;         // 16 bit offset from { block_select }
    logic [ 7:0] spi_req_control;

    logic [ 4:0] spi_req_block_select; // 5'h0 - common register, 5'h01 - sock0 reg, 5'h1F - sock7 rx buf
    logic        spi_req_rwb;          // read - 0, write - 1
    logic [ 1:0] spi_req_mode;         // variable by SCSn - 00, 1 byte - 01, 2 byte - 10, 4 byte - 11

    assign spi_req_control = { spi_req_block_select, spi_req_rwb, spi_req_mode };

    logic [2:0][7:0] spi_req_addr_data;

    assign spi_req_addr_data = { spi_req_addr, spi_req_control};

    // -------------------------------------------------------------------------

    always_comb begin
        next_state = state;
        spi_addr_transfer_active    = '0;
        spi_read_transfer_active    = '0;
        result_read_transfer_active = '0;

        if ( state == ST_IDLE )
        begin
            if ( arvalid )
            begin
                next_state = ST_SPI_SEND_ADDR;
            end
        end
        else if ( state == ST_SPI_SEND_ADDR )
        begin
            spi_addr_transfer_active = '1;

            if ( spi_addr_transfer_done )
            begin
                next_state = ST_SPI_READ_DATA;
            end
        end
        else if ( state == ST_SPI_READ_DATA )
        begin
            spi_read_transfer_active = '1;

            if ( spi_read_transfer_done )
            begin
                next_state = ST_SEND_RESP;
            end
        end
        else if ( state == ST_SEND_RESP )
        begin
            result_read_transfer_active = '1;

            if ( result_read_transfer_done )
            begin
                next_state = ST_IDLE;
            end
        end
    end

    // -------------------------------------------------------------------------

    always_ff @( posedge clk )
    begin
        if ( rst )
        begin
            spi_addr_ptr <= 0;
        end
        else if ( spi_ack_request )
        begin
            if ( spi_addr_transfer_done )
            begin
                spi_addr_ptr <= '0;
            end
            else if ( spi_addr_transfer_active )
            begin
                spi_addr_ptr <= spi_addr_ptr + 1'b1;
            end 
        end
    end

    assign spi_addr_transfer_done = ( spi_addr_ptr == 2'b10 ) & spi_ack_request;

    always_comb
    begin
        spi_tx_request = '0;
        spi_tx_data    = '0;

        if ( spi_addr_transfer_active )
        begin
            spi_tx_request = '1;
            spi_tx_data = spi_req_addr_data[spi_addr_ptr];
        end
    end

    // -------------------------------------------------------------------------

    spi #(
        .DATASIZE      ( 8          ),
        .CLK_FREQUENCY ( 50_000_000 ),
        .SPI_FREQUENCY ( 2_000_000  ),
        .IDLE_NS       ( 200        )
    )
    spi_inst
    (
        .clk         (   clk           ),
        .reset_n     ( ~ rst           ),

        .rx_request  ( spi_rx_request  ),
        .tx_request  ( spi_tx_request  ),
        .ack_request ( spi_ack_request ),
        .rx_valid    ( spi_rx_valid    ),
        .tx_data     ( spi_tx_data     ), // [DATASIZE-1:0] 
        .rx_data     ( spi_rx_data     ), // [DATASIZE-1:0] 
        .active      (                 ),

        .spi_clk     ( spi_clk         ),
        .spi_csn     ( spi_cs_n        ),
        .spi_sdi     ( spi_mosi        ),
        .spi_sdo     ( spi_miso        )
    );

endmodule
