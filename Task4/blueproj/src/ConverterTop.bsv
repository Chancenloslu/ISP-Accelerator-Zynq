package ConverterTop;

import BlueAXI :: * ;
import GetPut :: * ;
import MyTypes :: *;
import Grayscale_conv :: *;
import ClientServer::*; 
import FIFO :: *; 
import Vector :: *;

typedef enum {
	IDLE,
	SEND_RQ_RD,
	READ,
	WORK,
	SEND_RQ_WR,
	WRITE,
	ACCP_RS_WR,
	END
} States deriving (Eq, Bits);

interface AXI_Full_Fab#(numeric type addrwidth, numeric type rddatawidth, numeric type wrdatawidth, numeric type id_width, numeric type user_width);
	(* prefix="" *)
	interface AXI4_Master_Rd_Fab#(addrwidth, rddatawidth, id_width, user_width) rd_fab;
	(* prefix="" *)
    interface AXI4_Master_Wr_Fab#(addrwidth, wrdatawidth, id_width, user_width) wr_fab;
endinterface

interface AXI_Lite_Fab#(numeric type addrwidth, numeric type datawidth);
	(* prefix=""*)
	interface AXI4_Lite_Slave_Rd_Fab#(addrwidth, datawidth) rd_fab;
	(* prefix=""*)
	interface AXI4_Lite_Slave_Wr_Fab#(addrwidth, datawidth) wr_fab;
endinterface

interface ConverterTop#(numeric type addrwidth, numeric type rddatawidth, numeric type wrdatawidth, numeric type id_width, numeric type user_width);
// Add custom interface definitions
	interface AXI_Full_Fab#(addrwidth, rddatawidth, wrdatawidth, id_width, user_width) axi_full;
	interface AXI_Lite_Fab#(5, 32) axi_lite;
endinterface

/**
 * use burst can set bitwidth in BlueAXI
 * use state machine
 * 
 */
(* synthesize *)
module mkConverterTop(ConverterTop#(32, 128, 128, 0, 0)); 
		//int addrwidth = 5;
		//int datawidth = 32;

		Reg#(States) 					state		<- mkReg(IDLE);
		
		// work as master to transcate DMA
		AXI4_Master_Rd#(32, 128, 0, 0)  master_rd   <- mkAXI4_Master_Rd(2, 2, True); //read request from IP to DMA
        AXI4_Master_Wr#(32, 128, 0, 0) 	master_wr   <- mkAXI4_Master_Wr(2, 2, 2, True); //write request from IP to DMA
		Vector#(16, Server#(Field_RGB, GrayScale)) 	conv <- replicateM(mkGrayscale_converter());
		
		Vector#(3, FIFO#(AXI4_Read_Rs#(128, 0, 0))) data <- replicateM(mkFIFO());

		//Reg#(Bit#(384))					data_buffer	<- mkRegU();
		// work as slave to wait config from the master(PS)
		AXI4_Lite_Slave_Rd#(5, 32)  	slave_rd    <- mkAXI4_Lite_Slave_Rd(0); //read request from master
        AXI4_Lite_Slave_Wr#(5, 32)  	slave_wr    <- mkAXI4_Lite_Slave_Wr(0); //write request from master

		Reg#(Maybe#(UInt#(32)))			addr_imag1 	<- mkReg(tagged Invalid);
        Reg#(Maybe#(UInt#(32)))			addr_imag2 	<- mkReg(tagged Invalid);
		Reg#(Bool)						start		<- mkReg(False);
		Reg#(Bool) 						conv_end 	<- mkReg(False);
		Reg#(Bool) 				image_size_fixed 	<- mkReg(True);

		FIFO#(AXI4_Lite_Read_Rq_Pkg#(5)) 		axi_lite_rd_rq 		<- mkFIFO();
		FIFO#(AXI4_Lite_Write_Rq_Pkg#(5, 32))	axi_lite_wr_rq		<- mkFIFO();
		Reg#(Bit#(3))					count		<- mkReg(0);
		Reg#(UInt#(16))					cycle		<- mkReg(0);
		rule config_in (state == IDLE);
			let t <- slave_wr.request.get();
			axi_lite_wr_rq.enq(t);
		endrule

		rule parse_config (state == IDLE);
			let t = axi_lite_wr_rq.first();
			axi_lite_wr_rq.deq();
			case(t.addr)
				0: begin
					addr_imag1 <= tagged Valid unpack(t.data);
					$display("addr: %d, data: %h", t.addr, t.data);
				end
				4: begin
					addr_imag2 <= tagged Valid unpack(t.data);
					$display("addr: %d, data: %h", t.addr, t.data);
				end
				8: begin
					start 		<= unpack(t.data[0]);
					conv_end	<= False;
					state 		<= SEND_RQ_RD;
					$display("addr: %d, data: %h", t.addr, t.data);
				end
			endcase
			AXI4_Lite_Write_Rs_Pkg p;
			p.resp = OKAY;
			slave_wr.response.put(p);

		endrule

		rule read_pixel (state == SEND_RQ_RD);
			/*AXI4_Read_Rq#(32, 0, 0) rq = defaultValue;
			rq.addr = pack(fromMaybe(0, addr_imag1));
			rq.burst_length = 2;	//burst length = 3
			rq.burst_size = unpack(fromInteger(4));		//16bytes 128 bits
			rq.burst_type = INCR;
			
			master_rd.request.put(rq);*/
			
			Bit#(32) addr = pack(fromMaybe(0, addr_imag1));
			axi4_read_data(master_rd, addr, 2);
			addr_imag1 <= tagged Valid (unpack(addr) + 16 * 3);
			state <= READ;
		
			
		endrule
		
		rule pixel_in (state == READ);
			let t <- master_rd.response.get();
			data[count].enq(t);
			if(t.last) begin
				state <= WORK;
				count <= 0;
			end else begin
				count <= count + 1;
			end
			/*
			if(count <= 1) begin
				let t <- master_rd.response.get();
				data[count].enq(t);
				count <= count + 1;
				$display("Read data %d time ", count);
			end else begin
				let t <- master_rd.response.get();
				data[count].enq(t);
				state <= WORK;
				count <= 0;
				$display("Read data %d time ", count);
				$display("state change from READ to WORK ");
			end*/
		endrule

		rule padded_pixel (state == WORK);
			Bit#(384) pixel = 0;
			for(Integer i=0; i<3; i=i+1) begin
				let t = data[i].first();
				pixel[127+(2-i)*128:(2-i)*128] = t.data;
				data[i].deq();
			end
			//if(r_pixel matches Valid .r &&& g_pixel matches Valid .g &&& b_pixel matches Valid .b) begin
			for(Integer i=15; i>=0; i=i-1) begin
				Field_RGB toConv;
				toConv[0] = pixel[(i*24+7):(i*24+0)];
				toConv[1] = pixel[(i*24+15):(i*24+8)];
				toConv[2] = pixel[(i*24+23):(i*24+16)];
				conv[i].request.put(toConv);
			end
			$display("PIXEL to converter: %h", pixel);
			state <= WRITE;
			//end
		endrule
/*
		rule wr_rq_out (state == SEND_RQ_WR);
			
			AXI4_Write_Rq_Addr#(32, 0, 0) wr_rq_addr = defaultValue;
			wr_rq_addr.addr = pack(fromMaybe(0, addr_imag2));
			wr_rq_addr.burst_length = 0; // +1 = 1
			wr_rq_addr.burst_size = unpack(fromInteger(4));
			wr_rq_addr.burst_type = INCR;
			master_wr.request_addr.put(wr_rq_addr);
			addr_imag2 <= tagged Valid (unpack(wr_rq_addr.addr) + 16 * (extend(wr_rq_addr.burst_length) + 1));
			state <= WRITE;

		endrule*/
		
		rule wr_data_out (state == WRITE);
			Bit#(128) out = 0;
			for(Integer i=15; i>=0; i=i-1) begin
				out[i*8+7:i*8] <- conv[i].response.get();
			end
			Bit#(32) addr = pack(fromMaybe(0, addr_imag2));
			axi4_write_data_single(master_wr, addr, out, 16'hffff);
			addr_imag2 <= tagged Valid (unpack(addr) + 16);
			
			/*AXI4_Write_Rq_Data#(128, 0) wr_rq_data = defaultValue;
			wr_rq_data.data = out;
			master_wr.request_data.put(wr_rq_data);*/
			state <= ACCP_RS_WR;
			
		endrule
		
		rule wr_rs_in (state == ACCP_RS_WR);
			let t <- master_wr.response.get();
			if(t.resp == OKAY) begin
				if(cycle < 4225) begin
					cycle <= cycle + 1;
					state <= SEND_RQ_RD;
				end
				else begin
					cycle <= 0;
					state <= END;
				end
			end
			else begin
				state <= WRITE;
			end
			
		endrule
		
		rule conv_end_signal;
			let t <- slave_rd.request.get();
			//axi_lite_wr_rq.enq(t);
			if(t.addr == 12) begin
				AXI4_Lite_Read_Rs_Pkg#(32) rs;
				rs.data = extend(pack(conv_end));
				rs.resp = OKAY;
				slave_rd.response.put(rs);
			end
			else begin
				AXI4_Lite_Read_Rs_Pkg#(32) rs;
				rs.data = ?;
				rs.resp = EXOKAY;
				slave_rd.response.put(rs);
			end
		endrule
		
		rule postprocess (state == END);
			addr_imag1 	<= tagged Invalid;
			addr_imag2 	<= tagged Invalid;
			start		<= False;
			conv_end	<= True;
			state		<= IDLE;
		endrule
		
		
	    interface AXI_Full_Fab axi_full;
		    interface AXI4_Master_Rd_Fab rd_fab = master_rd.fab;
		    interface AXI4_Master_Wr_Fab wr_fab = master_wr.fab;
		endinterface

		interface AXI_Lite_Fab axi_lite;
			interface AXI4_Lite_Slave_Rd_Fab rd_fab = slave_rd.fab;
			interface AXI4_Lite_Slave_Wr_Fab wr_fab = slave_wr.fab;
		endinterface

endmodule

endpackage


