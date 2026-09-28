#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <signal.h>
#include <ucontext.h>

#define PORT 9999

// Flag file paths (root:lab04 600 — student cannot read these)
#define FLAG_CRASH_FILE  "/etc/lab04_flag_crash"
#define FLAG_OFFSET_FILE "/etc/lab04_flag_offset"

// Read a flag from a root-owned file at runtime (anti-cheat: no strings in binary)
static int read_flag(const char *path, char *buf, size_t bufsz) {
    FILE *f = fopen(path, "r");
    if (!f) return -1;
    if (!fgets(buf, bufsz, f)) { fclose(f); return -1; }
    // Strip trailing newline
    buf[strcspn(buf, "\n")] = '\0';
    fclose(f);
    return 0;
}

// Intermediate Flag 2: The student must overwrite RIP with this address
void debug_offset() {
    char flag[128];
    FILE *f = fopen("/tmp/vault_offset.log", "w");
    if(f) {
        if (read_flag(FLAG_OFFSET_FILE, flag, sizeof(flag)) == 0) {
            fprintf(f, "OFFSET CONTROLLED! Flag 2: %s\n", flag);
        } else {
            fprintf(f, "OFFSET CONTROLLED! But could not read flag file.\n");
        }
        fclose(f);
    }
    exit(0);
}

// Intermediate Flag 1: The student must crash the service
void sigsegv_handler(int sig, siginfo_t *info, void *ucontext) {
    ucontext_t *uc = (ucontext_t *)ucontext;
    unsigned long long rip = uc->uc_mcontext.gregs[REG_RIP];
    unsigned long long rsp = uc->uc_mcontext.gregs[REG_RSP];
    unsigned long long *rsp_ptr = (unsigned long long *)rsp;
    unsigned long long faulting_addr = 0;
    
    // Safely read the value at RSP
    if (rsp != 0) {
        faulting_addr = *rsp_ptr;
    }

    char flag[128];
    FILE *f = fopen("/tmp/vault_crash.log", "w");
    if(f) {
        if (read_flag(FLAG_CRASH_FILE, flag, sizeof(flag)) == 0) {
            fprintf(f, "CRASH DETECTED! Flag 1: %s\n", flag);
        } else {
            fprintf(f, "CRASH DETECTED! But could not read flag file.\n");
        }
        fprintf(f, "Instruction Pointer (RIP) at crash: 0x%llx\n", rip);
        fprintf(f, "Faulting Return Address (at RSP): 0x%llx\n", faulting_addr);
        fclose(f);
    }
    // Restore default handler and re-raise to dump core
    signal(SIGSEGV, SIG_DFL);
    raise(SIGSEGV);
}

// Artificial gadget: JMP RAX is the correct approach for 64-bit strcpy overflows.
// strcpy returns the destination buffer pointer in RAX, so jumping to RAX
// executes our shellcode at the start of the buffer (avoiding null-byte issues).
void gadget() {
    __asm__("jmp *%rax");
}

void filter_bad_chars(char *input) {
    // Bad characters: \x00 (implied by string functions), \x0a (newline), \x0d (carriage return), \x2b (+)
    for (int i = 0; input[i] != '\0'; i++) {
        if (input[i] == '\x0a' || input[i] == '\x0d' || input[i] == '\x2b') {
            input[i] = '\0'; // Truncate payload at bad char
            break;
        }
    }
}

void process_auth(char *input) {
    char buffer[512];
    
    // Check if the command starts with AUTH 
    if (strncmp(input, "AUTH ", 5) == 0) {
        char *password = input + 5;
        
        filter_bad_chars(password);
        
        // Call printf BEFORE strcpy so it doesn't clobber the RAX register!
        printf("[DEBUG] Auth check complete for: %s\n", password);
        
        // VULNERABILITY: Unbounded copy into 512-byte buffer
        strcpy(buffer, password);
    } else {
        printf("Unknown command.\n");
    }
}

void handle_client(int client_sock) {
    char recv_buf[2048];
    memset(recv_buf, 0, sizeof(recv_buf));
    
    char *welcome = "Welcome to VaultTech Authentication Server v1.0\nCommands: AUTH <password>\n> ";
    send(client_sock, welcome, strlen(welcome), 0);
    
    ssize_t bytes_read = recv(client_sock, recv_buf, sizeof(recv_buf) - 1, 0);
    if (bytes_read > 0) {
        process_auth(recv_buf);
        char *response = "Authentication failed.\n";
        send(client_sock, response, strlen(response), 0);
    }
    
    close(client_sock);
    exit(0);
}

int main() {
    int server_sock, client_sock;
    struct sockaddr_in server_addr, client_addr;
    socklen_t client_len = sizeof(client_addr);
    
    // Prevent zombies and handle crashes
    signal(SIGCHLD, SIG_IGN);
    
    struct sigaction sa;
    sa.sa_flags = SA_SIGINFO;
    sa.sa_sigaction = sigsegv_handler;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGSEGV, &sa, NULL);
    
    server_sock = socket(AF_INET, SOCK_STREAM, 0);
    if (server_sock < 0) {
        perror("Socket creation failed");
        exit(1);
    }
    
    int opt = 1;
    setsockopt(server_sock, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = INADDR_ANY;
    server_addr.sin_port = htons(PORT);
    
    if (bind(server_sock, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0) {
        perror("Bind failed");
        exit(1);
    }
    
    if (listen(server_sock, 5) < 0) {
        perror("Listen failed");
        exit(1);
    }
    
    printf("VaultTech Auth Server listening on port %d...\n", PORT);
    
    while (1) {
        client_sock = accept(server_sock, (struct sockaddr*)&client_addr, &client_len);
        if (client_sock < 0) {
            perror("Accept failed");
            continue;
        }
        
        pid_t pid = fork();
        if (pid == 0) {
            // Child process
            close(server_sock);
            handle_client(client_sock);
        } else if (pid > 0) {
            // Parent process
            close(client_sock);
        } else {
            perror("Fork failed");
        }
    }
    
    return 0;
}
