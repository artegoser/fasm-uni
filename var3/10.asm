; Задание 10. Вариант 3 (N=3, N\4=0).
; Строка >8 символов. Шифрование:
;   1-й символ: ROL на N\4=0 (без изменения)
;   2-й символ: ROR на 0
;   3-й символ: ROL на 1
;   4-й символ: ROR на 1
;   5-й символ: ROL на 2
;   ... и т.д.
; Затем расшифровка (обратные сдвиги) и вывод.

use16
org 100h

    ; --- Вывод исходной строки ---
    lea dx, [str_orig_msg]
    mov ah, 09h
    int 21h
    lea dx, [mystr]
    mov ah, 09h
    int 21h
    call print_newline

    ; --- Шифрование ---
    lea si, [mystr]
    xor bx, bx          ; BX = индекс
    mov dl, 0            ; DL = текущий сдвиг (N\4 = 0)

.enc_loop:
    xor cx, cx
    mov cl, [len]
    cmp bx, cx
    jae .enc_done

    mov al, [si]
    mov cl, dl           ; CL = количество бит

    test bx, 1
    jnz .enc_ror

    ; Чётный индекс -> ROL
    rol al, cl
    jmp .enc_store

.enc_ror:
    ; Нечётный индекс -> ROR
    ror al, cl

.enc_store:
    mov [si], al
    inc si
    inc bx

    ; Увеличивать сдвиг каждые 2 символа
    test bx, 1
    jnz .enc_no_inc
    inc dl
.enc_no_inc:
    jmp .enc_loop

.enc_done:

    ; --- Вывод зашифрованной строки ---
    lea dx, [str_enc_msg]
    mov ah, 09h
    int 21h
    lea dx, [mystr]
    xor cx, cx
    mov cl, [len]
    mov bx, 1           ; Стандартный вывод
    mov ah, 40h         ; Вывод по длине: шифротекст может содержать '$'
    int 21h
    call print_newline

    ; --- Расшифровка (обратные операции) ---
    lea si, [mystr]
    xor bx, bx
    mov dl, 0            ; Сброс сдвига

.dec_loop:
    xor cx, cx
    mov cl, [len]
    cmp bx, cx
    jae .dec_done

    mov al, [si]
    mov cl, dl

    test bx, 1
    jnz .dec_rol

    ; Чётный индекс: при шифровании ROL -> расшифровка ROR
    ror al, cl
    jmp .dec_store

.dec_rol:
    ; Нечётный индекс: при шифровании ROR -> расшифровка ROL
    rol al, cl

.dec_store:
    mov [si], al
    inc si
    inc bx

    test bx, 1
    jnz .dec_no_inc
    inc dl
.dec_no_inc:
    jmp .dec_loop

.dec_done:

    ; --- Вывод расшифрованной строки ---
    lea dx, [str_dec_msg]
    mov ah, 09h
    int 21h
    lea dx, [mystr]
    mov ah, 09h
    int 21h

    ; --- Завершение ---
    mov ax, 4C00h
    int 21h

; --- Процедура вывода новой строки ---
print_newline:
    mov ah, 02h
    mov dl, 0Dh
    int 21h
    mov dl, 0Ah
    int 21h
    ret

; --- Данные ---
mystr         db 'Hello World!$'
len           db 12               ; Длина строки без '$'

str_orig_msg  db 'Original: $'
str_enc_msg   db 'Encrypted: $'
str_dec_msg   db 'Decrypted: $'
