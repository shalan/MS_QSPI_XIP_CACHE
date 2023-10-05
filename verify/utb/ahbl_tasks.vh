    task ahbl_w_read;
        input [31:0] addr;
        begin
            //@(posedge HCLK);
            wait (HREADY == 1'b1);
            @(posedge HCLK);
            #1;
            HSEL = 1'b1;
            HTRANS = 2'b10;
            // First Phase
            HADDR = addr;
            @(posedge HCLK);
            HSEL = 1'b0;
            HTRANS = 2'b00;
            #2;
            wait (HREADY == 1'b1);
            @(posedge HCLK) 
                #1 $display("Read 0x%8x from 0x%8x", HRDATA, addr);
        end
    endtask
