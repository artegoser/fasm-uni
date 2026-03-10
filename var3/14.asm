; Задание 14.
; Ввод байта с консоли в двоичном виде (8 символов '0'/'1').
; С проверкой корректности ввода.

use16
org 100h

    ; Вывод подсказки
    lea dx, [prompt]
    mov ah, 09h
    int 21h

    xor bl, bl          ; BL = результат (аккумулятор)
    mov cx, 8           ; 8 бит

.input_loop:
    ; Считать символ
    mov ah, 01h
    int 21h             ; AL = введённый символ

    cmp al, '0'
    jb .error
    cmp al, '1'
    ja .error

    ; Сдвигаем BL влево и добавляем бит
    shl bl, 1
    sub al, '0'         ; AL = 0 или 1
    or bl, al

    loop .input_loop

    ; Сохранить результат
    mov [result], bl

    ; Новая строка
    call print_newline

    ; Вывод сообщения об успехе
    lea dx, [msg_ok]
    mov ah, 09h
    int 21h

    ; Вывод результата в hex для проверки
    mov al, [result]
    call print_hex_byte

    jmp .exit

.error:
    call print_newline
    lea dx, [msg_err]
    mov ah, 09h
    int 21h

.exit:
    mov ax, 4C00h
    int 21h

; --- Вывод новой строки ---
print_newline:
    mov ah, 02h
    mov dl, 0Dh
    int 21h
    mov dl, 0Ah
    int 21h
    ret

; --- Вывод байта в hex ---
; Вход: AL = байт
print_hex_byte:
    push ax
    mov ah, 02h

    ; Старший ниббл
    push ax
    shr al, 4
    call .nibble
    pop ax

    ; Младший ниббл
    and al, 0Fh
    call .nibble

    mov dl, 'h'
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

; --- Данные ---
prompt  db 'Enter byte in binary (8 digits 0/1): $'
msg_ok  db 'Result (hex): $'
msg_err db 'Error: only 0 and 1 are allowed!$'
result  db 0
