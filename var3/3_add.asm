; Задание 3. Дополнительное упражнение.
; Умножение двух 32-битных целых без знака -> 64-битный результат.
; num1 = num1_hi:num1_lo,  num2 = num2_hi:num2_lo
;
; Метод «столбиком»:
;   num1_lo * num2_lo             -> part0 (32 бита, позиция 0)
;   num1_lo * num2_hi             -> part1 (32 бита, позиция 16)
;   num1_hi * num2_lo             -> part2 (32 бита, позиция 16)
;   num1_hi * num2_hi             -> part3 (32 бита, позиция 32)
;
; Результат складывается со сдвигами в 64-битное число res (4 слова).

use16
org 100h

    ; --- num1_lo * num2_lo ---
    mov ax, [num1_lo]
    mul word [num2_lo]      ; DX:AX = num1_lo * num2_lo
    mov [res],   ax         ; res[0] = младшее слово
    mov [res+2], dx         ; res[1] = старшее слово (будем прибавлять)
    mov word [res+4], 0
    mov word [res+6], 0

    ; --- num1_lo * num2_hi ---
    mov ax, [num1_lo]
    mul word [num2_hi]      ; DX:AX = num1_lo * num2_hi
    add [res+2], ax
    adc [res+4], dx
    adc word [res+6], 0

    ; --- num1_hi * num2_lo ---
    mov ax, [num1_hi]
    mul word [num2_lo]      ; DX:AX = num1_hi * num2_lo
    add [res+2], ax
    adc [res+4], dx
    adc word [res+6], 0

    ; --- num1_hi * num2_hi ---
    mov ax, [num1_hi]
    mul word [num2_hi]      ; DX:AX = num1_hi * num2_hi
    add [res+4], ax
    adc [res+6], dx

    ; --- Завершение ---
    mov ax, 4C00h
    int 21h

; --- Данные ---
; num1 = 0x00030005 = 196613
; num2 = 0x00020003 = 131075
; Результат = 196613 * 131075 = 25,777,134,575 = 0x000000060019000F
num1_lo dw 0005h
num1_hi dw 0003h
num2_lo dw 0003h
num2_hi dw 0002h
res     dw 0, 0, 0, 0      ; 64-битный результат (4 слова)
