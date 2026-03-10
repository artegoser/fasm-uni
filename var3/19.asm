; Задание 19.
; Макрос для определения максимального значения.
; 3 операнда: dest, src1, src2
; Сравниваются src1 и src2, больший помещается в dest.
; (Числа со знаком)

use16
org 100h

; =============================================
; Макрос max3: dest = max(src1, src2)
; =============================================
macro max3 dest, src1, src2
{
    local .done
    push ax
    mov ax, src1
    cmp ax, src2
    jge .done               ; Если src1 >= src2 — уже в AX
    mov ax, src2
.done:
    mov dest, ax
    pop ax
}

    ; --- Примеры использования ---

    ; Пример 1: max(10, 20) -> 20
    max3 [result1], word [a], word [b]

    ; Пример 2: max(-5, 3) -> 3
    max3 [result2], word [c], word [d]

    ; Пример 3: max(-100, -50) -> -50
    max3 [result3], word [e], word [f]

    ; --- Завершение ---
    mov ax, 4C00h
    int 21h

; --- Данные ---
a  dw 10
b  dw 20
c  dw -5
d  dw 3
e  dw -100
f  dw -50

result1 dw 0
result2 dw 0
result3 dw 0
