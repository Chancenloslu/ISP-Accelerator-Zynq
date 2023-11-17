package Task2;

import BlueAXI :: * ;
import GetPut :: * ;
import FIFOF :: *;
import FIFO :: *;

interface AXI_Lite_Fab#(numeric type addrwidth, numeric type datawidth);
	(* prefix="axi_lite" *)
	interface AXI4_Lite_Slave_Rd_Fab#(addrwidth, datawidth) rd_fab;
	(* prefix="axi_lite" *)
    interface AXI4_Lite_Slave_Wr_Fab#(addrwidth, datawidth) wr_fab;
endinterface

interface MySlave #(numeric type addrwidth, numeric type datawidth);
	interface AXI_Lite_Fab#(addrwidth, datawidth) axi_lite;
endinterface

(* synthesize *)
module mkTask2(MySlave#(5, 32));
		//int addrwidth = 5;
		//int datawidth = 32;
		
	AXI4_Lite_Slave_Rd#(5, 32)  slave_rd    <- mkAXI4_Lite_Slave_Rd(0); //read request from master
    AXI4_Lite_Slave_Wr#(5, 32)  slave_wr    <- mkAXI4_Lite_Slave_Wr(0); //write request from master
	
	Reg#(Int#(32))					op1		<- mkReg(0);     
	Reg#(Bool)					op1_set		<- mkReg(False);
	Reg#(Int#(32))					op2		<- mkReg(0);
	Reg#(Bool)					op2_set		<- mkReg(False);
	Reg#(Int#(32))					res		<- mkReg(0);
	//Reg#(Bool)					res_set		<- mkReg(False);
	FIFO#(AXI4_Lite_Read_Rq_Pkg#(5))		rd_rq		<- mkFIFO();
	Reg#(Bit#(5))					wr_addr		<- mkReg(0);
	FIFO#(AXI4_Lite_Write_Rq_Pkg#(5, 32))		wr_rq		<- mkFIFO();
	Reg#(int)					op_set_counter	<- mkReg(0);
	Reg#(Bool)					wr_rq_received	<- mkReg(False);
	
	/* write request from master */
	rule wr_addr_data_in /*if(slave_wr.fab.awready && slave_wr.fab.wready)*/;
		let t <- slave_wr.request.get();
		wr_rq.enq(t);
		/*if(t.prot == UNPRIV_INSECURE_DATA) begin
			wr_rq.enq(t);
			AXI4_Lite_Write_Rs_Pkg p;
			p.resp = OKAY;
			slave_wr.response.put(p);
		end 
		
		else begin
			AXI4_Lite_Write_Rs_Pkg p;
			p.resp = EXOKAY;
			slave_wr.response.put(p);
		end*/
	endrule
	
	rule rd_op;   
		let t = wr_rq.first();
		wr_rq.deq();
		case(t.addr)
			0: begin 
				op1 <= unpack(t.data);
				//op1_set <= True;
			end
			4: begin
				op2 <= unpack(t.data);
				//op2_set <= True;
			end
	    endcase
		AXI4_Lite_Write_Rs_Pkg p;
		p.resp = OKAY;
		slave_wr.response.put(p);
    endrule

		rule mul;
			res <= op1 * op2;
		endrule
		/* read request from master */
        rule rd_rq_in /*if(slave_rd.fab.arready)*/; //todo: to see if the condition should be deleted
		let t <- slave_rd.request.get(); //AXI4_Lite_Read_Rq_Pkg
		rd_rq.enq(t);
        endrule 
        
        rule rd_resp /*(op1_set && op2_set)*/; //rd_rq.addr == 8 && rd_rq.prot == UNPRIV_SECURE_DATA
	        //AXI4_Lite_Read_Rq_Pkg#(addrwidth) rd_rq = slave_rd.first(); //AXI4_Lite_Read_Rq_Pkg
			let t = rd_rq.first(); rd_rq.deq();
			if(t.addr == 8) begin
				AXI4_Lite_Read_Rs_Pkg#(32) out;
				out.data = pack(res);
			    out.resp = OKAY;
			    slave_rd.response.put(out);
	        end
	        else begin
				AXI4_Lite_Read_Rs_Pkg#(32) out;
				out.data = ?;
			    out.resp = EXOKAY;
			    slave_rd.response.put(out);
	        end
	      
        endrule
	    
	    interface AXI_Lite_Fab axi_lite;
		    interface AXI4_Lite_Slave_Rd_Fab rd_fab = slave_rd.fab;
		    interface AXI4_Lite_Slave_Wr_Fab wr_fab = slave_wr.fab;
		endinterface
endmodule

endpackage
