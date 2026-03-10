; Задание 8. Вариант 3.
; Два массива слов, одинаковый размер (8-битная переменная).
; Сравнение элементов с помощью LOOPZ.
; Вывод строки о результате.

use16
org 100h

    xor cx, cx
    mov cl, [count]     ; CX = количество элементов
    lea si, [arr1]
    lea di, [arr2]

.cmp_loop:
    mov ax, [si]
    cmp ax, [di]        ; Сравниваем элементы (устанавливает ZF)
    lea si, [si+2]      ; Не меняет флаги (в отличие от add)
    lea di, [di+2]
    loopz .cmp_loop     ; Продолжать, пока ZF=1 и CX>0

    ; Если ZF=1 — все элементы совпали
    jz .equal

    ; Массивы не равны
    lea dx, [msg_neq]
    jmp .print

.equal:
    lea dx, [msg_eq]

.print:
    mov ah, 09h
    int 21h             ; Вывод строки

    mov ax, 4C00h
    int 21h

; --- Данные ---
count   db 5

arr1    dw 1, 2, 3, 4, 5
arr2    dw 1, 2, 3, 4, 5

msg_eq  db 'Arrays are equal$'
msg_neq db 'Arrays are NOT equal$'
