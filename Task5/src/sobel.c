#include <linux/init.h>
#include <linux/module.h>
#include <linux/miscdevice.h>
#include <linux/fs.h>
#include <linux/io.h>
#include <linux/kstrtox.h>
#include <linux/kernel.h>
#include <linux/dma-mapping.h>
#include <linux/slab.h>

unsigned int 		nr = 0;
unsigned int*		vir_myMisc;

static void*		cpu_addr_rd;
static void*		cpu_addr_wr;

static dma_addr_t 	dma_handler_rd;
static dma_addr_t	dma_handler_wr;

#define BUF_SIZE  	256 * 4096	// unit: byte

#define CNVT_ADDR	0x00A0000000
#define RANGE 		64 * 1024

#define CMD_SET_ADDRRD _IO('s', 0)
#define CMD_SET_ADDRWR _IO('s', 1)
#define CMD_SET_START _IOW('s', 2, int)
#define CMD_GET_END   _IOR('s', 3, int)

#define ADDRESS_RD 	(vir_myMisc + 0)
#define ADDRESS_WR 	(vir_myMisc + 1)
#define START		(vir_myMisc + 2)
#define CONV_END	(vir_myMisc + 3)

typedef enum  {
	READ_CPU_ADDR_RD,
	READ_CPU_ADDR_WR,
	WRITE_START_SIG,
	READ_END_SIG
} STATE_MACHINE;

STATE_MACHINE state;

/*************************************/
int misc_open(struct inode *inode, struct file *file);
int misc_release(struct inode *inode, struct file *file);
ssize_t misc_write (struct file *file, const char __user *ubuf, size_t size, loff_t *loff_t);
ssize_t misc_read (struct file *file, char __user * ubuf, size_t size, loff_t *loff_t);
int misc_mmap (struct file *filp, struct vm_area_struct *vma);
long misc_ioctl(struct file *file, unsigned int cmd, unsigned long value);
/*************************************/

static const struct file_operations misc_fops = {
	.owner 	= THIS_MODULE,
	.open 	= misc_open,
	.release= misc_release,
	.write	= misc_write,
	.read	= misc_read,
	.mmap	= misc_mmap,
	.unlocked_ioctl = misc_ioctl,
};

struct miscdevice misc_dev = {
	.minor = MISC_DYNAMIC_MINOR,
	.name = "sobel",
	.fops = &misc_fops,
};

int misc_mmap (struct file *filp, struct vm_area_struct *vma) {
	//int remap_page_range(unsigned long virt_add, unsigned long phys_add, unsigned long size, pgprot_t prot);
	//unsigned long offset = vma->vm_pgoff << PAGE_SHIFT;
	unsigned long start = vma->vm_start;
	unsigned long page;
	size_t size = vma->vm_end - vma->vm_start;
	vma->vm_page_prot = pgprot_noncached(vma->vm_page_prot);
	
	if (state == READ_CPU_ADDR_RD) {
		//pfn = dma_handler_rd >> PAGE_SHIFT;
		//remap_pfn_range();
		//page = vmalloc_to_pfn(cpu_addr_rd);
		page = (dma_handler_rd >> PAGE_SHIFT) + vma->vm_pgoff; // divide it with the size of page
		state = READ_CPU_ADDR_WR;
		printk("pfn for cpu_addr_rd = 0x%lx", page);
	}
	else if(state == READ_CPU_ADDR_WR) {
		page = (dma_handler_wr >> PAGE_SHIFT) + vma->vm_pgoff;
		//page = vmalloc_to_pfn(cpu_addr_wr);
		state = WRITE_START_SIG;
		printk("pfn for cpu_addr_wr = 0x%lx", page);
	}
	
	if (remap_pfn_range(vma, start, page, size, vma->vm_page_prot))
		return -EAGAIN;
	return 0;
}

long misc_ioctl(struct file *file, unsigned int cmd, unsigned long value) {
	
	int val;
	
	switch(cmd) {
		case CMD_SET_ADDRRD:
			*ADDRESS_RD = dma_handler_rd;
			printk("set addressread as %lld", dma_handler_rd);
		break;
		case CMD_SET_ADDRWR:
			*ADDRESS_WR = dma_handler_wr;
			printk("set addresswrite as %lld", dma_handler_wr);
		break;
		case CMD_SET_START:
			*START = value;
			printk("start conversion...");
		break;
		case CMD_GET_END:
			val = *CONV_END;
			if(copy_to_user((int *)value, &val, sizeof(val))!=0) { 
				printk("copy to user error");
				return -1;
			}
		break;
	}
	
	return 0;
}

int misc_open(struct inode *inode, struct file *file){
	struct device *dev = (&misc_dev)->this_device;
	if (dma_set_coherent_mask(dev, DMA_BIT_MASK(32))) {
		dev_warn(dev, "mydev: 32-bit DMA addressing not available\n");
		goto ignore_this_device;
	}

	printk("Hello, Sobel Filter converter"); 		//info given by printk can not showed through ssh
	
	cpu_addr_rd = dma_alloc_coherent(dev, BUF_SIZE, &dma_handler_rd, GFP_KERNEL);
	printk("cpu_addr_rd = 0x%p, dma_handler_rd = %lld", cpu_addr_rd, dma_handler_rd);
	
	cpu_addr_wr	= dma_alloc_coherent(dev, BUF_SIZE, &dma_handler_wr, GFP_KERNEL);
	printk("cpu_addr_wr = 0x%p, dma_handler_wr = %lld", cpu_addr_wr, dma_handler_wr);
	
	//dma_handle 	= dma_map_single(NULL, cpu_addr, BUF_SIZE, DMA_TO_DEVICE);
	
	return 0;

	ignore_this_device:
		return -1;
}

int misc_release(struct inode *inode, struct file *file){
	struct device *dev = (&misc_dev)->this_device;
	printk("Sobel Filter bye bye");
	//dma_unmap_single(NULL, dma_addr, BUF_SIZE, DMA_TO_DEVICE);
	dma_free_coherent(dev, BUF_SIZE, cpu_addr_rd, dma_handler_rd);
	dma_free_coherent(dev, BUF_SIZE, cpu_addr_wr, dma_handler_wr);
	
	nr = 0;
	return 0;
}

ssize_t misc_write (struct file *file, const char __user *ubuf, size_t size, loff_t *loff_t){
	char kbuf[64] = {0};
	unsigned int op;
	
	//dma_sync_single_for_device(NULL, dma_addr, size, DMA_TO_DEVICE);
	
	if(copy_from_user(kbuf, ubuf, size)!=0) {
		printk("copy from user error");
		return -1;
	}
	
	if(kstrtoint(kbuf, 10, &op) != 0){
		printk("convert arg %s to integer failed.", kbuf);
		return -1;
	}
		
	return 0;
}

ssize_t misc_read (struct file *file, char __user * ubuf, size_t size, loff_t *loff_t){
	char kbuf[50];

	int end = *CONV_END;
	if(snprintf(kbuf, 50, "%d", end) < 0) {
		printk(KERN_ERR "Error converting integer to string\n");
	}
	//sprinf(kbuf, "%d", res);
	
	if(copy_to_user(ubuf, kbuf, size)!=0) {
		printk("copy to user error");
		return -1;
	}
	if(end == 1){
		state = READ_CPU_ADDR_RD;
		printk("conversion ended");
	}
	return 0;
}

static int misc_init(void) {
	int ret;
	ret = misc_register(&misc_dev);
	if(ret<0) {
		printk("miscdevice >>Sobel Filter<< register failed!");
		return -1;
	}
	printk("miscdevice >>Sobel Filter<< register succeeded!");
	
	vir_myMisc = ioremap(CNVT_ADDR, RANGE);
	if(vir_myMisc == NULL) {
		printk("Sobel Filter ioremap error");
		return -EBUSY;
	}
	printk("Sobel Filter ioremap succeeded.");
	return 0;
}

static void misc_exit(void) {
	misc_deregister(&misc_dev);
	iounmap(vir_myMisc);
	printk("miscdevice >>Sobel Filter<< deregister succeeded!");
}

module_init(misc_init);
module_exit(misc_exit);

MODULE_AUTHOR("Chaoran Lu");
MODULE_LICENSE("GPL");

