; Задание 3. Вариант 3.
; k = (a - b) / (a * c),  где c = (a * b) / (a + b)
; Все числа целые со знаком, 16-битные.

use16
org 100h

    ; --- Исходные данные ---
    mov ax, [a]         ; AX = a
    mov bx, [b]         ; BX = b

    ; --- Вычисление c = (a * b) / (a + b) ---
    ; Числитель: a * b
    imul bx             ; DX:AX = a * b
    mov cx, [a]
    add cx, [b]         ; CX = a + b
    idiv cx             ; AX = (a * b) / (a + b) = c
    mov [c], ax         ; Сохранить c

    ; --- Вычисление k = (a - b) / (a * c) ---
    ; Числитель: a - b
    mov ax, [a]
    sub ax, [b]         ; AX = a - b
    cwd                 ; Расширение знака AX -> DX:AX

    ; Знаменатель: a * c
    mov bx, [a]
    imul bx, [c]        ; BX = a * c

    idiv bx             ; AX = (a - b) / (a * c) = k
    mov [k], ax

    ; --- Завершение программы ---
    mov ax, 4C00h
    int 21h

; --- Данные ---
a  dw 12
b  dw 4
c  dw 0
k  dw 0
