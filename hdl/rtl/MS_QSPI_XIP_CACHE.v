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
    AHB-Lite Quad I/O flash XiP controller with Nx16 RO Direct-mapped Cache.
    Intended to be used to execute only from an external Quad I/O SPI Flash Memory
*/

/*
    RTL Model for reading from Quad I/O flash using the QUAD I/O FAST READ (0xEB) command
    The Quad I/O bit has to be set in the flash memory (through flash programming); the 
    provided flash memory model has the bit set.

    Every transaction reads one cache line (128 bits or 16 bytes) from the flash.
    To start a transaction, provide the memory address and assert rd for 1 clock cycle.
    done is a sserted for 1 clock cycle when the data is ready

*/
module FLASH_READER_QSPI (
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
    localparam LINE_SIZE = 16;
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


module DMC_Nx16 #(parameter NUM_LINES = 16) (
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
    localparam      LINE_SIZE   = 16;
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
