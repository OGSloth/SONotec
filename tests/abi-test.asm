default rel

FAIL_LEN equ 16
SUCCES_LEN equ 17
SYS_WRITE equ 1
SYS_EXIT  equ 60
STDOUT    equ 1

section .rodata

big_cacl db "13432g3132g4g*53gY-g32ng+33g&123|33^gNZ~",0 ; wynik tego czegoś to podobno 18446744073709551359
message_fail db "Failed ABI test",10,0
message_succes db "ABI test success",10,0
message_dbg db "dbg msg",10,0

section .text

global _start
global debug
extern notec


debug:
    inc     r8
    mov     rax, rsp
    and     rax, 0xF
    mov     r9, r8
    cmp     rax, 8
    jne     fail
    mov     rdi, 420
    mov     rsi, 69
    mov     rdx, 2137
    mov     rcx, 2115
    mov     r9, 2021
    mov     rax, SYS_WRITE
    mov     rdi, STDOUT
    lea     rsi, [message_succes]
    mov     rdx, SUCCES_LEN

    xor     rax, rax
    ret

_start:
    push    1
    push    2
    push    3
    push    4
    mov     rbx, 1
    mov     rbp, 1
    mov     r12, 1
    mov     r13, 1
    mov     r14, 1
    mov     r15, 1
    mov     rdi, 0
    xor     r8, r8

    lea     rsi, [big_cacl]
    call    notec
    mov	    r9, 21
    cmp     rax, 18446744073709551359
    jne     fail

    mov     r9, 31
    cmp     rbx, 1
    jne     fail

    mov     r9, 41
    cmp     rbp, 1
    jne     fail

    mov     r9, 51
    cmp     r12, 1
    jne     fail

    mov     r9, 61
    cmp     r13, 1
    jne     fail

    mov	    r9, 71
    cmp     r14, 1
    jne     fail

    mov	    r9, 81
    cmp     r15, 1
    jne     fail

    mov	    r9, 91
    pop     rax
    mov	    r9, 10106
    cmp     rax, 4
    jne     fail

    mov	    r9, 101
    pop     rax
    cmp     rax, 3
    jne     fail

    mov	    r9, 111
    pop     rax
    cmp     rax, 2
    jne     fail

    mov	    r9, 121
    pop     rax
    cmp     rax, 1
    jne     fail
    jmp     success


fail:
    push    r9
    mov     rax, SYS_WRITE
    mov     rdi, STDOUT
    lea     rsi, [message_fail]
    mov     rdx, FAIL_LEN
    syscall
    pop     r9
    mov     rax, SYS_EXIT
    mov     rdi, r9
    syscall

success:
    mov     rax, SYS_WRITE
    mov     rdi, STDOUT
    lea     rsi, [message_succes]
    mov     rdx, SUCCES_LEN
    syscall
    mov     rax, SYS_EXIT
    mov     rdi, 0
    syscall
