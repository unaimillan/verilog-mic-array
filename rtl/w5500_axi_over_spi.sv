module w5500_axi_over_spi
(
    input         clk,
    input         rst,

    // ---------------------------------
    // AXI-like control and data interface
    // ---------------------------------

    input  logic        awvalid,
    output logic        awready,
    input  logic [31:0] awaddr,
    input  logic [ 7:0] awlen,

    input  logic        wvalid,
    output logic        wready,
    input  logic [ 7:0] wdata,
    input  logic        wlast,

    output logic        bvalid,
    input  logic        bready,

    input  logic        arvalid,
    output logic        arready,
    input  logic [31:0] araddr,
    input  logic [ 7:0] arlen,

    output logic        rvalid,
    input  logic        rready,
    output logic [ 7:0] rdata,
    output logic        rlast,

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
        ST_SPI_SEND_ADDR,
        ST_SPI_READ_DATA,
        ST_SEND_RESP
    } state_t;

    state_t state, next_state;

    logic spi_addr_transfer_active;
    logic spi_addr_transfer_done;

    logic spi_read_transfer_active;
    logic spi_read_transfer_done;

    logic response_read_transfer_active;
    logic response_read_transfer_done;
    
    // logic [31:0][7:0] spi_write_mem;
    // logic       [4:0] spi_write_ptr;

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

    assign spi_req_block_select = araddr[ 16 +: 5] | awaddr[ 16 +: 5];
    assign spi_req_rwb          = ( ~ arvalid ) & awvalid;
    assign spi_req_mode         = 2'b00;

    assign spi_req_control = { spi_req_block_select, spi_req_rwb, spi_req_mode };

    assign spi_req_addr = araddr[ 0 +: 16] | awaddr[ 0 +: 16];

    // -------------------------------------------------------------------------

    logic [ 7:0] arlen_r;
    
    always_ff @( posedge clk )
    begin
        if ( arvalid )
            arlen_r <= arlen;
    end

    // -------------------------------------------------------------------------

    always_comb begin
        next_state = state;
        spi_addr_transfer_active      = '0;
        spi_read_transfer_active      = '0;
        response_read_transfer_active = '0;

        arready = 1'b0;
        // awready = 1'b0;

        case (state)
        ST_IDLE:
        begin
            arready = ~ arvalid;
            // arready = 1'b1;
            // awready = 1'b1;

            if ( arvalid )
            begin
                next_state = ST_SPI_SEND_ADDR;
            end
        end
        ST_SPI_SEND_ADDR:
        begin
            spi_addr_transfer_active = '1;

            if ( spi_addr_transfer_done )
            begin
                next_state = ST_SPI_READ_DATA;
            end
        end
        ST_SPI_READ_DATA:
        begin
            spi_read_transfer_active = '1;

            if ( spi_read_transfer_done )
            begin
                next_state = ST_SEND_RESP;
            end
        end
        ST_SEND_RESP:
        begin
            response_read_transfer_active = '1;

            if ( response_read_transfer_done )
            begin
                next_state = ST_IDLE;
            end
        end
        
        default: begin end
        endcase
    end

    // -------------------------------------------------------------------------

    logic            spi_addr_ptr_last;
    logic      [1:0] spi_addr_ptr;
    logic [2:0][7:0] spi_addr_mem;

    counter_timer
    #(
        .COUNT_DOWN ( 1'b1 ),
        .MAX_VALUE  ( 2    )
    ) 
    spi_addr_mem_ptr_inst
    (
        .clk          ( clk                                        ),
        .rst          ( rst                                        ),
        .start        (                                            ), // input
        .tick_valid   ( spi_addr_transfer_active & spi_ack_request ), // input
        .finished     ( spi_addr_ptr_last                          ), // output logic
        .counter      ( spi_addr_ptr                               ), // output logic [CNT_W-1:0]
        .counter_next (                                            )  // output logic [CNT_W-1:0]
    );

    assign spi_addr_transfer_done = spi_addr_ptr_last & spi_ack_request;

    always_ff @( posedge clk )
    begin
        if ( arvalid ) // | awvalid
            spi_addr_mem <= { spi_req_addr, spi_req_control};
    end

    // -------------------------------------------------------------------------

    logic             read_mem_last;
    logic       [4:0] read_mem_ptr;
    logic [31:0][7:0] read_mem;

    counter_timer
    #(
        .COUNT_DOWN ( 1'b0 ),
        .MAX_VALUE  ( 32   )
    )
    read_mem_ptr_inst
    (
        .clk             ( clk                                                                                       ), // input
        .rst             ( rst                                                                                       ), // input
        .soft_rst        ( spi_read_transfer_done                                                                    ), // input
        .start           (                                                                                           ), // input
        .tick_valid      ( ( spi_read_transfer_active & spi_rx_valid ) | ( response_read_transfer_active & rready )  ), // input
        .finished        (                                                                                           ), // output logic
        .counter         (                                                                                           ), // output logic [CNT_W-1:0]
        .counter_next    (                                                                                           )  // output logic [CNT_W-1:0]
    );

    assign spi_read_transfer_done = ( read_mem_ptr_next == arlen_r ) & spi_rx_valid;
    assign response_read_transfer_done = ( spi_read_ptr == arlen ) & rready;

    always_ff @( posedge clk )
    begin
        if ( spi_read_transfer_active & spi_rx_valid )
            spi_read_mem[spi_read_ptr] <= spi_rx_data;
        else if ( response_read_transfer_active )
            rdata <= spi_read_mem[spi_read_ptr];
    end

    always_ff @( posedge clk)
    begin
        rvalid <= response_read_transfer_active;
        rlast  <= response_read_transfer_done;
    end

    // -------------------------------------------------------------------------

    always_comb
    begin
        spi_tx_request = '0;
        spi_tx_data    = '0;
        spi_rx_request = '0;

        if ( spi_addr_transfer_active & ( ~ spi_addr_transfer_done ) )
        begin
            spi_tx_request = '1;
            spi_tx_data = spi_addr_mem[spi_addr_ptr];
        end
        else if ( spi_read_transfer_active ) // & ( ~ spi_read_transfer_done )
        begin
            spi_rx_request = '1;
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
