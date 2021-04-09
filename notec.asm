;Linux kernell system calls
SYS_WRITE equ 1
SYS_EXIT equ 60
SYS_READ equ 0

STDIN equ 0                    ; Standard input file descriptior
STDOUT equ 1                   ; Standard output file descriptior

NOT_RUNNING equ 0
WORKS equ 1
AWAITS equ 2

WRITE_EXIT_SIGN equ '=' ;– Wyjdź z trybu wpisywania liczby.
ADD_SIGN equ '+' ;– Zdejmij dwie wartości ze stosu, oblicz ich sumę i wstaw wynik na stos.
MUL_SIGN equ '*' ; Zdejmij dwie wartości ze stosu, oblicz ich iloczyn i wstaw wynik na stos.
ART_NEG_SIGN equ '-' ; Zaneguj arytmetycznie wartość na wierzchołku stosu.
AND_SIGN equ '&' ; Zdejmij dwie wartości ze stosu, wykonaj na nich operację AND i wstaw wynik na stos.
OR_SIGN equ '|' ; Zdejmij dwie wartości ze stosu, wykonaj na nich operację OR i wstaw wynik na stos.
XOR_SIGN equ '^' ; Zdejmij dwie wartości ze stosu, wykonaj na nich operację XOR i wstaw wynik na stos.
NEG_SIGN equ '~' ; Zaneguj bitowo wartość na wierzchołku stosu.
REMOVE_SIGN equ 'Z' ; Usuń wartość z wierzchołka stosu.
DUP_SIGN equ 'Y' ; Wstaw na stos wartość z wierzchołka stosu, czyli zduplikuj wartość na wierzchu stosu.
SWAP_SIGN equ 'X' ; Zamień miejscami dwie wartości na wierzchu stosu.
NOTEC_PUSH_SIGN equ 'N' ; Wstaw na stos liczbę Noteci.
INSTANCE_PUSH_SIGN equ 'n' ; Wstaw na stos numer instancji tego Notecia.
CALL_DEBUG_SIGN equ 'g' ; Wywołaj funkcję debug
WAIT_SIGN equ 'W' ; Zdejmij wartość ze stosu, potraktuj ją jako numer instancji Notecia m. Czekaj na operację W Notecia m ze zdjętym ze stosu numerem instancji Notecia n i zamień wartości na wierzchołkach stosów Noteci m i n.

WRITE_MODE_OFF equ 0
WRITE_MODE_ON equ 1


global notec
section .bss
    alignb 4
    thread_status: resb N
    THREAD_WAITS_FOR: resb N
    THREAD_STACK_POINTER: resb N
    spin_lock resd 1 ; 1 raz 32 bity

section .rodata
    msg db "LET'S GO!", 0x0a
    len equ $ - msg
    new_line db `\n`

; --------------------------------------------------------------------------------------------------
section .text

; Jump if (value is) in interval
; %1 - value to validated if is in interval
; %2 - lower interval value
; %3 - higher interval value
; %4 - jump there if in interval value
%macro jiii 4                  ; Jump if (value is) in interval
    cmp %1, %2                 ; Compare with lower acceptable value
    jl %%not_in                ; Skip if the value is lower than the lower acceptable value
    cmp %1, %3                 ; Compare with higher acceptable value
    jg %%not_in                ; Skip if the value is greater than the higher acceptable value
    jmp %4                     ; Value is in the interval, jump there
%%not_in:                      ; Label to skip the jump if not in the interval
%endmacro

; Check if operation requiring 1 value on stack can be performed
; %1 - place to jump if operation can be performed
%macro one_val_op 1            ; Check if operations can be performed
    mov rbx, WRITE_MODE_OFF    ; Another sign was met, write mode is off
    mov rdi, rsp               ; Get stack pointer address value
    cmp rdi, rbp               ; Compare if stack pointer is not set on initial stack address
    je interpreted             ; If equals stack is empty, operation can not be performed
    pop rdi                    ; Get value from stack for further evaluation
    jmp %1                     ; Jump to operation to be performed
%endmacro

; Check if operation requiring 2 values on stack can be performed
; %1 - place to jump if operation can be performed
%macro two_vals_op 1           ; Check if operations can be performed
    mov rbx, WRITE_MODE_OFF    ; Another sign was met, write mode is off
    mov rdi, rsp               ; Get stack pointer address value
    cmp rdi, rsp               ; Compare if stack pointer is not set on initial stack address
    je interpreted             ; If equals stack is empty, operation can not be performed
    pop rdi                    ; Get first value from stack for further evaluation

    mov rsi, rsp               ; Get stack pointer address to second value
    cmp rsi, rbp               ; Compare if stack pointer is not set on initial stack address
    je %%no_second_value       ; If equals stack is empty, operation can not be performed
    jmp %1                     ; Operation cna be performed, rsi and rdi stores first two values
%%no_second_value:
    push rdi                   ; First value need to be put on the stack again
    jmp interpreted            ; Jump to the end of character interpretation
%endmacro

add_op:                        ; Adding operation
    two_vals_op add_cont       ; Checks if operation can be performed
add_cont:                      ; If can be performed two_vals_op jumps there
    mov rax, rdi               ; Put first value to rax (To maintain consistency) 
    add rax, rsi               ; Add first and second value
    push rax                   ; Put sum to the stack
    jmp interpreted            ; Finish this character interpretation

mul_op:                        ; Multiply operation
    two_vals_op mul_cont       ; Checks if operation can be performed
mul_cont:                      ; If can be performed two_vals_op jumps there
    mov rax, rdi               ; Put first value to rax
    mul rsi                    ; Multiply first and second value
    push rax                   ; Put result to the stack
    jmp interpreted            ; Finish this character interpretation

art_neg_op:                    ; Artmethic negation operation
    one_val_op art_neg_cont    ; Checks if operation can be performed
art_neg_cont:                  ; If can be performed two_vals_op jumps there
    xor rax, rdi               ; Put zero to the rax
    sub rax, rdi               ; Subtract value from 0 (Artmethic negation)
    push rax                   ; Put result to the stack
    jmp interpreted            ; Finish this character interpretation

and_op:                        ; And operation
    two_vals_op and_cont       ; Checks if operation can be performed
and_cont:                      ; If can be performed two_vals_op jumps there
    mov rax, rdi               ; Put first value to rax (To maintain consistency) 
    and rax, rsi               ; Perform bitwise "and" operation on first and second value
    push rax                   ; Put result to the stack
    jmp interpreted            ; Finish this character interpretation

or_op:                         ; Or operation
    two_vals_op or_cont        ; Checks if operation can be performed
or_cont:                       ; If can be performed two_vals_op jumps there
    mov rax, rdi               ; Put first value to rax (To maintain consistency)
    or rax, rsi                ; Perform bitwise "or" operation on first and second value
    push rax                   ; Put result to the stack
    jmp interpreted            ; Finish this character interpretation

write_exit_op:
    mov rbx, WRITE_MODE_OFF
    jmp interpreted

xor_op:
    two_vals_op xor_cont
xor_cont:
    xor rax, rax
    mov rax, rdi
    xor rax, rsi
    push rax
    jmp interpreted

neg_op:
    one_val_op neg_cont
neg_cont:
    mov rax, rdi
    neg rax
    push rax
    jmp interpreted
    
remove_op:
    one_val_op remove_cont
remove_cont:
    jmp interpreted

dup_op:
    one_val_op dup_cont
dup_cont:
    mov rax, rdi
    push rax
    push rax

swap_op:
    two_vals_op swap_cont
swap_cont:
    push rsi
    push rdi
    jmp interpreted

notec_push_op:
    mov rbx, WRITE_MODE_OFF
    push N
    jmp interpreted

instance_push_op:
    mov rbx, WRITE_MODE_OFF
    push r12
    jmp interpreted

call_debug_op:
    mov rbx, WRITE_MODE_OFF
    mov rsi, r12
    mov rdi, rsp
;   call debug
    mov rax, 123
    leave
    ret

wait_op:
    mov rbx, WRITE_MODE_OFF
    mov rax, 666
    leave
    ret

strol16_num:
    sub rdi, '0'
    cmp rbx, WRITE_MODE_OFF
    je push_strol
    jmp add_to_top

strol16_small:
    sub rdi, 'a'
    add rdi, 10
    cmp rbx, WRITE_MODE_OFF
    je push_strol
    jmp add_to_top

strol16_big:
    sub rdi, 'A'
    add rdi, 10
    cmp rbx, WRITE_MODE_OFF
    je push_strol
    jmp add_to_top

push_strol:
    push rdi
    mov rbx, WRITE_MODE_ON
    jmp interpreted

add_to_top:
    pop rsi
    shl rsi, 4
    add rsi, rdi
    push rsi
    jmp interpreted

sign_interprete:
    jiii rdi, '0', '9', strol16_num
    jiii rdi, 'a', 'f', strol16_small
    jiii rdi, 'A', 'F', strol16_big
not_num_sign:
    cmp rdi, WRITE_EXIT_SIGN
    je write_exit_op
    cmp rdi, ADD_SIGN
    je add_op
    cmp rdi, MUL_SIGN
    je mul_op
    cmp rdi, ART_NEG_SIGN
    je art_neg_op
    cmp rdi, AND_SIGN
    je and_op
    cmp rdi, OR_SIGN
    je or_op
    cmp rdi, XOR_SIGN
    je xor_op
    cmp rdi, NEG_SIGN
    je neg_op
    cmp rdi, REMOVE_SIGN
    je remove_op
    cmp rdi, DUP_SIGN
    je dup_op
    cmp rdi, SWAP_SIGN
    je swap_op
    cmp rdi, NOTEC_PUSH_SIGN
    je notec_push_op
    cmp rdi, INSTANCE_PUSH_SIGN
    je instance_push_op
    cmp rdi, CALL_DEBUG_SIGN
    je call_debug_op
    cmp rdi, WAIT_SIGN
    je wait_op

    jmp interpreted

align 8
notec:                         ; uint64_t notec(uint32_t n, char const *calc)
    push rbp
    mov rbp, rsp               ; Make a stack frame
    mov r12, rdi               ; Save value of the n
    mov r13, rsi               ; Copy pointer to the calc
    xor r14, r14               ; Counter to the pointer 
    mov rbx, WRITE_MODE_OFF    ; Set write mode to off at start
notec_loop:
    lea rdi, [r13 + r14]       ; Get 8 bytes stored in pointer *calc
    movsx rdi, byte [rdi]      ; Get first value from calc
    cmp rdi, 0x00
    je exit
    inc r14
    jmp sign_interprete
interpreted:
    jmp notec_loop
exit:
    mov rax, r14
    leave
    ret
