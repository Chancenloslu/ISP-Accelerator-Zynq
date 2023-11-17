#include <linux/init.h>
#include <linux/module.h>
#include <linux/miscdevice.h>
#include <linux/fs.h>
#include <linux/io.h>
#include <linux/kstrtox.h>
#include <linux/kernel.h>

unsigned int nr = 0;
unsigned int *vir_myMisc;

#define MYMISC_ADDR 0x00A0010000
#define RANGE 64 * 1024

#define OP_1 (vir_myMisc + 0)
#define OP_2 (vir_myMisc + 1)
#define RES	 (vir_myMisc + 2)

int misc_open(struct inode *inode, struct file *file){
	printk("Hello myMisc"); //info given by printk can not showed through ssh
	return 0;
}

int misc_release(struct inode *inode, struct file *file){
	printk("misc bye bye");
	return 0;
}

ssize_t misc_write (struct file *file, const char __user *ubuf, size_t size, loff_t *loff_t){
	char kbuf[64] = {0};
	int op;
	if(copy_from_user(kbuf, ubuf, size)!=0) {
		printk("copy from user error");
		return -1;
	}
	
	if(kstrtoint(kbuf, 10, &op) != 0){
		printk("convert arg %s to integer failed.", kbuf);
		return -1;
	}
	if(nr == 0) { *OP_1 = op; nr++; printk("op1 is %d", op);}
	else if(nr == 1) { *OP_2 = op; nr++; printk("op2 is %d", op); nr = 0;}

	return 0;
}

ssize_t misc_read (struct file *file, char __user * ubuf, size_t size, loff_t *loff_t){
	char kbuf[64] = {0};
	int res = *RES;
	if(snprintf(kbuf, sizeof(kbuf), "%d", res) < 0) {
		printk(KERN_ERR "Error converting integer to string\n");
	}
	//sprinf(kbuf, "%d", res);
	
	if(copy_to_user(ubuf, kbuf, size)!=0) {
		printk("copy to user error");
		return -1;
	}
	printk("result is %d", res);
	return 0;
}

static const struct file_operations misc_fops = {
	.owner 	= THIS_MODULE,
	.open 	= misc_open,
	.release= misc_release,
	.write	= misc_write,
	.read	= misc_read,
};

struct miscdevice misc_dev = {
	.minor = MISC_DYNAMIC_MINOR,
	.name = "myMisc",
	.fops = &misc_fops,
};

static int misc_init(void) {
	int ret;
	ret = misc_register(&misc_dev);
	if(ret<0) {
		printk("misc register failed!");
		return -1;
	}
	printk("misc register succeeded!");
	
	vir_myMisc = ioremap(MYMISC_ADDR, RANGE);
	if(vir_myMisc == NULL) {
		printk("myMisc ioremap error");
		return -EBUSY;
	}
	printk("myMisc ioremap succeeded.");
	return 0;
}

static void misc_exit(void) {
	misc_deregister(&misc_dev);
	iounmap(vir_myMisc);
	printk("misc deregister succeeded!");
}

module_init(misc_init);
module_exit(misc_exit);

MODULE_LICENSE("GPL");
