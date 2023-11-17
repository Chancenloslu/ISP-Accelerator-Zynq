#include <opencv2/opencv.hpp>
#include <stdio.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/mman.h>

#define PAGESIZE 	256 * 4096

#define CMD_SET_ADDRRD _IO('s', 0)
#define CMD_SET_ADDRWR _IO('s', 1)
#define CMD_SET_START _IOW('s', 2, int)
#define CMD_GET_END   _IOR('s', 3, int)

using namespace cv;

int main(int argc, char *argv[]) {
	int fd;
	fd = open("/dev/sobel", O_RDWR);
	if(fd==-1) {
		perror("open");
		return fd;
	}
	
	void *dma_buffer_rd = mmap(NULL, PAGESIZE, PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
	printf("dma_buffer_rd = 0x%x\n", dma_buffer_rd);

	void *dma_buffer_wr = mmap(NULL, PAGESIZE, PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
	printf("dma_buffer_wr = 0x%x\n", dma_buffer_wr);
	

	// read image
	printf("read image %s\n", argv[1]);
	Mat img = imread(argv[1], IMREAD_GRAYSCALE);
	int rows = img.rows;
	int cols = img.cols;
	printf("start to copying image with %d rows and %d cols to dma...\n", rows, cols);
	memcpy(dma_buffer_rd, img.data, rows*cols);
		
	// start conversion
	ioctl(fd, CMD_SET_ADDRRD);
	ioctl(fd, CMD_SET_ADDRWR);
	ioctl(fd, CMD_SET_START, 1);

	// read status
	int end = 0;
	do {
		ioctl(fd, CMD_GET_END, &end);
		printf("read result = %d\n", end);
		sleep(1);
	}while(end == 0);
	
	
	// write image
	Mat new_img(rows, cols, CV_8UC1, Scalar(255));
	memcpy(new_img.data, dma_buffer_wr, rows*cols);
	
	imwrite(argv[2], new_img);
	printf("write image %s\n", argv[2]);
	
	
	munmap(dma_buffer_rd, PAGESIZE);
	munmap(dma_buffer_wr, PAGESIZE);
	close(fd);
	return 0;
}
