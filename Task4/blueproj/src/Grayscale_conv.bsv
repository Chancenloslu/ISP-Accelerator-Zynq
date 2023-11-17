package Grayscale_conv;

import MyTypes::*;
import GetPut::*;
import ClientServer::*;
import FIFO::*;
//import ImageFunctions::*;
import FixedPoint::*;
//import Settings::*;
import Vector::*;

(* synthesize *)
module mkGrayscale_converter(Server#(Field_RGB, GrayScale)); 
		
		FIFO#(Field_RGB) in <- mkFIFO();
        FIFO#(GrayScale) out <- mkFIFO();

		Vector#(3, FixedPoint#(8, 8)) coefficients;
		coefficients[2] = 0.2126;		//R
		coefficients[1] = 0.7152;		//G
		coefficients[0] = 0.0722;		//B 	
    	
    	rule convert;
			let rgb = in.first();
			in.deq();
			FixedPoint#(17, 16) mulres = 0;
			for(Integer i=0; i<3; i=i+1) begin
				FixedPoint#(9, 8) pixel = fromUInt(unpack(rgb[i]));
				mulres = mulres + fxptMult(pixel, coefficients[i]);
				//$display("pixel now = %d", fxptGetInt(mulres));
			end
			$display("pixel now = %d", fxptGetInt(mulres));
			out.enq(truncate(pack(fxptGetInt(mulres)))); // get the decimal part and pack into Bits
		endrule
	    
		interface Put request = toPut(in);
	  	interface Get response = toGet(out);

endmodule

endpackage
