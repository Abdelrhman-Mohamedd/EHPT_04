#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

void print_flag() {
    FILE *f = fopen("/etc/lab04_flag", "r");
    if (f == NULL) {
        printf("Error: Could not open flag file.\n");
        printf("If you are running this locally for testing, make sure /etc/lab04_flag exists.\n");
        exit(1);
    }
    
    char flag[128];
    if (fgets(flag, sizeof(flag), f) != NULL) {
        printf("Congratulations! Here is your flag:\n%s\n", flag);
    } else {
        printf("Error reading flag file.\n");
    }
    
    fclose(f);
    exit(0);
}

void vuln() {
    char buffer[64];
    printf("Enter your name: ");
    // VULNERABILITY: read() reads more bytes than the buffer can hold!
    read(0, buffer, 256);
    printf("Hello, %s!\n", buffer);
}

int main(int argc, char **argv) {
    // Disable buffering for stdin/stdout to avoid issues with pwntools/pipes
    setvbuf(stdin, NULL, _IONBF, 0);
    setvbuf(stdout, NULL, _IONBF, 0);

    printf("--- VaultTech Legacy Authentication System ---\n");
    printf("[DEBUG] print_flag function is located at: %p\n", print_flag);
    
    vuln();
    
    printf("Authentication failed. Exiting normally.\n");
    return 0;
}
