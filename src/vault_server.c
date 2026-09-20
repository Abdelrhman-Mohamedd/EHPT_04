#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <signal.h>

#define PORT 9999

// Artificial gadget to ensure a reliable JMP RSP is available
// since we compile without PIE but the system libraries might be randomized
void gadget() {
    __asm__("jmp *%rsp");
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
        
        // VULNERABILITY: Unbounded copy into 512-byte buffer
        strcpy(buffer, password);
        
        printf("[DEBUG] Auth check complete for: %s\n", buffer);
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
    
    // Prevent zombies
    signal(SIGCHLD, SIG_IGN);
    
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
