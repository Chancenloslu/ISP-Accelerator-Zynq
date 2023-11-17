package Sobel_Filter;

import Real :: *;
import ClientServer :: *;
import GetPut :: *;
import FIFO :: *;
import Vector :: *;
import MyTypes :: *;


module mkSobel_Filter(Server#(Vector#(9, GrayScale), GrayScale));
	FIFO#(Vector#(9, GrayScale)) in <- mkFIFO();
    FIFO#(GrayScale) out <- mkFIFO();

    Vector#(9, Integer) gx; // horizontal weights
    gx[0] = 1; gx[1] = 0; gx[2] = -1;
    gx[3] = 2; gx[4] = 0; gx[5] = -2;
    gx[6] = 1; gx[7] = 0; gx[8] = -1;
	
	Vector#(9, Integer) gy; // vertical weights
    gy[0] = 1; gy[1] = 2; gy[2] = 1;
    gy[3] = 0; gy[4] = 0; gy[5] = 0;
    gy[6] = -1; gy[7] = -2; gy[8] = -1;

    rule convolve;
        let pixels = in.first();
        in.deq();
        Bit#(64) gx_res = 0;
        Bit#(64) gy_res = 0;
        for(Integer i = 0; i < 9; i = i + 1) begin
            Bit#(64) px_ex = extend(pixels[8-i]);
            gx_res = gx_res + (px_ex * fromInteger(gx[i]));
            gy_res = gy_res + (px_ex * fromInteger(gy[i]));
        end
        //Real x = $bitstoreal(gx_res);
        //Real y = $bitstoreal(gy_res);
        //Bit#(64) g = $realtobits(sqrt(x * x + y * y));
        Bit#(64) g = abs(gx_res) + abs(gy_res);
        out.enq(truncate(g >> 56));
    endrule

    interface Put request = toPut(in);
    interface Get response = toGet(out);

endmodule

endpackage
