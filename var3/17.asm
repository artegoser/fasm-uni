; Задание 17. Продолжение задания 16, вариант 3.
; CircleS(R) = 3.14 * R^2 для трёх кругов.
; Вещественный параметр R передаётся через стек по значению.
; Квадрат радиуса хранится в локальной переменной процедуры.

use16
org 100h

    finit

    push word [radius1+2]
    push word [radius1]
    call CircleS
    add sp, 4
    fstp dword [area1]

    push word [radius2+2]
    push word [radius2]
    call CircleS
    add sp, 4
    fstp dword [area2]

    push word [radius3+2]
    push word [radius3]
    call CircleS
    add sp, 4
    fstp dword [area3]

    mov ax, 4C00h
    int 21h

; [BP+4] = R (dword), результат — ST0.
; Стек параметров очищает вызывающий.
; [BP-4] = R^2 (локальный dword).
CircleS:
    push bp
    mov bp, sp
    sub sp, 4

    fld dword [bp+4]
    fmul st0, st0
    fstp dword [bp-4]       ; Сохранить R^2 в локальной переменной
    fld dword [bp-4]
    fmul dword [pi]

    mov sp, bp
    pop bp
    ret

pi      dd 3.14
radius1 dd 1.0
radius2 dd 2.5
radius3 dd 4.0
area1   dd 0.0             ; 3.14
area2   dd 0.0             ; 19.625
area3   dd 0.0             ; 50.24
