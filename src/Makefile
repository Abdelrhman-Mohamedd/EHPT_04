CC = gcc
CFLAGS = -g -O0 -fno-stack-protector -z execstack -no-pie

all: vault_server

vault_server: vault_server.c
	$(CC) $(CFLAGS) -o vault_server vault_server.c

clean:
	rm -f vault_server
