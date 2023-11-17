#include <vector>
#include <iostream>

#include "CImg.h"
using namespace cimg_library;

typedef unsigned long long ptr_type;

class ReadImage {
public:
    ReadImage(char* filename) : image(filename), currentPixel(0) {
        std::cout << "Opened image with " << image.size() << " pixels" << std::endl;
    }

    ~ReadImage() {
        std::cout << "Read " << currentPixel << std::endl;
    }

    // Use this method for stream-like access
    char getPixel() {
        return image.data()[currentPixel++];
    }

    char getPixelAt(unsigned int idx) {
        if(idx >= image.size()) {
            std::cout << "WARN: Access out of bounds" << std::endl;
            return 0;
        }
        return image.data()[idx];
    }

private:
    CImg<unsigned char> image;
    unsigned int currentPixel;
};

extern "C" {
    ptr_type readImage_create(char* filename) {
        return (ptr_type)new ReadImage(filename);
    }

    void readImage_delete(ptr_type addr) {
        delete ((ReadImage*)addr);
    }

    char readImage_getPixel(ptr_type addr) {
        return ((ReadImage*)addr)->getPixel();
    }

    char readImage_getPixelAt(ptr_type addr, unsigned int idx) {
        return ((ReadImage*)addr)->getPixelAt(idx);
    }
}
