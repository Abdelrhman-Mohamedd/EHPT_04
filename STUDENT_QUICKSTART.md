# Lab 04 Quick Start Guide

1. **Log in to the VM:** Use the credentials provided by your instructor (default: `student` / `labpassword`).
2. **Initialize:** The first time you log in, a graphical prompt will ask for your **Student ID**. Enter it carefully. This will generate your unique vulnerable environment.
3. **Locate the Target:** Open a terminal and navigate to `/srv/labs/lab04/bin/`. You will find the `vuln` executable.
4. **Analyze & Exploit:** Analyze the binary to find the buffer overflow vulnerability and the address of the `print_flag` function. Craft a payload to redirect execution to this function.
5. **Submit Flag:** Once you successfully exploit the binary, it will run with `lab04` privileges and print your unique flag from `/etc/lab04_flag`. Submit this flag to your instructor.
