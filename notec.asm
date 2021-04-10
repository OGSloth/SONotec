; Notec - Assigment 2
; Marcin Gadomski - mg370790
global notec

DEFAULT REL                    ; Set as rel to allow use of shared memory 
extern debug                   ; int64_t debug(uint32_t n, uint64_t *stack_pointer)

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





section .bss
    alignb 4
    TOP_VAL: resq N            ; Stores top value for thread communication

section .data
    alignb 4
    WAITS_FOR: times N dq N    ; Stores information about for what n-th thread waits (N means that thread does not wait)
    SPIN_LOCKS: times N dq 1   ; Spin locks for thread top values exchange


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

; Get buffer macro
; Due to problems with Position Independent Executable (Could not find better soulution)
; Had to find way to ommit this error
; %1 - Pointer to the buffer
; %2 - Byte to get from the buffer
%macro gbuff 2
    mov rax, %1                ; Get pointer to the shared memory
    mov r11, %2                ; Get number on memory thread looks far
    shl r11, 3                 ; Converts number of bytes to bytes
    add rax, r11               ; Point to value looked for
%endmacro

add_op:                        ; Adding operation
    pop rax
    pop rdi                    ; Geting two top stack values
    add rax, rdi               ; Add first and second value
    push rax                   ; Put sum to the stack
    jmp interpreted            ; Finish this character interpretation

mul_op:                        ; Multiply operation
    pop rax
    pop rdi                    ; Geting two top stack values
    mul rdi                    ; Multiply first and second value
    push rax                   ; Put result to the stack
    jmp interpreted            ; Finish this character interpretation

art_neg_op:                    ; Artmethic negation operation
    pop rdi                    ; Geting value to aritmetical negation
    xor rax, rax               ; Put zero to the rax
    sub rax, rdi               ; Subtract value from 0 (Artmethic negation)
    push rax                   ; Put result to the stack
    jmp interpreted            ; Finish this character interpretation

and_op:                        ; And operation
    pop rax
    pop rdi
    and rax, rdi               ; Perform bitwise "and" operation on first and second value
    push rax                   ; Put result to the stack
    jmp interpreted            ; Finish this character interpretation

or_op:                         ; Or operation
    pop rax
    pop rdi                    ; Geting two top stack values
    or rax, rdi                ; Perform bitwise "or" operation on first and second value
    push rax                   ; Put result to the stack
    jmp interpreted            ; Finish this character interpretation

xor_op:                        ; Xor operation
    pop rax
    pop rdi                    ; Geting two top stack values
    xor rax, rdi               ; Perform xor operation of two top stack values
    push rax                   ; Put the result to the stack
    jmp interpreted            ; Finish this character interpretation

neg_op:                        ; Bitwise negation operation
    pop rax
    not rax                    ; Perform negation
    push rax                   ; Put the result to the stack
    jmp interpreted            ; Finish this character interpretation
    
remove_op:                     ; Remove value from the top of the stack operation
    pop rax                    ; If can be performed one_val_op jumps there
    jmp interpreted            ; As value was already pop to the rsi we can just jump further

dup_op:                        ; Duplicate value from the top of the stack operation
    pop rax
    push rax                   ; Restore value from the stack
    push rax                   ; Put duplicated value to the stack
    jmp interpreted            ; Finish this character interpretation

swap_op:                       ; Swap two top values from the stack
    pop rdi
    pop rsi
    push rdi                   ; Put previously top value to the stack
    push rsi                   ; Put previously second value as the top of the stack
    jmp interpreted            ; Finish this character interpretation

notec_push_op:                 ; Push compilation notec N value to the top of the stack
    push N                     ; Push the N value to the stack
    jmp interpreted            ; Finish this character interpretation

instance_push_op:              ; Push instance value number to the top of the stack
    push r12                   ; Push instance value number to the top of the stack
    jmp interpreted            ; Finish this character interpretation

call_debug_op:                 ; Set ups and calls provided debug functions
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

wait_op:                       ; Perform wait operation
    pop rdi
    pop rsi                    ; Get two first values from stack

    gbuff TOP_VAL, r12         ; Get pointer to shared memory top value buffer
    mov [rax], rsi             ; Set my top stack value for m-thread
    
    gbuff WAITS_FOR, r12       ; Get pointer to shared memory "what waits for what" buffer
    mov [rax], rdi             ; Inform m-thread that this thread waits for it

    nop
busy_wait:                     ; Waits for m-thread to wait for this thread
    gbuff WAITS_FOR, rdi       ; Get pointer to shared memory "what waits for what" buffer
    mov rsi, [rax]             ; Get for what m-thread waits

    cmp rsi, r12               ; Check if m-thread waits for this thread
    jne busy_wait              ; If not spin-lock and wait for it

    cmp r12, rdi               ; Check if n < m
    jl smaller_instance        ; If so perform task for smaller number thread
    
    jmp greater_instance

; Greater instance is ment to wait for smaller to get stack top value
; After smaller instance gets value, get value, clean up buffers
; Inform smaller instance, that stack top values exchange has finished
greater_instance:
spin_lock_greater:             ; Use spin lock waitting for smaller instance to finish work
    gbuff SPIN_LOCKS, r12      ; Get pointer to shared memory of spinlocks buffer
    mov     r9, 1              ; Put spinlock locking value
    xchg    r9, [rax]          ; If lock is open, close it
    test    r9, r9             ; Test for zero (Set zero flag)
    jnz     spin_lock_greater  ; If flag is not zero, keep waitting in spin lock

    gbuff TOP_VAL, rdi         ; Get pointer to m-th thread top stack value
    mov rsi, [rax]             ; Get value from address

    push rsi                   ; Put recieved value to this thread stack

    gbuff WAITS_FOR, r12       ; Get pointer to shared memory "what waits for what" buffer
    mov r9, N                  ; Put to register value - thread does not wait 
    mov [rax], r9              ; Set that thread finished waitting and does not wait no more

    gbuff WAITS_FOR, rdi       ; Get pointer to shared memory "what waits for what" buffer
    mov r9, N                  ; Put to register value - thread does not wait 
    mov [rax], r9              ; Set value for smaller instance

    gbuff SPIN_LOCKS, rdi      ; Get pointer to shared memory spin locks buffer
    xor r9, r9                 ; Set register to zero (Value unlocking spinlock)
    xchg r9, [rax]             ; Unlock smaller instance spinlock

    gbuff SPIN_LOCKS, r12      ; Get pointer to shared memory spin locks buffer
    mov r9, 1                  ; Set register to one (Value lock spinlock for this thread)
    mov [rax], r9              ; Lock spinlock (Cleaning up)

    jmp interpreted            ; Recieved value, cleaned, can coninue for next character

; Smaller instance at first get top stack value
; And waits for m-th thread to finish it's work
smaller_instance:
    gbuff TOP_VAL, rdi         ; Get pointer to m-th thread top stack value
    mov rsi, [rax]             ; Get value from address

    push rsi                   ; Put recieved value to this thread stack

    gbuff SPIN_LOCKS, rdi      ; Get pointer to shared memory spin locks buffer (For m-th value) 
    xor r9, r9                 ; Set register to zero (Value lock spinlock for this thread) 
    xchg r9, [rax]             ; Unlock m-th thread spinlock (Inform, that this thread recieved value)

spin_lock_smaller:
    gbuff SPIN_LOCKS, r12      ; Get pointer to shared memory of spinlocks buffer 
    mov     r9, 1              ; Put spinlock locking value
    xchg    r9, [rax]          ; If lock is open, close it                   
    test    r9, r9             ; Test for zero (Set zero flag)
    jnz     spin_lock_smaller  ; If flag is not zero, keep waitting in spin lock

    gbuff SPIN_LOCKS, r12      ; Get pointer to shared memory spin locks buffer
    mov r9, 1                  ; Set register to one (Value lock spinlock for this thread)
    xchg r9, [rax]             ; Lock spinlock (Cleaning up)

    jmp interpreted            ; Recieved value, cleaned, can coninue for next character
    

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
    mov rbx, WRITE_MODE_OFF                    ; This is not hexdecimal character, turn off write mode
    
; Casing through previously explained signs
; If value from the calc equals to the sign, perform previously described operations 
    cmp rdi, WRITE_EXIT_SIGN
    je interpreted             ; Only instruction that does not match this case, as write mode is already off
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

align 8                        ; As it is not main function, requires to be aligned to 8
notec:                         ; uint64_t notec(uint32_t n, char const *calc)
    push rbx
    push r12
    push r13
    push r14
    push rbp                   ; Prologue - Store values that might be changed on debug call
    mov rbp, rsp               ; Make a stack frame
    mov r12, rdi               ; Save value of the n
    mov r13, rsi               ; Copy pointer to the calc
    xor r14, r14               ; Counter to the pointer 
    mov rbx, WRITE_MODE_OFF    ; Set write mode to off at start
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
    pop rbx                    ; Restoring required registers
    ret                        ; Finish the function call
