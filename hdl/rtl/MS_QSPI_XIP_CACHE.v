/*
	Copyright 2020 Mohamed Shalan (mshalan@aucegypt.edu)
	
	Licensed under the Apache License, Version 2.0 (the "License"); 
	you may not use this file except in compliance with the License. 
	You may obtain a copy of the License at:
	http://www.apache.org/licenses/LICENSE-2.0
	Unless required by applicable law or agreed to in writing, software 
	distributed under the License is distributed on an "AS IS" BASIS, 
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
	See the License for the specific language governing permissions and 
	limitations under the License.
*/

`timescale          1ns/1ps
`default_nettype    none

/*
    AHB-Lite Quad I/O flash XiP controller with Nx16 RO DM $
    Intended to be used to execute only from an external Quad I/O SPI Flash Memory
    
    Performance (CM0 @ 50MHz using gcc -O2)
    
         Configuration                                 run-time (msec)
    NUM_LINES   LINE_SIZE   stress          hash            chacha          xtea(256)       aes_sbox        G. Mean
    128         16          0.208 (4.9x)    0.707 (8.8x)    0.277 (7.4x)    0.212 (11.9x)   0.339 (6.4x)    7.53
    64          16          0.208 (4.9x)    0.779 (8.0x)    0.277 (7.4x)    0.212 (11.9x)   0.339 (6.4x)    7.39
    32          16          0.233 (4.4x)    0.869 (7.2x)    0.334 (6.2x)    0.212 (11.9x)   0.339 (6.4x)    6.83
    16          16          0.410 (2.5x)    1.259 (5.0x)    0.436 (4.7x)    0.212 (11.9x)   0.339 (6.4x)    5.37     <-- default
    8           16          0.692 (1.5x)    2.217 (2.8x)    0.951 (2.2x)    0.218 (11.6x)   0.341 (6.4x)    3.69
    4           16          0.899 (1.1x)    4.983 (1.3x)    1.723 (1.2x)
    2           16          1.020 (1.0x)    6.243 (1.0x)    2.076 (1.0x)    2.527 ( 1.0x)   2.191 (1.0x)    1.00
    
    Warning: Don't change LINE_SIZE from 16 due to some hidden bug!
*/
module MS_QSPI_XIP_CACHE #(parameter   NUM_LINES = 16 , 
                                        LINE_SIZE = 16 ) (
    // AHB-Lite Slave Interface
    input   wire            HCLK,
    input   wire            HRESETn,
    input   wire            HSEL,
    input   wire [31:0]     HADDR,
    input   wire [1:0]      HTRANS,
    //input wire [31:0]   HWDATA,
    input   wire            HWRITE,
    input   wire            HREADY,
    output  reg             HREADYOUT,
    output  wire [31:0]     HRDATA,

    // External Interface to Quad I/O
    output  wire            sck,
    output  wire            ce_n,
    input   wire [3:0]      din,
    output  wire [3:0]      dout,
    output  wire [3:0]      douten     
);

    // Cache wires/buses
    wire [31:0]                 c_datao;
    wire [(LINE_SIZE*8)-1:0]    c_line;
    wire                        c_hit;
    reg [1:0]                   c_wr;
    wire [23:0]                 c_A;

    // Flash Reader wires
    wire            fr_rd;
    wire            fr_done;

    wire            doe;

    // The State Machine
    localparam [1:0]    st_idle    = 2'b00;
    localparam [1:0]    st_wait    = 2'b01;
    localparam [1:0]    st_rw      = 2'b10;
    
    reg [1:0]   state, nstate;

    //AHB-Lite Address Phase Regs
    reg             last_HSEL;
    reg [31:0]      last_HADDR;
    reg             last_HWRITE;
    reg [1:0]       last_HTRANS;

    always@ (posedge HCLK) begin
        if(HREADY) begin
            last_HSEL       <= HSEL;
            last_HADDR      <= HADDR;
            last_HWRITE     <= HWRITE;
            last_HTRANS     <= HTRANS;
        end
    end

    always @ (posedge HCLK or negedge HRESETn)
        if(HRESETn == 0) state <= st_idle;
        else 
            state <= nstate;

    always @* begin
        nstate = st_idle;
        case(state)
            st_idle :   if(HTRANS[1] & HSEL & HREADY & c_hit) 
                            nstate = st_rw;
                        else if(HTRANS[1] & HSEL & HREADY & ~c_hit) 
                            nstate = st_wait;

            st_wait :   if(c_wr[1]) 
                            nstate = st_rw; 
                        else  
                            nstate = st_wait;

            st_rw   :   if(HTRANS[1] & HSEL & HREADY & c_hit) 
                            nstate = st_rw;
                        else if(HTRANS[1] & HSEL & HREADY & ~c_hit) 
                            nstate = st_wait;
        endcase
    end

    always @(posedge HCLK or negedge HRESETn)
        if(!HRESETn) HREADYOUT <= 1'b1;
        else
            case (state)
                st_idle :   if(HTRANS[1] & HSEL & HREADY & c_hit) HREADYOUT <= 1'b1;
                            else if(HTRANS[1] & HSEL & HREADY & ~c_hit) HREADYOUT <= 1'b0;
                            else HREADYOUT <= 1'b1;
                st_wait :   if(c_wr[1]) HREADYOUT <= 1'b1;
                            else HREADYOUT <= 1'b0;
                st_rw   :   if(HTRANS[1] & HSEL & HREADY & c_hit) HREADYOUT <= 1'b1;
                            else if(HTRANS[1] & HSEL & HREADY & ~c_hit) HREADYOUT <= 1'b0;
            endcase
        

    assign fr_rd        =   ( HTRANS[1] & HSEL & HREADY & ~c_hit & (state==st_idle) ) |
                            ( HTRANS[1] & HSEL & HREADY & ~c_hit & (state==st_rw) );

    assign c_A          =   last_HADDR[23:0];
    
    DMC_Nx16 #(.NUM_LINES(NUM_LINES), .LINE_SIZE(LINE_SIZE)) CACHE ( 
                	                    .clk(HCLK), 
                                        .rst_n(HRESETn), 
                                        .A(last_HADDR[23:0]), 
                                        .A_h(HADDR[23:0]), 
                                        .Do(c_datao), 
                                        .hit(c_hit), 
                                        .line(c_line), 
                                        .wr(c_wr[1]) 
                                    );
    
    FLASH_READER #(.LINE_SIZE(LINE_SIZE)) FR (   
                                                .clk(HCLK), 
                                                .rst_n(HRESETn), 
                                                .addr({HADDR[23:4], 4'd0}), 
                                                .rd(fr_rd), 
                                                .done(fr_done), 
                                                .line(c_line),
                                                .sck(sck), 
                                                .ce_n(ce_n), 
                                                .din(din), 
                                                .dout(dout), 
                                                .douten(doe) 
                                            );

    assign HRDATA   = c_datao;

    always @ (posedge HCLK) begin
        c_wr[0] <= fr_done;
        c_wr[1] <= c_wr[0];
    end
  
    assign douten = {4{doe}};
    
endmodule

/*
    RTL Model for reading from Quad I/O flash using the QUAD I/O FAST READ (0xEB) command
    The Quad I/O bit has to be set in the flash memory (through flash programming); the 
    provided flash memory model has the bit set.

    Every transaction reads one cache line (128 bits or 16 bytes) from the flash.
    To start a transaction, provide the memory address and assert rd for 1 clock cycle.
    done is a sserted for 1 clock cycle when the data is ready

*/
module FLASH_READER #(parameter LINE_SIZE=16)(
    input   wire                    clk,
    input   wire                    rst_n,
    input   wire [23:0]             addr,
    input   wire                    rd,
    output  wire                    done,
    output  wire [(LINE_SIZE*8)-1: 0]   line,      

    output  reg                     sck,
    output  reg                     ce_n,
    input   wire[3:0]               din,
    output      [3:0]               dout,
    output  wire                    douten
);

    localparam LINE_BYTES = LINE_SIZE;
    localparam LINE_CYCLES = LINE_BYTES * 8;

    parameter IDLE=1'b0, READ=1'b1;

    reg         state, nstate;
    reg [7:0]   counter;
    reg [23:0]  saddr;
    reg [7:0]   data [LINE_BYTES-1 : 0]; 

    reg         first;

    wire[7:0]   EBH     = 8'heb;
    
    // for debugging
    wire [7:0] data_0 = data[0];
    wire [7:0] data_1 = data[1];
    wire [7:0] data_15 = data[15];


    always @*
        case (state)
            IDLE: if(rd) nstate = READ; else nstate = IDLE;
            READ: if(done) nstate = IDLE; else nstate = READ;
        endcase 

    always @ (posedge clk or negedge rst_n)
        if(!rst_n) first = 1'b1;
        else if(first & done) first <= 0;

    
    always @ (posedge clk or negedge rst_n)
        if(!rst_n) state = IDLE;
        else state <= nstate;

    always @ (posedge clk or negedge rst_n)
        if(!rst_n) sck <= 1'b0;
        else if(~ce_n) sck <= ~ sck;
        else if(state == IDLE) sck <= 1'b0;

    always @ (posedge clk or negedge rst_n)
        if(!rst_n) ce_n <= 1'b1;
        else if(state == READ) ce_n <= 1'b0;
        else ce_n <= 1'b1;

    always @ (posedge clk or negedge rst_n)
        if(!rst_n) counter <= 8'b0;
        else if(sck & ~done) counter <= counter + 1'b1;
        else if(state == IDLE) 
            if(first) counter <= 8'b0;
            else counter <= 8'd8;

    always @ (posedge clk or negedge rst_n)
        if(!rst_n) saddr <= 24'b0;
        else if((state == IDLE) && rd) saddr <= addr;

    always @ (posedge clk)
        if(counter >= 20 && counter <= 19+LINE_BYTES*2)
            if(sck) data[counter/2 - 10] <= {data[counter/2 - 10][3:0], din}; // Optimize!

    assign dout     =   (counter < 8)   ? EBH[7 - counter] :
                        (counter == 8)  ? saddr[23:20] : 
                        (counter == 9)  ? saddr[19:16] :
                        (counter == 10)  ? saddr[15:12] :
                        (counter == 11)  ? saddr[11:8] :
                        (counter == 12)  ? saddr[7:4] :
                        (counter == 13)  ? saddr[3:0] :
                        (counter == 14)  ? 4'hA :
                        (counter == 15)  ? 4'h5 : 4'h0;    
        
    assign douten   = (counter < 20);

    assign done     = (counter == 19+LINE_BYTES*2);


    generate
        genvar i; 
        for(i=0; i<LINE_BYTES; i=i+1)
            assign line[i*8+7: i*8] = data[i];
    endgenerate

endmodule


module DMC_Nx16 #(parameter NUM_LINES = 16, LINE_SIZE = 16) (
    input wire          clk,
    input wire          rst_n,
    // 
    input wire  [23:0]  A,
    input wire  [23:0]  A_h,
    output wire [31:0]  Do,
    output wire         hit,
    //
    input wire [(LINE_SIZE*8)-1:0]  line,
    input wire          wr
);

    localparam      LINE_WIDTH  = LINE_SIZE * 8;
    localparam      INDEX_WIDTH = $clog2(NUM_LINES);
    localparam      OFF_WIDTH   = $clog2(LINE_SIZE);
    localparam      TAG_WIDTH   = 24 - INDEX_WIDTH - OFF_WIDTH;
    
    //
    reg [(LINE_WIDTH - 1): 0]   LINES   [(NUM_LINES-1):0];
    reg [(TAG_WIDTH - 1) : 0]   TAGS    [(NUM_LINES-1):0];
    reg                         VALID   [(NUM_LINES-1):0];

    wire [(OFF_WIDTH - 1) : 0]  offset  =   A[(OFF_WIDTH - 1): 0];
    wire [(INDEX_WIDTH -1): 0]  index   =   A[(OFF_WIDTH+INDEX_WIDTH-1): (OFF_WIDTH)];
    wire [(TAG_WIDTH-1)   : 0]  tag     =   A[23:(OFF_WIDTH+INDEX_WIDTH)];

    wire [(INDEX_WIDTH -1): 0]  index_h =   A_h[(OFF_WIDTH+INDEX_WIDTH-1): (OFF_WIDTH)];
    wire [(TAG_WIDTH-1)   : 0]  tag_h   =   A_h[23:(OFF_WIDTH+INDEX_WIDTH)];

    
    assign  hit =   VALID[index_h] & (TAGS[index_h] == tag_h);

    // Change this to support lines other than 16 bytes
    
    assign  Do  =   (offset[3:2] == 2'd0) ?  LINES[index][31:0] :
                    (offset[3:2] == 2'd1) ?  LINES[index][63:32] :
                    (offset[3:2] == 2'd2) ?  LINES[index][95:64] :
                    LINES[index][127:96];
    /*
    assign  Do  =   (offset[4:2] == 2'd0) ?  LINES[index][31:0] :
                    (offset[4:2] == 2'd1) ?  LINES[index][63:32] :
                    (offset[4:2] == 2'd2) ?  LINES[index][95:64] :
                    (offset[4:2] == 2'd3) ?  LINES[index][127:96] :
                    (offset[4:2] == 2'd4) ?  LINES[index][159:128] :
                    (offset[4:2] == 2'd5) ?  LINES[index][191:160] :
                    (offset[4:2] == 2'd6) ?  LINES[index][223:192] :
                    LINES[index][255:224] ;
    */                
    
    // clear the VALID flags
    integer i;
    always @ (posedge clk or negedge rst_n)
        if(!rst_n) 
            for(i=0; i<NUM_LINES; i=i+1)
                VALID[i] <= 1'b0;
        else  if(wr)  VALID[index]    <= 1'b1;

    always @(posedge clk)
        if(wr) begin
            LINES[index]    <= line;
            TAGS[index]     <= tag;
        end

endmodule
