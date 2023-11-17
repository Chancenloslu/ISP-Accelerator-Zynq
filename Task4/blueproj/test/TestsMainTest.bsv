package TestsMainTest;
    import StmtFSM :: *;
    import TestHelper :: *;
    import ConverterTop :: *;
    import BlueAXI :: *;
    import Vector :: *;
    import Connectable :: *;
    import GetPut :: *;

	function Stmt ma_wr_to_sl(AXI4_Lite_Master_Wr#(5, 32) m_wr, Bit#(5) addr, Bit#(32) _config);
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
    
    	ConverterTop#(32, 128, 128, 0, 0) dut <- mkConverterTop;
		
		AXI4_Lite_Master_Wr#(5, 32)		ps_wr_config <- mkAXI4_Lite_Master_Wr(0);
		AXI4_Lite_Master_Rd#(5, 32) 	ps_rd_config <- mkAXI4_Lite_Master_Rd(0);
		mkConnection(ps_wr_config.fab, dut.axi_lite.wr_fab);
		mkConnection(ps_rd_config.fab, dut.axi_lite.rd_fab);
		
		AXI4_Slave_Rd#(32, 128, 0, 0)	ip_rd_pixel <- mkAXI4_Slave_Rd(0, 0);		// 0: BypassFIFOF
		AXI4_Slave_Wr#(32, 128, 0, 0) 	ip_wr_pixel <- mkAXI4_Slave_Wr(0, 0, 0);
		mkConnection(ip_rd_pixel.fab, dut.axi_full.rd_fab);
		mkConnection(ip_wr_pixel.fab, dut.axi_full.wr_fab);
		
		Vector#(3, Bit#(128)) rgb;
		rgb[0] = 128'hffffffffffffffffffffffffffffffff;
		rgb[1] = 128'h0123456789abcdef0123456789abcdef;
		rgb[2] = 128'h00112233445566778899aabbccddeeff;
		/*
		r[0] = 200; r[1] = 100; r[2] = 50; r[3] = 255;
		Vector#(4, Bit#(8)) g;
		g[0] = 240; g[1] = 150; g[2] = 80; g[3] = 255;
		Vector#(4, Bit#(8)) b;
		b[0] = 180; b[1] = 200; b[2] = 120; b[3] = 255;
		*/
		
		
		//Reg#(UInt#(32)) read_x <- mkReg(0);
        //Reg#(UInt#(32)) read_y <- mkReg(0);
        //Reg#(UInt#(32)) writeCounter <- mkReg(0);
        //Reg#(UInt#(32)) addressRead <- mkRegU;
        //Reg#(UInt#(32)) addressWrite <- mkRegU;
        //Reg#(UInt#(32)) n_pixels <- mkRegU;
        Reg#(UInt#(32)) i <- mkRegU;
    	Reg#(Bit#(32)) addressRead <- mkReg(32'h10000000);
    	
        Stmt convertImage = seq 
        	$display("simulation starts...");
        	ma_wr_to_sl(ps_wr_config, 5'd0, 32'h10000000);
        	ma_wr_to_sl(ps_wr_config, 5'd4, 32'h20000000);
        	ma_wr_to_sl(ps_wr_config, 5'd8, 32'h1);
        	for(i<=0; i<3; i<=i+1) seq
		        action
		        	let t <- ip_rd_pixel.request.get();
		        	if(t.addr == addressRead) begin
		        		Bit#(128) pixel = rgb[i];
						AXI4_Read_Rs#(128, 0 ,0) rs = defaultValue;
						rs.data = pixel;
		        		ip_rd_pixel.response.put(rs);
		        		$display("Reading pixel %h, is at: %x", pixel, t.addr);
	        		end
		           addressRead <= addressRead + 16;
		        endaction
		    endseq
	        action
	        	let a <- ip_wr_pixel.request_addr.get();
	        	let b <- ip_wr_pixel.request_data.get();
	        	$display("Writing pixel: %h, at: %h", unpack(b.data), unpack(a.addr));
	        endaction    
	        
	        axi4_lite_read(ps_rd_config, 5'd12);
        
		    action
		    	let t <- axi4_lite_read_response(ps_rd_config);
		    	$display("end signal: %d", unpack(t));
		    endaction
	        
	        $display("simulation finishes...");
        endseq;

        FSM testFSM <- mkFSM(convertImage);

        method Action go();
            testFSM.start();
        endmethod

        method Bool done();
            return testFSM.done();
        endmethod
        
    endmodule

endpackage
