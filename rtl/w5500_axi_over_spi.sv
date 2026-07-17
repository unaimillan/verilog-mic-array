module w5500_axi_over_spi
# (
    parameter RW_BUFFER_DEPTH = 32
)
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

    logic spi_addr_transfer_done;
    logic spi_write_transfer_done;
    logic spi_read_transfer_done;
    logic request_write_transfer_done;
    logic response_read_transfer_done;

    wire goto_st_idle           = ( state != ST_IDLE           ) & ( next_state == ST_IDLE           );
    wire goto_st_recv_write_req = ( state != ST_RECV_WRITE_REQ ) & ( next_state == ST_RECV_WRITE_REQ );
    wire goto_st_spi_send_addr  = ( state != ST_SPI_SEND_ADDR  ) & ( next_state == ST_SPI_SEND_ADDR  );
    wire goto_st_spi_read_data  = ( state != ST_SPI_READ_DATA  ) & ( next_state == ST_SPI_READ_DATA  );
    wire goto_st_spi_write_data = ( state != ST_SPI_WRITE_DATA ) & ( next_state == ST_SPI_WRITE_DATA );
    wire goto_st_send_resp      = ( state != ST_SEND_RESP      ) & ( next_state == ST_SEND_RESP      );

    // -------------------------------------------------------------------------

    logic       spi_rx_request;
    logic       spi_tx_request;
    logic       spi_tx_ack_req;
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

            if ( request_write_transfer_done )
            begin
                next_state = ST_SPI_SEND_ADDR;
            end
        end
        ST_SPI_SEND_ADDR:
        begin
            // Begin SPI transaction by sending address

            if ( spi_addr_transfer_done )
            begin
                if ( rw_mode_r )
                    next_state = ST_SPI_WRITE_DATA;
                else
                    next_state = ST_SPI_READ_DATA;
            end
        end
        ST_SPI_WRITE_DATA:
        begin
            // Begin reading N len bytes of data from SPI into buffer

            if ( spi_write_transfer_done )
            begin
                next_state = ST_SEND_RESP;
            end
        end
        ST_SPI_READ_DATA:
        begin
            // Begin reading N len bytes of data from SPI into buffer

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

    logic      [1:0] spi_addr_ptr;
    logic            spi_addr_ptr_rst;

    counter_timer
    #(
        .COUNT_DOWN ( 1'b0 ),
        .MAX_VALUE  ( 3    )
    ) 
    spi_addr_mem_ptr_inst
    (
        .clk          ( clk                           ),
        .rst          ( rst                           ),
        .soft_rst     ( spi_addr_ptr_rst              ),
        .start        (                               ), // input
        .tick_valid   ( ( state == ST_SPI_SEND_ADDR ) 
                        & spi_ack_request             ), // input
        .finished     (                               ), // output logic
        .counter      ( spi_addr_ptr                  ), // output logic [CNT_W-1:0]
        .counter_next (                               )  // output logic [CNT_W-1:0]
    );

    assign spi_addr_ptr_rst = goto_st_spi_send_addr;
    assign spi_addr_transfer_done = ( spi_addr_ptr == 2'd3 ) & spi_tx_ack_req;

    // -------------------------------------------------------------------------

    logic       mem_write;
    logic       mem_read;
    logic [7:0] mem_wdata;
    logic [7:0] mem_rdata;

    localparam CNT_W = $clog2( RW_BUFFER_DEPTH + 1 );

    logic [CNT_W - 1:0] counter;
    logic [CNT_W - 1:0] counter_next;
    logic               counter_rst;
    logic               counter_tick;

    counter_timer
    #(
        .COUNT_DOWN ( 1'b0 ),
        .MAX_VALUE  ( RW_BUFFER_DEPTH )
    )
    mem_counter_i
    (
        .clk             ( clk          ), // input
        .rst             ( rst          ), // input
        .soft_rst        ( counter_rst  ), // input
        .start           (              ), // input
        .tick_valid      ( counter_tick ), // input
        .finished        (              ), // output logic
        .counter         ( counter      ), // output logic [CNT_W-1:0]
        .counter_next    ( counter_next )  // output logic [CNT_W-1:0]
    );

    fifo_dualport
    # (
        .WIDTH ( 8 ),
        .DEPTH ( RW_BUFFER_DEPTH )
    )
    fifo_mem
    (
        .clk_i   ( clk       ), // input  logic
        .rst_i   ( rst       ), // input  logic
        .wr_en_i ( mem_write ), // input  logic
        .rd_en_i ( mem_read  ), // input  logic
        .data_i  ( mem_wdata ), // input  logic [WIDTH-1:0]
        .data_o  ( mem_rdata ), // output logic [WIDTH-1:0]
        .empty_o (           ), // output logic
        .full_o  (           )  // output logic
    );

    // -------------------------------------------------------------------------

    always_comb
    begin
        counter_rst  = '0;
        counter_tick = '0;
        
        if ( goto_st_spi_read_data | goto_st_send_resp )
        begin
            counter_rst = 1'b1;
        end
        else
        begin
            if ( ( state == ST_SPI_READ_DATA & spi_ack_request ) | ( state == ST_SEND_RESP & rvalid & rready ) )
            begin
                counter_tick = 1'b1;
            end
        end
    end

    always_comb
    begin
        mem_write    = '0;
        mem_read     = '0;
        mem_wdata    = '0;
        rvalid       = '0;
        rdata        = '0;
        rlast        = '0;

        if ( state == ST_SPI_READ_DATA )
        begin
            mem_write = spi_rx_valid;
            mem_wdata = spi_rx_data;
        end
        else if ( state == ST_SEND_RESP )
        begin
            rvalid = 1'b1;
            mem_read = rvalid & rready;
            rdata  = mem_rdata;
            rlast  = counter_next == CNT_W'(arlen_r);
        end

        spi_read_transfer_done = ( counter == CNT_W'(arlen_r) ) & spi_rx_valid;
        response_read_transfer_done = ( counter_next == CNT_W'(arlen_r) ) & rready;
    end

    // -------------------------------------------------------------------------

    always_comb
    begin
        spi_tx_request = '0;
        spi_tx_data    = '0;
        spi_rx_request = '0;

        if ( state == ST_SPI_SEND_ADDR & ( spi_addr_ptr != 2'd3 ) )
        begin
            spi_tx_request = '1;
            spi_tx_data = spi_request_mem[ 2'd2 - spi_addr_ptr ];
        end
        else if ( state == ST_SPI_WRITE_DATA & ( ~ spi_write_transfer_done ) )
        begin
            spi_tx_request = '1;
            spi_tx_data = mem_rdata;
        end
        else if ( state == ST_SPI_READ_DATA & ( counter != CNT_W'(arlen_r) ) )
        begin
            spi_rx_request = '1;
        end
    end

    // -------------------------------------------------------------------------

    //     .clk             ( clk                                                                                      ), // input
    //     .rst             ( rst                                                                                      ), // input
    //     .soft_rst        ( request_write_transfer_done | spi_write_transfer_done                                    ), // input
    //     .start           (                                                                                          ), // input
    //     .tick_valid      ( ( request_write_transfer_active & wvalid ) | ( spi_write_transfer_active & spi_tx_request_next )  ), // input


    // assign write_mem_last              = write_mem_ptr_next == 5'( awlen_r );
    // assign request_write_transfer_done = write_mem_last;
    // assign spi_write_transfer_done     = write_mem_last & spi_rx_valid;

    // always_ff @( posedge clk )
    // begin
    //     if ( request_write_transfer_active & wvalid )
    //         write_mem[write_mem_ptr] <= wdata;
    // end

    // assign wready = request_write_transfer_active & ( ~ request_write_transfer_done );

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

        .tx_request  ( spi_tx_request  ),
        .tx_data     ( spi_tx_data     ), // [DATASIZE-1:0] 
        .tx_ack_req  ( spi_tx_ack_req  ),
        .rx_request  ( spi_rx_request  ),
        .rx_valid    ( spi_rx_valid    ),
        .rx_data     ( spi_rx_data     ), // [DATASIZE-1:0] 
        .ack_request ( spi_ack_request ),
        .active      (                 ),

        .spi_clk     ( spi_clk         ),
        .spi_csn     ( spi_cs_n        ),
        .spi_sdi     ( spi_mosi        ),
        .spi_sdo     ( spi_miso        )
    );

endmodule
