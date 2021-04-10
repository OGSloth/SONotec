; Notec - Assigment 2
; Marcin Gadomski - mg370790

extern debug                   ; int64_t debug(uint32_t n, uint64_t *stack_pointer)

; Flags of the status of the current thread
FINISHED equ 0
AWAITS equ 1

; Not hexdecimal signs interpreted by notec
; If any of these is met, perform:
WRITE_EXIT_SIGN equ '='        ; Turn off write mode
ADD_SIGN equ '+'               ; Add two values from the top of the stack 
MUL_SIGN equ '*'               ; Multiply two values from the top of the stack 
ART_NEG_SIGN equ '-'           ; Arithmetic negation on the top value of the stack 
AND_SIGN equ '&'               ; AND operation on the two value from the top of the stack
OR_SIGN equ '|'                ; OR operation on the two value from the top of the stack
XOR_SIGN equ '^'               ; XOR operation on the two value from the top of the stack
NEG_SIGN equ '~'               ; Bitwise negation on the top value of the stack 
REMOVE_SIGN equ 'Z'            ; Remove top value from the top of the stack
DUP_SIGN equ 'Y'               ; Duplicate top value from the top of the stack
SWAP_SIGN equ 'X'              ; Swap first value from the top of the stack with second one 
NOTEC_PUSH_SIGN equ 'N'        ; Push notec number to the top of the stack
INSTANCE_PUSH_SIGN equ 'n'     ; Wstaw na stos numer instancji tego Notecia.
CALL_DEBUG_SIGN equ 'g'        ; Call debug function
WAIT_SIGN equ 'W'              ; Take value from the top of the stack, wait for intance to also call W and perform stacks swap

; Flags to be stored in rbx to determine if write mode is on or off
WRITE_MODE_OFF equ 0           ; Set if write mode is off
WRITE_MODE_ON equ 1            ; Set if write mdoe is on

ALIGN_VALUE equ 0xFFFFFFFFFFFFFFF0             ; Value stored for stack alighemnt

global notec
section .bss
    THREAD_STATUS: resb N
    WAITS_FOR: resq N
    TOP_VAL: resq N

;section .rodata
;    buffer times 8 db 0

section .text

; Jump if (value is) in interval
; %1 - value to validated if is in interval
; %2 - lower interval value
; %3 - higher interval value
; %4 - jump there if in interval value
%macro jiii 4                  ; Jump if (value is) in interval
    cmp %1, %2                 ; Compare with lower acceptable value
    jl %%not_in_interval       ; Skip if the value is lower than the lower acceptable value
    cmp %1, %3                 ; Compare with higher acceptable value
    jg %%not_in_interval       ; Skip if the value is greater than the higher acceptable value
    jmp %4                     ; Value is in the interval, jump there
%%not_in_interval:
%endmacro

; Check if operation requiring 1 value on stack can be performed
; %1 - place to jump if operation can be performed
%macro one_val_op 1            ; Check if operations can be performed
    mov rbx, WRITE_MODE_OFF    ; Another sign was met, write mode is off
    cmp rsp, rbp               ; Compare if stack pointer is not set on initial stack address
    je interpreted             ; If equals stack is empty, operation can not be performed
    pop rdi                    ; Get value from stack for further evaluation
    jmp %1                     ; Jump to operation to be performed
%endmacro

; Check if operation requiring 2 values on stack can be performed
; %1 - place to jump if operation can be performed
%macro two_vals_op 1           ; Check if operations can be performed
    mov rbx, WRITE_MODE_OFF    ; Another sign was met, write mode is off
    cmp rbp, rsp               ; Compare if stack pointer is not set on initial stack address
    je interpreted             ; If equals stack is empty, operation can not be performed
    pop rdi                    ; Get first value from stack for further evaluation

    cmp rbp, rsp               ; Compare if stack pointer is not set on initial stack address
    je %%no_second_value       ; If equals stack is empty, operation can not be performed
    pop rsi
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
    xor rax, rax               ; Put zero to the rax
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

write_exit_op:                 ; Turns off write mode
    mov rbx, WRITE_MODE_OFF    ; Simply sets flag to off mode
    jmp interpreted            ; Finish this character interpretation

xor_op:                        ; Xor operation
    two_vals_op xor_cont       ; Checks if operation can be performed
xor_cont:                      ; If can be performed two_vals_op jumps there
    mov rax, rdi               ; Put first value to rax (To maintain consistency)
    xor rax, rsi               ; Perform xor operation of two top stack values
    push rax                   ; Put the result to the stack
    jmp interpreted            ; Finish this character interpretation

neg_op:                        ; Bitwise negation operation
    one_val_op neg_cont        ; Checks if operation can be performed
neg_cont:                      ; If can be performed one_val_op jumps there
    mov rax, rdi               ; Move the value to the rax register
    not rax                    ; Perform negation
    push rax                   ; Put the result to the stack
    jmp interpreted            ; Finish this character interpretation
    
remove_op:                     ; Remove value from the top of the stack operation
    one_val_op remove_cont     ; Checks if operation can be performed
remove_cont:                   ; If can be performed one_val_op jumps there
    jmp interpreted            ; As value was already pop to the rsi we can just jump further

dup_op:                        ; Duplicate value from the top of the stack operation
    one_val_op dup_cont        ; Checks if operation can be performed
dup_cont:                      ; If can be performed one_val_op jumps there
    mov rax, rdi               ; Move value to the rax (To maintain consistency)
    push rax                   ; Restore value from the stack
    push rax                   ; Put duplicated value to the stack
    jmp interpreted            ; Finish this character interpretation

swap_op:                       ; Swap two top values from the stack
    two_vals_op swap_cont      ; Checks if operation can be performed
swap_cont:                     ; If can be performed two_vals_op jumps there
    push rdi                   ; Put previously top value to the stack
    push rsi                   ; Put previously second value as the top of the stack
    jmp interpreted            ; Finish this character interpretation

notec_push_op:                 ; Push compilation notec N value to the top of the stack
    mov rbx, WRITE_MODE_OFF    ; As this is not performed in other places turn off write mode
    push N                     ; Push the N value to the stack
    jmp interpreted            ; Finish this character interpretation

instance_push_op:              ; Push instance value number to the top of the stack
    mov rbx, WRITE_MODE_OFF    ; As this is not performed in other places turn off write mode
    push r12                   ; Push instance value number to the top of the stack
    jmp interpreted            ; Finish this character interpretation

call_debug_op:                 ; Set ups and calls provided debug functions
    mov rbx, WRITE_MODE_OFF    ; As another sign was met, turn off write mode
    mov rdi, r12               ; Move n as the first value
    mov rsi, rsp               ; Move stack pointer as the second value
    push rbp
    mov rbp,rsp                ; Make stack frame
    and rsp, ALIGN_VALUE       ; Enforce stack algiment for function call
    call debug                 ; Call debug function
    mov rsp, rbp               ; Stack frame destruction
    pop rbp                    ; Restoring base pointer (Initial stack pointer value address)

    shl rax, 3                 ; Convert recieved numbers from function to number of bytes
    add rsp, rax               ; Push stack by number of recieved bytes
    jmp interpreted            ; Finish this character interpretation

wait_op:
    mov rbx, WRITE_MODE_OFF
    pop rdi
    mov [WAITS_FOR + r12 * 8], rdi
    pop rsi
    mov [TOP_VAL + r12 * 8], rsi
    mov al, 1
    mov [THREAD_STATUS + r12], al

nop
is_waiting:
    mov al, [THREAD_STATUS + rdi]
    cmp al, 0
    jne is_waiting

    nop
busy_wait:
    mov rsi, [WAITS_FOR + rdi * 8]
    cmp rsi, r12
    jne busy_wait

    mov rsi, [TOP_VAL + rdi * 8]
    mov al, 0
    mov [THREAD_STATUS + r12], al
    push rsi

    nop
wait_for:
    mov al, [THREAD_STATUS + rdi]
    cmp al, 0
    jne wait_for

    mov rax, N                 ;
    mov [WAITS_FOR + r12 * 8], rax

    jmp interpreted

strol16_num:                   ; C like strol (to hexdecimal), but for a single numerical character
    sub rdi, '0'               ; Subtract ASCII numerical "shift" to match hexdecimal number
    cmp rbx, WRITE_MODE_OFF    ; Check if write mode is on
    je push_strol              ; If is on, perform pushing value to the top of the stack
    jmp add_to_top             ; Write mode is on, increase top value by currently recieved value

strol16_small:                 ; C like strol (to hexdecimal), but for a single small hexdecimal character
    sub rdi, 'a'               ; Subtract ASCII numerical "shift" to match hexdecimal number
    add rdi, 10                ; Add decimal base to convert to hexdecimal value
    cmp rbx, WRITE_MODE_OFF    ; Check if write mode is on
    je push_strol              ; If is on, perform pushing value to the top of the stack
    jmp add_to_top             ; Write mode is on, increase top value by currently recieved value

strol16_big:                   ; C like strol (to hexdecimal), but for a single capital hexdecimal character
    sub rdi, 'A'               ; Subtract ASCII numerical "shift" to match hexdecimal number
    add rdi, 10                ; Add decimal base to convert to hexdecimal value
    cmp rbx, WRITE_MODE_OFF    ; Check if write mode is on
    je push_strol              ; If is on, perform pushing value to the top of the stack
    jmp add_to_top             ; Write mode is on, increase top value by currently recieved value

push_strol:                    ; Pushes the strol value to the stack
    push rdi                   ; Push current value to the stack
    mov rbx, WRITE_MODE_ON     ; Turn on write mode
    jmp interpreted            ; Finish this character interpretation

add_to_top:                    ; Increase top value by the new hexdecimal number
    pop rax                    ; Get top value from the stack
    shl rax, 4                 ; Shift value by the base of hexdecimal numbers (16 = power(2, 4))
    add rax, rdi               ; Add current value to shifted previously top value
    push rax                   ; Insert the result to the top of the stack
    jmp interpreted            ; Finish this character interpretation

nop
sign_interprete:
    jiii rdi, '0', '9', strol16_num            ; Check if character if between '0' and '9', if so perform strol16_num
    jiii rdi, 'a', 'f', strol16_small          ; Check if character if between 'a' and 'b', if so perform strol16_small
    jiii rdi, 'A', 'F', strol16_big            ; Check if character if between 'A' and 'F', if so perform strol16_big

; Casing through previously explained signs
; If value from the calc equals to the sign, perform previously described operations 
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

    jmp interpreted            ; Character was not in the list of the recogniseable values, finish character interpretation

align 8
notec:                         ; uint64_t notec(uint32_t n, char const *calc)
    push rbx
    push r11
    push r12
    push r13
    push r14
    push rbp                   ; Prologue - Store values that might be changed on debug call
    mov rbp, rsp               ; Make a stack frame
    mov r12, rdi               ; Save value of the n
    mov r13, rsi               ; Copy pointer to the calc
    xor r14, r14               ; Counter to the pointer 
    mov rbx, WRITE_MODE_OFF    ; Set write mode to off at start
    mov rax, N                 ;
    mov [WAITS_FOR + r12 * 8], rax
notec_loop:
    lea rdi, [r13 + r14]       ; Get 8 bytes stored in pointer *calc
    movsx rdi, byte [rdi]      ; Get first value from calc
    cmp rdi, 0x00              ; Check if pointer points to end of the string
    je exit                    ; If so, notec has finished its work
    inc r14                    ; Increment calc counter pointing value
    jmp sign_interprete        ; Interprete recieved character
    nop
interpreted:                   ; Interpretation has finished
    jmp notec_loop             ; Go to the next caracter
exit:                          ; Epilogue, get value and finish the function call 
    pop rax                    ; Get value from the top of the stack
    mov rsp, rbp               ; Stack frame destruction
    pop rbp
    pop r14
    pop r13
    pop r12
    pop r11
    pop rbx                    ; Restoring required registers
    ret                        ; Finish the function call
