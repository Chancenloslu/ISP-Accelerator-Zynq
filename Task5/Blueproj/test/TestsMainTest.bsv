package TestsMainTest;
    import StmtFSM :: *;
    import TestHelper :: *;
    import Sobel_Filter :: *;
    import BlueAXI::*;
    import ConverterTop :: *;
    import Connectable :: *;
    import ImageFunctions :: *;
    import Settings :: *;
    import GetPut :: *;

	function Stmt ma_wr_to_sl(AXI4_Lite_Master_Wr#(L_AW, L_DW) m_wr, Bit#(L_AW) addr, Bit#(L_DW) _config);
		return seq
			axi4_lite_write(m_wr, addr, _config);
			action
				let t <- axi4_lite_write_response(m_wr);
				if(t == OKAY) begin
					$display("Initialized configuration: %h.", _config);
				end
				else begin
					$display("Failed to Initialize configuration %h. The write request response is %d", _config, t);
				end
			endaction
		endseq;
	endfunction

    (* synthesize *)
    module [Module] mkTestsMainTest(TestHandler);

        ConverterTop#(L_AW, L_DW, F_AW, F_RD_DW, F_WR_DW, F_ID_W, F_USER_W) dut <- mkConverterTop();
        Reg#(UInt#(32)) readCounter <- mkReg(0);
        Reg#(UInt#(32)) pixel_count <- mkReg(0);
        //Reg#(Bit#(128)) pixel		<- mkReg(0);
        
        Reg#(UInt#(32)) writeCounter <- mkReg(0);
        Reg#(UInt#(64)) addressRead <- mkRegU;
        Reg#(UInt#(64)) addressWrite <- mkRegU;

        Reg#(UInt#(32)) n_pixels_in <- mkRegU;
        Reg#(UInt#(32)) n_pixels_out <- mkRegU;
        
		AXI4_Lite_Master_Wr#(L_AW, L_DW)		ps_wr_config <- mkAXI4_Lite_Master_Wr(0);
		AXI4_Lite_Master_Rd#(L_AW, L_DW) 	ps_rd_config <- mkAXI4_Lite_Master_Rd(0);
		mkConnection(ps_wr_config.fab, dut.axi_lite.wr_fab);
		mkConnection(ps_rd_config.fab, dut.axi_lite.rd_fab);
		
		AXI4_Slave_Rd#(F_AW, F_RD_DW, F_ID_W, F_USER_W)	ip_rd_pixel <- mkAXI4_Slave_Rd(0, 0);		// 0: BypassFIFOF
		AXI4_Slave_Wr#(F_AW, F_WR_DW, F_ID_W, F_USER_W) ip_wr_pixel <- mkAXI4_Slave_Wr(0, 0, 0);
		mkConnection(ip_rd_pixel.fab, dut.axi_full.rd_fab);
		mkConnection(ip_wr_pixel.fab, dut.axi_full.wr_fab);
		
		
        Stmt s = {
            seq				
                action
		            let t1 <- readImage_create("./picture.png");
		            addressRead <= t1;
		            $display("Reading image, is at: %d", t1);

		            n_pixels_in <= fromInteger(width) * fromInteger(height);
		            n_pixels_out <= fromInteger(width-2) * fromInteger(height-2);
		            let t2 <- writeImage_create("./AcceleratorTbOut", 0, fromInteger(width-2), fromInteger(height-2));

		            addressWrite <= t2;
		            $display("Writing image, is at: %d", t2);
		        endaction
		 
		        
	            ma_wr_to_sl(ps_wr_config, 5'd0, pack(addressRead));
				ma_wr_to_sl(ps_wr_config, 5'd4, pack(addressWrite));
				ma_wr_to_sl(ps_wr_config, 5'd8, 64'h1);
		        
		        par
		            for(readCounter <= 0; readCounter < n_pixels_in; readCounter <= readCounter + 1) action
		                let t <- ip_rd_pixel.request.get();
		                
				    	if(t.addr == pack(addressRead)) begin
				    		Bit#(128) pixel = 0;
				    		for(Integer i = 15; i >= 0; i = i - 1) begin
				            	let p <- readImage_getPixel(addressRead);
				            	pixel[i*8 + 7:i*8] = p;
				            end
				    		addressRead <= addressRead + 16;
							AXI4_Read_Rs#(128, 2 ,2) rs = defaultValue;
							rs.data = pixel;
				    		ip_rd_pixel.response.put(rs);
				    		$display("Reading pixel %h, is at: %x", pixel, t.addr);
			    		end

		            endaction
		            
		            for(writeCounter <= 0; writeCounter < n_pixels_out; writeCounter <= writeCounter + 1) action
		           		let a <- ip_wr_pixel.request_addr.get();
	        			let b <- ip_wr_pixel.request_data.get();
		                
		                writeImage_putPixel(unpack(a.addr), b.data[7:0]);
		            endaction
		        endpar
		        
		        
		        readImage_delete(addressRead);
		        writeImage_delete(addressWrite);
		        $display("Finished test");
            endseq
        };
        FSM testFSM <- mkFSM(s);

        method Action go();
            testFSM.start();
        endmethod

        method Bool done();
            return testFSM.done();
        endmethod
    endmodule

endpackage
