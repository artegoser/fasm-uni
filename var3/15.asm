; Задание 15.
; Вычислить сумму значений флагов CF, SF, ZF.
; Вывести результат на консоль.
; Если результат > 1, инвертировать CF.

use16
org 100h

    ; Выполним операцию, чтобы установить флаги
    mov ax, 0FFFFh
    add ax, 1           ; AX = 0, CF=1, ZF=1, SF=0

    ; Сразу сохраняем флаги, т.к. любые последующие команды их изменят
    pushf               ; Сохранить FLAGS в стек
    pop dx              ; DX = FLAGS

    xor bx, bx          ; BX = сумма

    ; CF — бит 0
    test dx, 0001h
    jz .no_cf
    inc bx
.no_cf:

    ; ZF — бит 6
    test dx, 0040h
    jz .no_zf
    inc bx
.no_zf:

    ; SF — бит 7
    test dx, 0080h
    jz .no_sf
    inc bx
.no_sf:

    ; BX = сумма флагов
    ; Вывод: "Sum of CF+ZF+SF = X"
    lea si, [msg]
    mov ah, 09h
    mov dx, si
    int 21h

    ; Вывод числа (0..3)
    mov dl, bl
    add dl, '0'
    mov ah, 02h
    int 21h

    ; Новая строка
    mov ah, 02h
    mov dl, 0Dh
    int 21h
    mov dl, 0Ah
    int 21h

    ; Если сумма > 1, инвертировать CF
    cmp bx, 1
    jbe .skip_cmc
    cmc                  ; Инвертировать CF

    lea dx, [msg_cmc]
    mov ah, 09h
    int 21h
.skip_cmc:

    mov ax, 4C00h
    int 21h

; --- Данные ---
msg     db 'Sum of CF+ZF+SF = $'
msg_cmc db 'CF was inverted (CMC)$'
