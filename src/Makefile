CC = gcc
CFLAGS = -fno-stack-protector -z execstack -no-pie -g -O0

all: vuln

vuln: vuln.c
	$(CC) $(CFLAGS) -o vuln vuln.c

clean:
	rm -f vuln
