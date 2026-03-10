; Задание 12.
; 2-3 массива слов без знака, разное количество элементов.
; Процедура вычисления среднего арифметического.
; Параметры: адрес массива (SI), количество элементов (CX).
; Возвращает: AX = среднее арифметическое.

use16
org 100h

    ; --- Среднее arr1 ---
    lea si, [arr1]
    xor cx, cx
    mov cx, [count1]
    call calc_avg
    mov [avg1], ax

    ; --- Среднее arr2 ---
    lea si, [arr2]
    mov cx, [count2]
    call calc_avg
    mov [avg2], ax

    ; --- Среднее arr3 ---
    lea si, [arr3]
    mov cx, [count3]
    call calc_avg
    mov [avg3], ax

    ; --- Завершение ---
    mov ax, 4C00h
    int 21h

; =============================================
; Процедура вычисления среднего арифметического
; Вход: SI = адрес массива, CX = количество элементов
; Выход: AX = среднее арифметическое
; =============================================
calc_avg:
    push bx
    push dx
    push si

    xor dx, dx          ; DX = 0 (старшая часть суммы)
    xor bx, bx          ; BX = 0 (младшая часть суммы / аккумулятор)
    mov bx, cx          ; Сохранить количество элементов

    xor ax, ax
    xor dx, dx
.sum_loop:
    add ax, [si]        ; Прибавить элемент
    adc dx, 0           ; Учесть перенос
    add si, 2
    loop .sum_loop

    ; DX:AX = сумма, BX = количество элементов
    div bx              ; AX = DX:AX / BX = среднее

    pop si
    pop dx
    pop bx
    ret

; --- Данные ---
arr1   dw 10, 20, 30
count1 dw 3

arr2   dw 100, 200, 300, 400, 500
count2 dw 5

arr3   dw 5, 15, 25, 35
count3 dw 4

avg1   dw 0              ; Среднее arr1
avg2   dw 0              ; Среднее arr2
avg3   dw 0              ; Среднее arr3
