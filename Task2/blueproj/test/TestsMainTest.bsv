package TestsMainTest;

    import StmtFSM :: *;
    import TestHelper :: *;
    import Task2 :: *;
	import BlueAXI :: *;
	import Connectable :: *;
	import Vector :: *;
		
	function Stmt setup(AXI4_Lite_Master_Wr#(5, 32) m_wr, Int#(32) op1, Int#(32) op2, Int#(32) expOut);
		return seq
			axi4_lite_write(m_wr, 0, pack(op1));
			axi4_lite_write(m_wr, 4, pack(op2));
			$display("Initialized parameter with op1 = %d, op2 = %d.", op1, op2);
		endseq;
	endfunction
	
	function Stmt ma_wr_to_sl(AXI4_Lite_Master_Wr#(5, 32) m_wr, Bit#(5) addr, Int#(32) op);
		return seq
			axi4_lite_write(m_wr, addr, pack(op));
			action
				let t <- axi4_lite_write_response(m_wr);
				if(t == OKAY) begin
					$display("Initialized parameter with op = %d.", op);
				end
				else begin
					$display("Failed to Initialize parameter op = %d. The write request response is %d", op, t);
				end
			endaction
		endseq;
	endfunction
	
    (* synthesize *)
    module [Module] mkTestsMainTest(TestHandler);

        MySlave#(5, 32) dut <- mkTask2();
		
		AXI4_Lite_Master_Rd#(5, 32) m_rd <- mkAXI4_Lite_Master_Rd(0);
	    AXI4_Lite_Master_Wr#(5, 32) m_wr <- mkAXI4_Lite_Master_Wr(0);
	    /* wire connection */
	    mkConnection(m_rd.fab, dut.axi_lite.rd_fab);
	    mkConnection(m_wr.fab, dut.axi_lite.wr_fab);
	    
	    Vector#(6, Int#(32)) op1;
	    op1[0] = 1; op1[1] = 6; op1[2] = -3; op1[3] = 32; op1[4] = 9; op1[5] = 13;
	    Vector#(6, Int#(32)) op2;
	    op2[0] = 5; op2[1] = -6; op2[2] = 3; op2[3] = 2; op2[4] = 3; op2[5] = 5;
	    Vector#(6, Int#(32)) expOut;
	    expOut[0] = 5;
	    expOut[1] = -36;
	    expOut[2] = -9;
	    expOut[3] = 64;
	    expOut[4] = 27;
	    expOut[5] = 65;  
	    /*for(Integer i = 0, i < 5, i = i + 1) begin 
			expOut[i] = op1[i] * op2[i];
	    end*/
	    Reg#(UInt#(32)) idx <- mkReg(0);
	    //Wire#(Int#(32))	res <- mkWire;
	    
        Stmt s1 = { 
        	seq
            
				ma_wr_to_sl(m_wr, 5'd4, op1[2]);
				ma_wr_to_sl(m_wr, 5'd4, op2[2]);
				$display("Initialized parameter with op1 = %d, op2 = %d.", op1[2], op2[2]);
				axi4_lite_read(m_rd, 5'd0);

				action
	        		let r <- axi4_lite_read_response(m_rd);
	        		if(unpack(r) == expOut[2]) begin
	        			$display("calculation succeeds! Result is %d.", r);
	        		end
	        		else begin
	        			$display("wrong result expected %d, but got %d.", expOut[2], r);
	        		end
	        	endaction
				
					
		        /*seq
		        	action
		        		let r <- axi4_lite_read_response(m_rd);
		        		if(unpack(r) == expOut[idx]) begin
		        			$display("calculation succeeds! Result is %d.", r);
		        		end
		        		else begin
		        			$display("wrong result expected %d, but got %d.", expOut[idx], r);
		        		end
		        	endaction
            	endseq*/
            	
                $display("Hello World from the testbench.");
            $finish();
        	endseq
        };
        
        Stmt s2 = { 
        	seq
            	for(idx <= 0; idx<6; idx<=idx+1) seq
            	
					ma_wr_to_sl(m_wr, 5'd0, op1[idx]);
					ma_wr_to_sl(m_wr, 5'd4, op2[idx]);
					$display("Initialized parameter with op1 = %d, op2 = %d.", op1[idx], op2[idx]);
					
					axi4_lite_read(m_rd, 5'd8);
					action
			    		let r <- axi4_lite_read_response(m_rd);
			    		if(unpack(r) == expOut[idx]) begin
			    			Int#(32) t = unpack(r);
			    			$display("calculation succeeds! Result is %d.", t);
			    		end
			    		else begin
				    		Int#(32) t = unpack(r);
			    			$display("wrong result expected %d, but got %d.", expOut[idx], t);
			    			$display("Test failed!");
			    			$finish();
			    		end
			    	endaction
				endseq
					
           	$display("Test succeeded");
            $finish();
        	endseq
        };
        
        FSM testFSM <- mkFSM(s2);

        method Action go();
            testFSM.start();
        endmethod

        method Bool done();
            return testFSM.done();
        endmethod
    endmodule
/*
    interface myMaster#(numeric type addrwidth, numeric type datawidth );
        interface AXI4_Lite_Master_Rd#(addrwidth, datawidth) master_rd;
        interface AXI4_Lite_Master_Wr#(addrwidth, datawidth) master_wr;
    endinterface

    module mkMyMaster(myMaster#(addrwidth, datawidth));
	    AXI4_Lite_Master_Rd#(addrwidth, datawidth) m_rd <- mkAXI4_Lite_Master_Rd(0);
	    AXI4_Lite_Master_Wr#(addrwidth, datawidth) m_wr <- mkAXI4_Lite_Master_Wr(0);
	    
		// Read from address 16 whenever possible
		rule foo;
			axi4_lite_read(m_rd, 16);
		endrule
		
	    rule bar;
			let r <- axi4_lite_read_response(m_rd);
			printColorTimed(GREEN, $format("Address 16 is %d", r)); // From BlueLib
		endrule
		
		
        let isRst <- isResetAsserted();
        FIFOF#(AXI4_Lite_Read_Rq_Pkg#(addrwidth)) in <- mkFIFO();
        FIFOF#(AXI4_Lite_Read_Rs_Pkg#(datawidth)) out <- mkFIFO();
        
        Wire#(Bool) arreadyIn <- mkBypassWire();
		Wire#(Bit#(addrwidth)) araddrOut <- mkDWire(unpack(0));
		Wire#(AXI4_Lite_Prot) arprotOut <- mkDWire(UNPRIV_SECURE_DATA);

        rule ;
            $display("The value read from the slave is %d", res);
        endrule
    endmodule*/

endpackage
