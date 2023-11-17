# README
## File
[Task*](): the file directory that contains necessary file for the project of each tasks.

[documentation.md](documentation.md): my procedure of doing ESHO2 project.

[picture](./picture/): directory that contains pictures needed for documentation.
## How to recreate my project
To avoid wrong path to dependancies, download my project repository on the Desktop.

In each Task subdirectory constains a Tcl file.The file `Task*.tcl` contains all the information of the project. For example, to recreate task 2, just run
```
cd /Desktop/ChaoranLu/Task2/
source Task*.tcl
```
in the vivado tcl console window.

## How to load binary file into firmware
Bin file for every task is already stored in the /lib/firmware. Just run the following command to load them
```
echo task*.bit > /sys/class/fpga_manager/fpga0/firmware
```
## How to run
This is introduced in [documentation](./documentation.md)
