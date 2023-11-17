#include <stdio.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char **argv){
	int fd;
	fd = open("/dev/myMisc", O_RDWR);
	
	char *buf;
	
	if(fd==-1) {
		perror("open");
		return fd;
	}
	
	
	buf = argv[1];
	printf("argv1 = %s\n", buf);
	write(fd, buf, sizeof(buf));
	
	buf = argv[2];
	printf("argv2 = %s\n", buf);
	write(fd, buf, sizeof(buf));
	
	read(fd, buf, sizeof(buf));
	printf("result = %s\n", buf);
	close(fd);
	
	return 0;
	
}
