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

module MS_QSPI_XIP_CACHE_ahbl_tb;
    wire        sck;
    wire        ce_n;
    wire [3:0]  din;
    wire [3:0]  dout;
    wire [3:0]  douten;    
    reg         HSEL;
    reg         HCLK;
    reg         HRESETn;
    reg [31:0]  HADDR;
    reg [1:0]   HTRANS;
    reg [31:0]  HWDATA;
    reg         HWRITE;
    wire        HREADY;

    wire        HREADYOUT;
    wire [31:0] HRDATA;

    `include "ahbl_tasks.vh"

    MS_QSPI_XIP_CACHE_ahbl DUV (
        // AHB-Lite Slave Interface
        .HSEL(HSEL),
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .HADDR(HADDR),
        .HTRANS(HTRANS),
        //.HWDATA(HWDATA),
        .HWRITE(HWRITE),
        .HREADY(HREADY),
        .HREADYOUT(HREADYOUT),
        .HRDATA(HRDATA),

        // External Interface to Quad I/O
        .sck(sck),
        .ce_n(ce_n),
        .din(din),
        .dout(dout),
        .douten(douten)   
    );    
    
    
    wire [3:0] SIO = (douten==4'b1111) ? dout : 4'bzzzz;

    assign din = SIO;

    sst26wf080b FLASH (
            .SCK(sck),
            .SIO(SIO),
            .CEb(ce_n)
        );

    initial begin
        $dumpfile("MS_QSPI_XIP_CACHE_ahbl_tb.vcd");
        $dumpvars;
        // Initializa flash memory ( the hex file inits first 10 bytes)
        #1 $readmemh("./vip/init.hex", FLASH.I0.memory);
        # 5000 $finish;
    end

    always #5 HCLK = ~HCLK;

    assign HREADY = HREADYOUT;

    initial begin
        HCLK = 0;
        HSEL = 0;
        HCLK = 0;
        HRESETn = 0;
        HADDR = 0;
        HTRANS = 0;
        HWDATA = 0;
        HWRITE = 0;

        // Reset Operation
        #100;
        @(posedge HCLK);
        HRESETn = 0;
        #75;
        @(posedge HCLK);
        HRESETn = 1;
        
        #100;
        
        ahbl_w_read(0);
        
        ahbl_w_read(4);

        ahbl_w_read(8);

        ahbl_w_read(16);
       
        #2000;
        $finish;
    end


endmodule