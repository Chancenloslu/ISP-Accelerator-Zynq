package SingleBuffer;

import GetPut::*;
import ClientServer::*;
import FIFO::*;
import SpecialFIFOs::*;
import BRAMFIFO::*;
import Settings::*;

import MyTypes::*;

interface BufferServer;
    method Action clear();
    interface Put#(Maybe#(GrayScale)) request;
    interface Get#(Maybe#(GrayScale)) response;
endinterface: BufferServer

// The buffer buffers width-3 values. It only allows to get a value if at least size one are filled.
// This buffer operates with BRAM fifos.
module mkSingleBuffer(BufferServer);

    // Takes a value, gives a value.
    FIFO#(Maybe#(GrayScale)) inputValue <- mkBypassFIFO;
    FIFO#(Maybe#(GrayScale)) outputValue <- mkBypassFIFO;
   
    // Stores values due to enq and deq in the same clock cycle.
    FIFO#(Maybe#(GrayScale)) bufferedValue <- mkSizedBRAMFIFO(width-3+1);

    // Only count to log(2, width-3) at max.
    Reg#(Bit#(12)) counterInput <- mkReg(0);
    // If once full, thats ok.
    Reg#(Bool) flag <- mkReg(False);
    rule drainInput;
        let value = inputValue.first;
        inputValue.deq;
        // Pass the value
        bufferedValue.enq(value);
        // Got enough? Pass those values out than.
        if(counterInput == fromInteger(width-3 - 1)) //actual counterInput is width-3
            flag <= True;
        else
            counterInput <= counterInput + 1;
    endrule

    rule fillOutputValid (flag);
        let value = bufferedValue.first;
        bufferedValue.deq;

        outputValue.enq(value);
    endrule

    method Action clear();
        counterInput <= 0;
        flag <= False;
        inputValue.clear();
        outputValue.clear();
        bufferedValue.clear();
    endmethod

    interface Put request = toPut(inputValue);
    interface Get response = toGet(outputValue);
endmodule


endpackage



