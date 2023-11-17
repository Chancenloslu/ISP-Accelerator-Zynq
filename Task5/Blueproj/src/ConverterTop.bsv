package ConverterTop;
	import BlueAXI::*;
    import FIFO::*;
    import GetPut::*;
    import ClientServer::*;
    import Vector::*;
    import SingleBuffer::*;
    import Settings::*;
    import MyTypes::*;
    import RowBuffer::*;
    import SobelTop::*;
    import DReg::*;

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

interface ConverterTop#(numeric type lite_addrwidth, numeric type lite_datawidth, numeric type addrwidth, numeric type rddatawidth, numeric type wrdatawidth, numeric type id_width, numeric type user_width);
// Add custom interface definitions
	interface AXI_Full_Fab#(addrwidth, rddatawidth, wrdatawidth, id_width, user_width) axi_full;
	interface AXI_Lite_Fab#(lite_addrwidth, lite_datawidth) axi_lite;
endinterface



    module mkConverterTop(ConverterTop#(L_AW, L_DW, F_AW, F_RD_DW, F_WR_DW, F_ID_W, F_USER_W));
    
    	FIFO#(AXI4_Lite_Read_Rq_Pkg#(L_AW)) 		axi_lite_rd_rq 		<- mkFIFO();
		FIFO#(AXI4_Lite_Write_Rq_Pkg#(L_AW, L_DW))	axi_lite_wr_rq		<- mkFIFO();
		
		AXI4_Lite_Slave_Rd#(L_AW, L_DW)  	slave_rd    <- mkAXI4_Lite_Slave_Rd(0); //read request from master
        AXI4_Lite_Slave_Wr#(L_AW, L_DW)  	slave_wr    <- mkAXI4_Lite_Slave_Wr(0); //write request from master
        
        // work as master to transcate DMA
		AXI4_Master_Rd#(F_AW, F_RD_DW, F_ID_W, F_USER_W)  master_rd   <- mkAXI4_Master_Rd(2, 2, True); //read request from IP to DMA
        AXI4_Master_Wr#(F_AW, F_WR_DW, F_ID_W, F_USER_W)  master_wr   <- mkAXI4_Master_Wr(2, 2, 2, True); //write request from IP to DMA
        //Reg#(States) 					state_rd	<- mkReg(IDLE);
        //Reg#(States)					state_wr	<- mkReg(IDLE);
        Reg#(States)					state		<- mkReg(IDLE);
       	Vector#(16, FIFO#(GrayScale))	data_in		<- replicateM(mkFIFO());
        FIFO#(GrayScale)				data_out	<- mkFIFO();
        Reg#(UInt#(8))					count_in	<- mkReg(15);
        Reg#(UInt#(8))					count_out	<- mkReg(15);
        Reg#(Bool)						flag_out	<- mkReg(False);
        Reg#(UInt#(2))					time_count	<- mkReg(0);
        Reg#(UInt#(32)) 				npixel 		<- mkReg(0);
        Reg#(UInt#(32))					cc			<- mkReg(0);
        Reg#(UInt#(32))					cc1			<- mkReg(0);
        
        Reg#(Maybe#(UInt#(F_AW)))		addr_imag1 	<- mkReg(tagged Invalid);
        Reg#(Maybe#(UInt#(F_AW)))		addr_imag2 	<- mkReg(tagged Invalid);
		Reg#(Bool)						start		<- mkReg(False);
		Reg#(Bool) 						conv_end 	<- mkReg(False);
        SobelTop						sobelFilter	<- mkSobelTop();
        Reg#(UInt#(32))					npixel_out	<- mkReg(0);
        Reg#(UInt#(32))					count_pixel	<- mkReg(0);
        
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
					state		<= SEND_RQ_RD;
					sobelFilter.setStart();
					npixel		<= fromInteger(n_vals);
					npixel_out	<= fromInteger(n_out);
					$display("addr: %d, data: %h", t.addr, t.data);
				end
			endcase
			AXI4_Lite_Write_Rs_Pkg p;
			p.resp = OKAY;
			slave_wr.response.put(p);
		endrule
		
		rule read_pixel (state == SEND_RQ_RD);
			AXI4_Read_Rq#(F_AW, F_ID_W, F_USER_W) rq = defaultValue;
			rq.addr = pack(fromMaybe(0, addr_imag1));
			rq.burst_length = 0;	//burst length = 3
			rq.burst_size = unpack(fromInteger(4));		//16bytes 128 bits
			rq.burst_type = INCR;
			master_rd.request.put(rq);
			addr_imag1 <= tagged Valid (unpack(rq.addr) + 16);
			state <= READ;
			
			//$display("send read request");
		endrule
		
		rule pixel_in (state == READ);
			let t <- master_rd.response.get();
			Bit#(F_RD_DW) data = t.data;
			for(Integer i = 0; i<16; i=i+1) begin
				data_in[i].enq(data[7+8*i:8*i]);		// can combine two clock domain
			end
			
			if (cc < 4225) begin
				cc <= cc + 1;
				state <= SEND_RQ_RD;
				$display("read %d group pixel", cc);
			end
			else begin
				cc <= 0;
				state <= END;
			end
			//$display("read pixel");
		endrule

		rule pixel_dispatch;
			
			if(time_count == 0) begin
				//$display("pixel in", $time);
				let t = data_in[count_in].first();
				data_in[count_in].deq();
				sobelFilter.request.put(t);
				if(count_in>0)
					count_in <= count_in - 1;
				else 
					count_in <= 15;
				$display("get %d pixel", npixel);				
				npixel <= npixel - 1;
			end
			time_count <= time_count + 1;
		
		endrule
		
		rule forwardResult (!flag_out && start && npixel_out!=0);
        	
            let t <- sobelFilter.response.get();
            //data_out.enq(t);
            Bit#(F_WR_DW) data_out = extend(t);
            //$display("pixel count : %d", count_pixel);
            count_pixel <= count_pixel + 1;
            AXI4_Write_Rq_Addr#(F_AW, F_ID_W, F_USER_W) wr_rq_addr = defaultValue;
            wr_rq_addr.addr = pack(fromMaybe(0, addr_imag2));
            wr_rq_addr.burst_type = FIXED;
            wr_rq_addr.burst_length = 0;
            wr_rq_addr.burst_size = unpack(fromInteger(4));
            master_wr.request_addr.put(wr_rq_addr);
            
            AXI4_Write_Rq_Data#(F_WR_DW, F_USER_W) wr_rq_data = defaultValue;
			wr_rq_data.data = data_out;
			wr_rq_data.strb = 16'h0001;
			
			master_wr.request_data.put(wr_rq_data);

            //axi4_write_data_single(master_wr, addr, data_out, 16'h0001);
			addr_imag2 <= tagged Valid (unpack(wr_rq_addr.addr) + 1);
			
			flag_out <= True;
			/*
            if(count_out > 0) begin
				data_out[count_out*8+7:count_out*8] <= t;
				count_out <= count_out - 1; 
            end
            else begin
            	data_out[7:0] <= t
				count_out <= 15;
				out_flag <= True;
            end*/
        endrule
        

        rule wr_rs_in (flag_out && start && npixel_out!=0);
			let t <- master_wr.response.get();
			$display(" %d cycle", npixel_out);
				npixel_out <= npixel_out - 1;
			if(t.resp == OKAY) begin
				flag_out <= False;
			end
			else begin
				flag_out <= False;
			end
		endrule
        
        rule conv_end_signal;
			let t <- slave_rd.request.get();
			if(t.addr == 12) begin
				AXI4_Lite_Read_Rs_Pkg#(L_DW) rs;
				rs.data = extend(pack(conv_end));
				rs.resp = OKAY;
				slave_rd.response.put(rs);
			end
			else begin
				AXI4_Lite_Read_Rs_Pkg#(L_DW) rs;
				rs.data = ?;
				rs.resp = EXOKAY;
				slave_rd.response.put(rs);
			end
		endrule
        
        rule postprocess (start && npixel_out == 0);
			addr_imag1 	<= tagged Invalid;
			addr_imag2 	<= tagged Invalid;
			start		<= False;
			conv_end	<= True;
			state 		<= IDLE;
			sobelFilter.clear();
			cc 			<= 0;
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
