obj-m += myMisc.o #compile to module
#KDIR := /opt/cad/xilinx/vitis/Vitis/2020.1/gnu/aarch64/lin/aarch64-linux/bin
KDIR := /net/bombur/cl61zyfi/linux-xlnx/
PWD ?= $(shell pwd)

CC = $(CROSS_COMPILE)gcc

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules
clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean || true
	-rm *.o *.ko *.mod.{c,o} modules.order Module.symvers || true
