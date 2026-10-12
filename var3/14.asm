use16
org 100h

start:
    mov dx, prompt
    mov ah, 09h
    int 21h

    mov dx, input_buffer
    mov ah, 0Ah
    int 21h

    cmp byte [input_buffer+1], 8
    jne .error

    lea si, [input_buffer+2]
    xor bl, bl
    mov cx, 8

.input_loop:
    mov al, [si]
    cmp al, '0'
    jb .error
    cmp al, '1'
    ja .error

    shl bl, 1
    sub al, '0'
    or bl, al

    inc si
    loop .input_loop

    mov [result], bl

    mov dx, msg_ok
    mov ah, 09h
    int 21h

    mov al, [result]
    call print_hex_byte
    jmp .exit

.error:
    mov dx, msg_err
    mov ah, 09h
    int 21h

.exit:
    mov ax, 4C00h
    int 21h

print_hex_byte:
    push ax
    push ax
    shr al, 4
    call .nibble
    pop ax

    and al, 0Fh
    call .nibble

    mov dl, 'h'
    mov ah, 02h
    int 21h

    pop ax
    ret

.nibble:
    cmp al, 10
    jb .digit
    add al, 'A' - 10
    jmp .out
.digit:
    add al, '0'
.out:
    mov dl, al
    mov ah, 02h
    int 21h
    ret

prompt       db 'Enter byte in binary (8 digits 0/1): $'
msg_ok       db 'Result (hex): $'
msg_err      db 'Error: enter exactly 8 binary digits!$'
result       db 0
input_buffer db 10, 0
             rb 10
