package SobelTop;
    import FIFO::*;
    import GetPut::*;
    import ClientServer::*;
    import Vector::*;
    import SingleBuffer::*;
    import Settings::*;
    import MyTypes::*;
    import RowBuffer::*;
    import Sobel_Filter::*;
    import DReg::*;

	
    interface SobelTop;
        interface Put#(GrayScale) request;
        interface Get#(GrayScale) response;
        
        method Action setStart();
        (* always_ready *)
        method Action clear();
    endinterface

    module mkSobelTop(SobelTop);
        FIFO#(GrayScale) in <- mkFIFO();
        FIFO#(GrayScale) out <- mkFIFO();
        Reg#(UInt#(32)) npix <- mkReg(0);
        Reg#(Bool) started <- mkReg(False);

        Server#(Vector#(9, GrayScale), GrayScale) 		filter 			<- mkSobel_Filter();
        RowBufferServer 								rowbuffer 		<- mkRowBuffer();
        Vector#(3, Vector#(3, Reg#(Maybe#(GrayScale)))) workingField 	<- replicateM(replicateM(mkReg(tagged Invalid)));

        Reg#(UInt#(2)) 	timeout <- mkReg(0); // Used to avoid edge pixels
        Reg#(UInt#(14)) col_cnt <- mkReg(fromInteger(width-2));

        Wire#(GrayScale) new_px <- mkWire();
        Wire#(Bool) rotate 		<- mkDWire(False);
        Reg#(Bool) tofilter 	<- mkDReg(False);

        rule read_in (started);
            let p0 = in.first;
            
            in.deq;
            new_px <= p0;
            rotate <= True;
            tofilter <= True;
        endrule

        rule populate;
            workingField[0][0] <= tagged Valid new_px;
            // Move forward in register field
            for(Integer x = 1; x <= 2; x = x + 1) begin
                for(Integer y = 0; y <= 2; y = y + 1) begin
                    workingField[y][x] <= workingField[y][x-1];
                end
            end
            // Populate and drain row buffers
            Vector#(2, Maybe#(GrayScale)) nextin;
            for(Integer y = 0; y < 2; y = y + 1) begin
                nextin[y] = workingField[y][2];
            end
            rowbuffer.request.put(nextin);
        endrule

        // Only put buffered values on working field if we have a new value so everything moves together
        rule drain(rotate);
            let nextout <- rowbuffer.response.get();
            for(Integer y = 0; y < 2; y = y + 1) begin
                workingField[y+1][0] <= nextout[y];
            end
        endrule

        rule constructKernel (isValid(workingField[2][2]) && tofilter && timeout == 0);
            Vector#(9, GrayScale) toSobel = replicate(0);
            for(Integer y = 0; y < 3; y = y + 1) begin
                for(Integer x = 0; x < 3; x = x + 1) begin
                    toSobel[3*y+x] = fromMaybe(0, workingField[y][x]);
                end
            end
            filter.request.put(toSobel);
            let t = col_cnt - 1;
            
            if(t == 0) begin
                timeout <= 3; // always wait 3 cycles so edge pixels don't cause computation
                col_cnt <= fromInteger(width-2);
            end
            else begin
                col_cnt <= t;
            end
        endrule

        rule wait_timeout(timeout > 0 && rotate); // only reduce timeout if data arrived
            timeout <= timeout - 1;
        endrule

        rule forwardResult;
            let t <- filter.response.get();
            //$display("forward result: %x", t, $time);
            out.enq(t);
        endrule

        method Action setStart() if(!started);
            started <= True;
        endmethod

        method Action clear() ;
            started <= False;
            rowbuffer.clear();
            for(Integer i = 0; i < 3; i = i + 1) begin
                for(Integer j = 0; j < 3; j = j + 1) begin
                    workingField[i][j] <= tagged Invalid;
                end
            end
        endmethod

        
        interface Put request = toPut(in);
        interface Get response = toGet(out);
        
    endmodule

endpackage
