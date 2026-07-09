module w5500_axi_over_spi
(
    input         clk,
    input         rst,

    // ---------------------------------
    // AXI-like data interface for W5500 module
    // ---------------------------------

    input  logic        awvalid,
    output logic        awready,
    input  logic [ 4:0] aw_block_select,
    input  logic [15:0] aw_offset_addr,
    input  logic [ 7:0] awlen,

    input  logic        wvalid,
    output logic        wready,
    input  logic [ 7:0] wdata,
    input  logic        wlast,

    output logic        bvalid,
    input  logic        bready,

    input  logic        arvalid,
    output logic        arready,
    input  logic [ 4:0] ar_block_select,
    input  logic [15:0] ar_offset_addr,
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
        ST_IDLE           = 4'd0,
        ST_RECV_WRITE_REQ = 4'd1,
        ST_SPI_SEND_ADDR  = 4'd2,
        ST_SPI_READ_DATA  = 4'd3,
        ST_SPI_WRITE_DATA = 4'd4,
        ST_SEND_RESP      = 4'd5
    } state_t;

    state_t state, next_state;

    logic spi_addr_transfer_active;
    logic spi_addr_transfer_done;

    logic spi_write_transfer_active;
    logic spi_write_transfer_done;

    logic spi_read_transfer_active;
    logic spi_read_transfer_done;

    logic request_write_transfer_active;
    logic request_write_transfer_done;

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

    logic [7:0] awlen_r;
    logic [7:0] arlen_r;
    
    always_ff @( posedge clk )
    begin
        if ( arvalid )
            arlen_r <= arlen;

        if ( awvalid )
            awlen_r <= awlen;
    end

    // -------------------------------------------------------------------------

    logic [2:0][7:0] spi_request_mem;

    logic            rw_mode;
    logic            rw_mode_r;

    logic [15:0]     spi_req_addr;         // 16 bit offset from { block_select }
    logic [ 7:0]     spi_req_control;

    logic [ 4:0]     spi_req_block_select; // 5'h0 - common register, 5'h01 - sock0 reg, 5'h1F - sock7 rx buf
    logic            spi_req_rwb;          // read - 0, write - 1
    logic [ 1:0]     spi_req_mode;         // variable by SCSn - 00, 1 byte - 01, 2 byte - 10, 4 byte - 11

    assign rw_mode = awvalid & ( ~ arvalid );

    assign spi_req_block_select = rw_mode ? aw_block_select : ar_block_select;
    assign spi_req_rwb          = rw_mode;
    assign spi_req_mode         = 2'b00;

    assign spi_req_control = { spi_req_block_select, spi_req_rwb, spi_req_mode };

    assign spi_req_addr = rw_mode ? aw_offset_addr : ar_offset_addr;


    always_ff @( posedge clk )
    begin
        if ( arvalid | awvalid )
        begin
            rw_mode_r       <= rw_mode;
            spi_request_mem <= { spi_req_addr[8 +: 8], spi_req_addr[0 +: 8], spi_req_control};
        end
    end

    // -------------------------------------------------------------------------

    always_comb
    begin
        next_state = state;

        request_write_transfer_active = '0;
        spi_addr_transfer_active      = '0;
        spi_write_transfer_active     = '0;
        spi_read_transfer_active      = '0;
        response_read_transfer_active = '0;

        arready = 1'b0;
        awready = 1'b0;
        bvalid  = 1'b0;

        case (state)
        ST_IDLE:
        begin
            // Accept incoming request

            awready = 1'b1;
            arready = 1'b1;

            if ( awvalid )
            begin
                arready = 1'b0;
                next_state = ST_RECV_WRITE_REQ;
            end

            if ( arvalid )
            begin
                next_state = ST_SPI_SEND_ADDR;
            end
        end
        ST_RECV_WRITE_REQ:
        begin
            // Begin reading N len bytes of data from SPI into buffer

            request_write_transfer_active = '1;

            if ( request_write_transfer_done )
            begin
                next_state = ST_SPI_SEND_ADDR;
            end
        end
        ST_SPI_SEND_ADDR:
        begin
            // Begin SPI transaction by sending address

            spi_addr_transfer_active = '1;

            if ( spi_addr_transfer_done )
            begin
                next_state = ST_SPI_READ_DATA;
            end
        end
        ST_SPI_WRITE_DATA:
        begin
            // Begin reading N len bytes of data from SPI into buffer

            spi_write_transfer_active = '1;

            if ( spi_write_transfer_done )
            begin
                next_state = ST_SEND_RESP;
            end
        end
        ST_SPI_READ_DATA:
        begin
            // Begin reading N len bytes of data from SPI into buffer

            spi_read_transfer_active = '1;

            if ( spi_read_transfer_done )
            begin
                next_state = ST_SEND_RESP;
            end
        end
        ST_SEND_RESP:
        begin
            if ( rw_mode_r )
            begin
                bvalid = '1;

                if ( bready )
                begin
                    next_state = ST_IDLE;
                end
            end
            else
            begin
                response_read_transfer_active = '1;

                if ( response_read_transfer_done )
                begin
                    next_state = ST_IDLE;
                end
            end
        end
        
        default: begin end
        endcase
    end

    always_ff @( posedge clk )
    begin
        if ( rst )
            state <= ST_IDLE;
        else
            state <= next_state;
    end

    // -------------------------------------------------------------------------

    logic            spi_addr_ptr_last;
    logic      [1:0] spi_addr_ptr;

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

    // -------------------------------------------------------------------------

    logic       spi_tx_request_next;

    // ---------------------------------

    logic             write_mem_last;
    logic       [4:0] write_mem_ptr;
    logic       [4:0] write_mem_ptr_next;
    logic [31:0][7:0] write_mem;

    counter_timer
    #(
        .COUNT_DOWN ( 1'b0 ),
        .MAX_VALUE  ( 32   )
    )
    write_mem_ptr_inst
    (
        .clk             ( clk                                                                                      ), // input
        .rst             ( rst                                                                                      ), // input
        .soft_rst        ( request_write_transfer_done | spi_write_transfer_done                                    ), // input
        .start           (                                                                                          ), // input
        .tick_valid      ( ( request_write_transfer_active & wvalid ) | ( spi_write_transfer_active & spi_tx_request_next )  ), // input
        .finished        (                                                                                          ), // output logic
        .counter         ( write_mem_ptr                                                                             ), // output logic [CNT_W-1:0]
        .counter_next    ( write_mem_ptr_next                                                                        )  // output logic [CNT_W-1:0]
    );

    assign write_mem_last              = write_mem_ptr_next == 5'( awlen_r );
    assign request_write_transfer_done = write_mem_last;
    assign spi_write_transfer_done     = write_mem_last & spi_rx_valid;

    always_ff @( posedge clk )
    begin
        if ( request_write_transfer_active & wvalid )
            write_mem[write_mem_ptr] <= wdata;
    end

    assign wready = request_write_transfer_active & ( ~ request_write_transfer_done );

    // -------------------------------------------------------------------------

    logic             read_mem_last;
    logic       [4:0] read_mem_ptr;
    logic       [4:0] read_mem_ptr_next;
    logic [31:0][7:0] read_mem;

    counter_timer
    #(
        .COUNT_DOWN ( 1'b0 ),
        .MAX_VALUE  ( 32   )
    )
    read_mem_ptr_inst
    (
        .clk             ( clk                                                                                      ), // input
        .rst             ( rst                                                                                      ), // input
        .soft_rst        ( spi_read_transfer_done | response_read_transfer_done                                     ), // input
        .start           (                                                                                          ), // input
        .tick_valid      ( ( spi_read_transfer_active & spi_rx_valid ) | ( response_read_transfer_active & rready ) ), // input
        .finished        (                                                                                          ), // output logic
        .counter         ( read_mem_ptr                                                                             ), // output logic [CNT_W-1:0]
        .counter_next    ( read_mem_ptr_next                                                                        )  // output logic [CNT_W-1:0]
    );

    assign read_mem_last               = read_mem_ptr_next == 5'( arlen_r );
    assign spi_read_transfer_done      = read_mem_last & spi_rx_valid;
    assign response_read_transfer_done = read_mem_last & rready;

    always_ff @( posedge clk )
    begin
        if ( spi_read_transfer_active & spi_rx_valid )
            read_mem[read_mem_ptr] <= spi_rx_data;
        else if ( response_read_transfer_active )
            rdata <= read_mem[read_mem_ptr];
    end

    always_ff @( posedge clk)
    begin
        rvalid <= response_read_transfer_active;
        rlast  <= read_mem_last;
    end

    // -------------------------------------------------------------------------

    logic       spi_tx_request_r;
    logic [7:0] spi_tx_data_r;
    logic [7:0] spi_tx_data_next;

    always_comb
    begin
        spi_tx_request_next = '0;
        spi_tx_data_next    = '0;
        spi_rx_request      = '0;

        if ( spi_addr_transfer_active & ( ~ spi_addr_transfer_done ) )
        begin
            spi_tx_request_next = '1;
            spi_tx_data_next = spi_request_mem[spi_addr_ptr];
        end
        else if ( spi_write_transfer_active & ( ~ spi_write_transfer_done ) )
        begin
            spi_tx_request_next = '1;
            spi_tx_data_next = write_mem[write_mem_ptr];
        end
        else if ( spi_read_transfer_active & ( ~ spi_read_transfer_done ) )
        begin
            spi_rx_request = '1;
        end
    end

    always_ff @( clk )
    begin
        spi_tx_request_r <= spi_tx_request_next;

        if ( spi_tx_request_next )
        begin
            spi_tx_data_r <= spi_tx_data_next;
        end
    end

    assign spi_tx_request = spi_tx_request_r;
    assign spi_tx_data    = spi_tx_data_r;

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
