#define _GNU_SOURCE
#include <stdio.h>
#include <signal.h>
#include <ucontext.h>

void handler(int sig, siginfo_t *info, void *ucontext) {
    ucontext_t *uc = (ucontext_t *)ucontext;
    unsigned long long rip = uc->uc_mcontext.gregs[REG_RIP];
    unsigned long long rsp = uc->uc_mcontext.gregs[REG_RSP];
    unsigned long long ret_addr = *(unsigned long long *)rsp;
    printf("RIP: 0x%llx\n", rip);
    printf("si_addr: %p\n", info->si_addr);
    printf("Value at RSP: 0x%llx\n", ret_addr);
}

int main() {
    struct sigaction sa;
    sa.sa_flags = SA_SIGINFO;
    sa.sa_sigaction = handler;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGSEGV, &sa, NULL);
    
    __asm__("mov $0x3261413161413061, %rax; push %rax; ret");
    return 0;
}
