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

    // --- W5500 Block Select Bits (BSB) ---
    localparam logic [4:0] W5500_BSB_COMMON = 5'h0;
    localparam logic [4:0] W5500_BSB_S0     = 5'h1;
    localparam logic [4:0] W5500_BSB_S0_TX  = 5'h2;

    // --- W5500 Common Registers ---
    localparam logic [15:0] W5500_MR        = 16'h0000; // Mode Register
    localparam logic [15:0] W5500_GAR       = 16'h0001; // Gateway Address Register
    localparam logic [15:0] W5500_SUBR      = 16'h0005; // Subnet Mask Register
    localparam logic [15:0] W5500_SHAR      = 16'h0009; // Source Hardware Address (MAC)
    localparam logic [15:0] W5500_SIPR      = 16'h000F; // Source IP Address
    localparam logic [15:0] W5500_PHYCFGR   = 16'h002E; // PHY Configuration Register
    localparam logic [15:0] W5500_VERSIONR  = 16'h0039; // Chip Version Register

    // --- W5500 Common Register Commands/Bits ---
    localparam logic [7:0] MR_CMD_RESET    = 8'h80;
    localparam logic [7:0] MR_CMD_WOL      = 8'h08;
    localparam logic [7:0] MR_CMD_PING_BLK = 8'h10;
    localparam logic [7:0] MR_CMD_CLEAR    = 8'h00;

    // --- W5500 Socket 0 Registers (Offsets) ---
    localparam logic [15:0] W5500_S_MR     = 16'h0000; // Socket Mode
    localparam logic [15:0] W5500_S_CR     = 16'h0001; // Socket Command
    localparam logic [15:0] W5500_S_IR     = 16'h0002; // Socket Interrupt
    localparam logic [15:0] W5500_S_SR     = 16'h0003; // Socket Status
    localparam logic [15:0] W5500_S_PORT   = 16'h0004; // Socket Source Port
    localparam logic [15:0] W5500_S_DIPR   = 16'h000C; // Socket Destination IP
    localparam logic [15:0] W5500_S_DPORT  = 16'h0010; // Socket Destination Port
    localparam logic [15:0] W5500_S_TX_FSR = 16'h0020; // Socket TX Free Size
    localparam logic [15:0] W5500_S_TX_WR  = 16'h0024; // Socket TX Write Pointer
    localparam logic [15:0] W5500_S_TX_RD  = 16'h0028; // Socket TX Read Pointer

    // --- Socket Commands & Modes ---
    localparam logic [7:0] S_MR_MODE_UDP   = 8'h02; // UDP Mode setting
    localparam logic [7:0] S_CR_CMD_OPEN   = 8'h01; // OPEN command
    localparam logic [7:0] S_CR_CMD_SEND   = 8'h20; // SEND command
    localparam logic [7:0] S_IR_INT_SENDOK = 8'h10; // SEND_OK interrupt flag
    localparam logic [7:0] S_IR_CLR_ALL    = 8'hFF; // Clear all interrupts code

    // --- Network Configuration Values ---
    localparam logic [5:0][7:0] CONF_MAC      = { 8'hDE,  8'hAD,  8'hBE,  8'hEF, 8'hFE, 8'hED};
    localparam logic [3:0][7:0] CONF_SRC_IP   = { 8'd192, 8'd168, 8'd1,   8'd10 };
    localparam logic [3:0][7:0] CONF_NETMASK  = { 8'd255, 8'd255, 8'd255, 8'd0  };
    localparam logic [3:0][7:0] CONF_GATEWAY  = { 8'd255, 8'd255, 8'd255, 8'd0  }; 
    localparam logic [1:0][7:0] CONF_SRC_PORT = 16'd8880; // 0x22B0

    localparam logic [3:0][7:0] CONF_DST_IP   = { 8'd192, 8'd168, 8'd1, 8'd100 };
    localparam logic [1:0][7:0] CONF_DST_PORT = 16'd8888; // 0x22B8

    // -------------------------------------------------------------------------

    typedef enum logic [3:0] {
        WAIT_FOR_TIMER  = 4'd0,
        SPI_WRITE_REQ   = 4'd1,
        SPI_WRITE_REQ_R = 4'd2,
        SPI_WRITE_I     = 4'd3,
        SPI_WRITE_R     = 4'd4,
        SPI_READ_REQ    = 4'd5,
        SPI_READ_R      = 4'd6,
        JUMP            = 4'd7
    } opcode_t;

    typedef struct packed {
        opcode_t opcode;
        logic [27:0] immediate;
    } instruction_t;

    localparam MAX_PROGRAM_SIZE = 1000;
    localparam PC_W             = $clog2(MAX_PROGRAM_SIZE);

    logic [PC_W - 1:0] pc, pc_next;

    instruction_t current_instruction;
    opcode_t current_opcode;

    logic [7:0] reg_addr;
    logic [7:0] reg_mem [0:32];

    instruction_t spi_program [0:MAX_PROGRAM_SIZE - 1];

    initial
    begin
        spi_program = '{
            // -- Initialization routine
            // Set activation threshold
            { WAIT_FOR_TIMER, 28'b0                                  },
            { SPI_WRITE_REQ,  W5500_BSB_COMMON, W5500_MR, 8'd1       },
            { SPI_WRITE_I,    MR_CMD_RESET                           },
            { SPI_WRITE_REQ,  W5500_BSB_COMMON, W5500_MR, 8'd1       },
            { SPI_WRITE_I,    MR_CMD_CLEAR                           },
            { SPI_READ_REQ,   W5500_BSB_COMMON, W5500_MR, 8'd1       },
            { SPI_READ_R,     28'h0                                  },
            { SPI_READ_REQ,   W5500_BSB_COMMON, W5500_VERSIONR, 8'd1 },
            { SPI_READ_R,     28'h1                                  },
            { SPI_WRITE_REQ,  W5500_BSB_COMMON, W5500_SHAR, 8'd6     },
            { SPI_WRITE_I,    CONF_MAC[5]                            },
            { SPI_WRITE_I,    CONF_MAC[4]                            },
            { SPI_WRITE_I,    CONF_MAC[3]                            },
            { SPI_WRITE_I,    CONF_MAC[2]                            },
            { SPI_WRITE_I,    CONF_MAC[1]                            },
            { SPI_WRITE_I,    CONF_MAC[0]                            },
            { SPI_WRITE_REQ,  W5500_BSB_COMMON, W5500_SIPR, 8'd4     },
            { SPI_WRITE_I,    CONF_SRC_IP[3]                         },
            { SPI_WRITE_I,    CONF_SRC_IP[2]                         },
            { SPI_WRITE_I,    CONF_SRC_IP[1]                         },
            { SPI_WRITE_I,    CONF_SRC_IP[0]                         },
            { SPI_WRITE_REQ,  W5500_BSB_COMMON, W5500_SIPR, 8'd4     },
            { SPI_WRITE_I,    CONF_GATEWAY[3]                        },
            { SPI_WRITE_I,    CONF_GATEWAY[2]                        },
            { SPI_WRITE_I,    CONF_GATEWAY[1]                        },
            { SPI_WRITE_I,    CONF_GATEWAY[0]                        },
            { SPI_WRITE_REQ,  W5500_BSB_COMMON, W5500_SIPR, 8'd4     },
            { SPI_WRITE_I,    CONF_NETMASK[3]                        },
            { SPI_WRITE_I,    CONF_NETMASK[2]                        },
            { SPI_WRITE_I,    CONF_NETMASK[1]                        },
            { SPI_WRITE_I,    CONF_NETMASK[0]                        },
            { SPI_WRITE_REQ,  W5500_BSB_S0, W5500_S_MR, 8'd1         },
            { SPI_WRITE_I,    S_MR_MODE_UDP                          },
            { SPI_WRITE_REQ,  W5500_BSB_S0, W5500_S_PORT, 8'd2       },
            { SPI_WRITE_I,    CONF_SRC_PORT[1]                       },
            { SPI_WRITE_I,    CONF_SRC_PORT[0]                       },
            { SPI_WRITE_REQ,  W5500_BSB_S0, W5500_S_CR, 8'd1         },
            { SPI_WRITE_I,    S_CR_CMD_OPEN                          },
            { SPI_WRITE_REQ,  W5500_BSB_S0, W5500_S_DIPR, 8'd4       },
            { SPI_WRITE_I,    CONF_DST_IP[3]                         },
            { SPI_WRITE_I,    CONF_DST_IP[2]                         },
            { SPI_WRITE_I,    CONF_DST_IP[1]                         },
            { SPI_WRITE_I,    CONF_DST_IP[0]                         },
            { SPI_WRITE_REQ,  W5500_BSB_S0, W5500_S_DPORT, 8'd2      },
            { SPI_WRITE_I,    CONF_DST_PORT[1]                       },
            { SPI_WRITE_I,    CONF_DST_PORT[0]                       },
            // -------------------------
            { WAIT_FOR_TIMER, 28'd0                                  },
            { SPI_READ_REQ,   W5500_BSB_S0, W5500_S_TX_WR, 8'd2      },
            { SPI_READ_R,     28'h5                                  },
            { SPI_READ_R,     28'h6                                  },
            { SPI_WRITE_REQ_R, W5500_BSB_S0_TX, 16'h5, 8'd8          },
            { SPI_WRITE_R,    28'h10                                 },
            { SPI_WRITE_R,    28'h11                                 },
            { SPI_WRITE_R,    28'h12                                 },
            { SPI_WRITE_R,    28'h13                                 },
            { SPI_WRITE_R,    28'h14                                 },
            { SPI_WRITE_R,    28'h15                                 },
            { SPI_WRITE_R,    28'h16                                 },
            { SPI_WRITE_R,    28'h17                                 },
            { SPI_WRITE_REQ,  W5500_BSB_S0, W5500_S_TX_WR, 8'd2      },
            { SPI_WRITE_R,    28'h7                                  },
            { SPI_WRITE_R,    28'h8                                  },
            { SPI_WRITE_REQ,  W5500_BSB_S0, W5500_S_CR, 8'd1         },
            { SPI_WRITE_I,    S_CR_CMD_SEND                          },
            { WAIT_FOR_TIMER, 28'd0                                  },
            { JUMP,           28' ($signed (-19) )                   }
        };
    end

    // -------------------------------------------------------------------------

    // RX Monitor
    logic monitor_rx;
    logic monitor_rx_r;

    always_ff @(posedge clk) begin
        // Set and clear monitor_rx flag
        if (monitor_rx)
        begin
            address <= current_instruction.immediate;
            monitor_rx_r <= 1'b1;
        end else if (rx_valid)
        begin
            monitor_rx_r <= 1'b0;
        end

        // If waiting for request, save data to the saved address.
        if (rx_valid && monitor_rx_r) begin
            memory[address] <= rx_data;
        end
    end

    // Unpack memory
    assign data_x = {memory[1], memory[0]};
    assign data_y = {memory[3], memory[2]};
    assign data_z = {memory[5], memory[4]};
    
    // -------------------------------------------------------------------------

    // Processor implementation
    always_ff @(posedge clk) begin  
        pc                  <= pc_next;
        current_instruction <= spi_program[pc_next];
    end

    always_comb begin
        // Default initial values
        if (reset_n == 1'b0) begin
            pc_next = 0;
        end else begin
            pc_next = pc;
        end

        // Default outputs
        tx_request = 1'b0; 
        rx_request = 1'b0;
        data_valid = 1'b0;
        monitor_rx = 1'b0;

        // Convenience assignments
        current_opcode = current_instruction.opcode;

        case (current_opcode)
            READ: begin
                rx_request = 1'b1;
                if (ack_request) begin
                    monitor_rx = 1'b1;
                    pc_next = pc + 1'b1;
                end
            end

            WRITE: begin
                tx_request = 1'b1;
                // Increment PC if TX is acknowledged.
                if (ack_request) begin
                    pc_next = pc + 1'b1;
                end
            end

            WAIT_FOR_IDLE: begin
                if (active == 1'b0) begin
                    pc_next = pc + 1'b1;
                end
            end

            WAIT_FOR_UPDATE: begin
                if (update) begin
                    pc_next = pc + 1'b1;
                end
            end

            JUMP: begin
                pc_next = current_instruction.immediate;
            end

            NOTIFY: begin
                data_valid = 1'b1;
                pc_next = pc + 1'b1;
            end
        endcase
    end

    // -------------------------------------------------------------------------

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
