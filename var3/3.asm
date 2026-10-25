; Задание 3. Вариант 3.
; k = (a - b) / (a * c),  где c = (a * b) / (a + b)
; Все переменные целые со знаком, 16-битные.
; Промежуточные вычисления — 32-битные, чтобы не терять старшие биты.
; Нулевой делитель или непредставимый результат: код завершения 1.

use16
org 100h

    ; --- Вычисление c = (a * b) / (a + b) ---
    movsx eax, [a]
    movsx ebx, [b]
    mov ecx, eax
    add ecx, ebx        ; a + b может не помещаться в слово
    jz .error
    imul eax, ebx       ; EAX = a * b
    cdq
    idiv ecx
    cmp eax, -32768
    jl .error
    cmp eax, 32767
    jg .error
    mov [c], ax         ; Сохранить c

    ; --- Вычисление k = (a - b) / (a * c) ---
    movsx ecx, [a]
    imul ecx, eax       ; ECX = a * c (полный 32-битный результат)
    jecxz .error
    movsx eax, [a]
    sub eax, ebx        ; EAX = a - b
    cdq
    idiv ecx
    cmp eax, -32768
    jl .error
    cmp eax, 32767
    jg .error
    mov [k], ax

    ; --- Завершение программы ---
    mov ax, 4C00h
    int 21h

.error:
    mov ax, 4C01h
    int 21h

; --- Данные ---
a  dw 12
b  dw 4
c  dw 0
k  dw 0
