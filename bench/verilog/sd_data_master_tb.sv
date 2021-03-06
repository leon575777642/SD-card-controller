//////////////////////////////////////////////////////////////////////
////                                                              ////
//// WISHBONE SD Card Controller IP Core                          ////
////                                                              ////
//// sd_data_master_tb.sv                                         ////
////                                                              ////
//// This file is part of the WISHBONE SD Card                    ////
//// Controller IP Core project                                   ////
//// http://opencores.org/project,sd_card_controller              ////
////                                                              ////
//// Description                                                  ////
//// testbench for sd_data_master module                          ////
////                                                              ////
//// Author(s):                                                   ////
////     - Marek Czerski, ma.czerski@gmail.com                    ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2013 Authors                                   ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE. See the GNU Lesser General Public License for more  ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from http://www.opencores.org/lgpl.shtml                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

`include "sd_defines.h"

module sd_data_master_tb();

parameter SD_TCLK = 20; // 50 MHz -> timescale 1ns

reg sd_clk;
reg rst;
reg start_tx_i;
reg start_rx_i;
reg [`DATA_TIMEOUT_W-1:0] timeout_i;
wire d_write_o;
wire d_read_o;
reg tx_fifo_empty_i;
reg rx_fifo_full_i;
reg xfr_complete_i;
reg crc_ok_i;
//2 - fifo un/ov
//1 - wrong crc
//0 - completed
wire [`INT_DATA_SIZE-1:0] int_status_o;
reg int_status_rst_i;

task reset_int_status;
    begin
    
        //reset int status
        int_status_rst_i = 1;
        #SD_TCLK;
        int_status_rst_i = 0;
        assert(int_status_o == 0);
        
    end
endtask

task start_read;
    begin
    
        start_tx_i = 1; //start filling tx fifo
        #SD_TCLK;
        start_tx_i = 0;
        wait(sd_data_master_dut.tx_cycle == 1);
        #(SD_TCLK/2);
        assert(d_write_o == 0);
        assert(d_read_o == 0);
        #(4*SD_TCLK);
        tx_fifo_empty_i = 0;
        wait(d_write_o == 1);
        #(SD_TCLK/2);
        xfr_complete_i = 0; //serial_data_host starts its state machine
        assert(d_read_o == 0);
        #(2*SD_TCLK);
        //check if d_write_o went low
        assert(d_write_o == 0);
        
    end
endtask

task check_end_read;
	input integer expected_status;
	begin
	
        assert(d_write_o == 0);
        assert(d_read_o == 0);    
        wait(sd_data_master_dut.tx_cycle == 0);
        #(SD_TCLK/2);
        assert(int_status_o == expected_status);
        
        reset_int_status;
        
    end
endtask

task end_read;
    input crc_ok;
    begin
    
        xfr_complete_i = 1;
        crc_ok_i = crc_ok;
        #SD_TCLK;
        //xfr_complete_i = 0; //signl stays in logic 1 after transmission
        crc_ok_i = 0;
        if (crc_ok)
            check_end_read(1 << `INT_DATA_CC);
        else
            check_end_read((1 << `INT_DATA_EI) | (1 << `INT_DATA_CCRCE));
        tx_fifo_empty_i = 1;

    end
endtask

task test_read;
    input crc_ok;
    begin
    
		start_read;

        #(10*SD_TCLK);

		end_read(crc_ok);
        
    end
endtask

task start_write;
    begin
    
		start_rx_i = 1; //start filling rx fifo and start sd_data_serial_host
        #SD_TCLK;
        start_rx_i = 0;
        wait(d_read_o == 1);
        #(SD_TCLK/2);
        xfr_complete_i = 0; //serial_data_host starts its state machine
        assert(d_write_o == 0);
        #(2*SD_TCLK);
        //check if d_read_o went low
        assert(d_read_o == 0);
        
    end
endtask

task check_end_write;
	input integer expected_status;
	begin
	
        assert(d_write_o == 0);
        assert(d_read_o == 0);
        wait(sd_data_master_dut.trans_done == 0);
        #(SD_TCLK/2);
        assert(int_status_o == expected_status);

        reset_int_status;
        
    end
endtask

task end_write;
    input crc_ok;
    begin
    
        xfr_complete_i = 1;
        crc_ok_i = crc_ok;
        #SD_TCLK;
        //xfr_complete_i = 0; //signl stays in logic 1 after transmission
        crc_ok_i = 0;
        if (crc_ok)
			check_end_write(1 << `INT_DATA_CC);
		else
			check_end_write((1 << `INT_DATA_EI) | (1 << `INT_DATA_CCRCE));
        
    end
endtask

task test_write;
    input crc_ok;
    begin
    
		start_write;
		
        #(10*SD_TCLK);
        
		end_write(crc_ok);
		
    end
endtask

task check_failed_read;
	input integer expected_status;
	begin
	
		assert(d_write_o == 1);
		assert(d_read_o == 1);
		wait(sd_data_master_dut.tx_cycle == 0);
		#(SD_TCLK/2);
		xfr_complete_i = 1;
		assert(int_status_o == expected_status);
        
        reset_int_status;
        
    end
endtask

task check_failed_write;
	input integer expected_status;
	begin
	
		assert(d_write_o == 1);
		assert(d_read_o == 1);
		wait(sd_data_master_dut.trans_done == 0);
		#(SD_TCLK/2);
		xfr_complete_i = 1;
		assert(int_status_o == expected_status);
		
		reset_int_status;
        
    end
endtask

sd_data_master sd_data_master_dut(
           .sd_clk(sd_clk),
           .rst(rst),
           .start_tx_i(start_tx_i),
           .start_rx_i(start_rx_i),
           .timeout_i(timeout_i),
           .d_write_o(d_write_o),
           .d_read_o(d_read_o),
           .tx_fifo_rd_en_i(1'b0),
           .tx_fifo_empty_i(tx_fifo_empty_i),
           .rx_fifo_wr_en_i(1'b0),
           .rx_fifo_full_i(rx_fifo_full_i),
           .xfr_complete_i(xfr_complete_i),
           .crc_ok_i(crc_ok_i),
           .int_status_o(int_status_o),
           .int_status_rst_i(int_status_rst_i)
       );

// Generating sd_clk clock
always
begin
    sd_clk=0;
    forever #(SD_TCLK/2) sd_clk = ~sd_clk;
end

initial
begin

    rst = 1;
    start_tx_i = 0;
    start_rx_i = 0;
    timeout_i = 0;
    tx_fifo_empty_i = 1;
    rx_fifo_full_i = 0;
    xfr_complete_i = 1; //this signal is 0 only when serial_data_host is busy
    crc_ok_i = 0;
    int_status_rst_i = 0;
    
    $display("sd_data_master_tb start ...");
    
    #(3*SD_TCLK);
    rst = 0;
    assert(d_write_o == 0);
    assert(d_read_o == 0);
    assert(int_status_o == 0);
    #(3*SD_TCLK);
    assert(d_write_o == 0);
    assert(d_read_o == 0);
    assert(int_status_o == 0);
    
    //set timeout
    timeout_i = 100;
    
    //just check simple read and simple write, the rest is done by the sd_data_serial_host
    //////////////////////////////////////////////////////////////////////////////////////
    test_read(1);
    
    //write test
    /////////////////////////////////////////////////////////////////////
    test_write(1);
    
    //check fifo error during read / write
    //////////////////////////////////////////////////////////////////////
    start_tx_i = 1; //start filling tx fifo
    #SD_TCLK;
    start_tx_i = 0;
    wait(sd_data_master_dut.tx_cycle == 1);
    #(4.5*SD_TCLK);
    tx_fifo_empty_i = 0; //tx fifo is not empty
    wait(d_write_o == 1);
    xfr_complete_i = 0;
    #(10.5*SD_TCLK);
    tx_fifo_empty_i = 1;
    #SD_TCLK;
    tx_fifo_empty_i = 0;
    
    // check_failed_read((1 << `INT_DATA_EI) | (1 << `INT_DATA_CFE));
	wait(sd_data_master_dut.tx_cycle == 0);
	#(SD_TCLK/2);
	xfr_complete_i = 1;
    
    reset_int_status;
    tx_fifo_empty_i = 1;
    
    //write test
    //////////////////////////////////////////////////////////////////////
    start_rx_i = 1; //start filling rx fifo and start sd_data_serial_host
    #SD_TCLK;
    start_rx_i = 0;
    wait(d_read_o == 1);
    xfr_complete_i = 0;
    #(10.5*SD_TCLK);
    rx_fifo_full_i = 1;
    #SD_TCLK;
    rx_fifo_full_i = 0;
    
    check_failed_write((1 << `INT_DATA_EI) | (1 << `INT_DATA_CFE));
    
    //write crc not ok
    //////////////////////////////////////////////////////////////////////
    test_read(0);
    
    //read crc not ok
    //////////////////////////////////////////////////////////////////////
    test_write(0);
    
    //timeout test
    //////////////////////////////////////////////////////////////////////
    start_read;

    wait(d_write_o == 1 && d_read_o == 1);
    check_failed_read((1 << `INT_DATA_EI) | (1 << `INT_DATA_CTE));
    tx_fifo_empty_i = 1;
    
    //write test
    start_write;
    
    wait(d_write_o == 1 && d_read_o == 1);
    check_failed_write((1 << `INT_DATA_EI) | (1 << `INT_DATA_CTE));

    //timeout=0 test
    ////////////////////////////////////////////////////////////////////////
    timeout_i = 0;
    #SD_TCLK;
    
    test_read(1);
    test_write(1);
    
    timeout_i = 100;

    #(10*SD_TCLK) $display("sd_data_master_tb finish ...");
    $finish;
    
end

endmodule
