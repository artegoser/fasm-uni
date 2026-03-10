; Задание 13.
; Вывод массива слов со знаком в десятичном виде через запятую.

use16
org 100h

    lea si, [arr]
    mov cx, [count]

.print_loop:
    push cx
    mov ax, [si]
    call print_signed_word
    add si, 2

    pop cx
    dec cx
    jz .done

    ; Печать ", "
    mov ah, 02h
    mov dl, ','
    int 21h
    mov dl, ' '
    int 21h

    jmp .print_loop

.done:
    ; Новая строка
    mov ah, 02h
    mov dl, 0Dh
    int 21h
    mov dl, 0Ah
    int 21h

    mov ax, 4C00h
    int 21h

; =============================================
; Процедура вывода знакового слова в десятичном виде
; Вход: AX = число со знаком
; =============================================
print_signed_word:
    push ax
    push bx
    push cx
    push dx

    ; Проверяем знак
    test ax, ax
    jns .positive

    ; Отрицательное число — выводим '-'
    push ax
    mov ah, 02h
    mov dl, '-'
    int 21h
    pop ax
    neg ax              ; Делаем положительным

.positive:
    ; Преобразуем число в цифры (от младшей к старшей)
    xor cx, cx          ; Счётчик цифр
    mov bx, 10

.div_loop:
    xor dx, dx
    div bx              ; AX = AX / 10, DX = остаток
    push dx             ; Сохраняем цифру в стек
    inc cx
    test ax, ax
    jnz .div_loop

    ; Выводим цифры (из стека — в правильном порядке)
.print_digits:
    pop dx
    add dl, '0'
    mov ah, 02h
    int 21h
    loop .print_digits

    pop dx
    pop cx
    pop bx
    pop ax
    ret

; --- Данные ---
arr   dw -128, 0, 255, -32768, 1234, -1
count dw 6
