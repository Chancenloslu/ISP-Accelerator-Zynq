package ImageFunctions;
    import MyTypes::*;
    import Settings::*;
    import Vector::*;
    
    import "BDPI" function ActionValue#(UInt#(64)) readImage_create(String filename);
    import "BDPI" function Action readImage_delete(UInt#(64) addr);
    import "BDPI" function ActionValue#(GrayScale) readImage_getPixel(UInt#(64) addr);
    import "BDPI" function GrayScale readImage_getPixelAt(UInt#(64) addr, UInt#(32) idx);

    import "BDPI" function ActionValue#(UInt#(64)) writeImage_create(String filename, UInt#(32) iteration, UInt#(32) columns, UInt#(32) rows);
    import "BDPI" function Action writeImage_delete(UInt#(64) addr);
    import "BDPI" function Action writeImage_putPixel(UInt#(64) addr, GrayScale pixel);

    // Oracles
    import "BDPI" function GrayScale getGaussResult(Vector#(9, GrayScale) pixels);
    import "BDPI" function ActionValue#(UInt#(64)) oracle_create(UInt#(64) input_addr, UInt#(32) width, UInt#(32) height);
    import "BDPI" function Action oracle_delete(UInt#(64) oracle);
    import "BDPI" function ActionValue#(GrayScale) oracle_get_next_pixel(UInt#(64) oracle);

    // Other utilities
    function UInt#(32) xy_to_row_major(UInt#(32) x, UInt#(32) y);
        UInt#(32) res = y * fromInteger(width) + x;
        return res; // We don't need 64 bit here, as we will never load images with 4B x 4B resolution...
    endfunction

    function Tuple2#(Int#(32), Int#(32)) row_major_to_xy(UInt#(32) idx);
        Int#(32) x = unpack(pack(idx)) % fromInteger(width);
        Int#(32) y = unpack(pack(idx)) / fromInteger(width);
        return tuple2(x,y);
    endfunction

    function GrayScale get_padded_pixel(UInt#(64) addressRead, Int#(32) x, Int#(32) y);
        GrayScale result = 0;
        if(x >= 0 && y >= 0 && x < fromInteger(width) && y < fromInteger(height)) begin
            let idx = xy_to_row_major(unpack(pack(x)), unpack(pack(y)));
            result = readImage_getPixelAt(addressRead, idx);
        end
        return result;
    endfunction
endpackage : ImageFunctions