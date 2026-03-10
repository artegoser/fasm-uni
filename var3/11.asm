; Задание 11.
; Строка "$!olleH". Перевернуть с использованием стека.
; Вывести результат: "Hello!$"

use16
org 100h

    ; Определяем длину строки (6 символов, включая '$' и '!')
    lea si, [mystr]
    xor cx, cx
    mov cl, [len]       ; CX = длина строки

    ; --- Помещаем каждый символ в стек ---
    lea si, [mystr]
    mov bx, cx          ; Сохраняем длину
.push_loop:
    xor ax, ax
    mov al, [si]
    push ax             ; Помещаем символ в стек
    inc si
    loop .push_loop

    ; --- Извлекаем из стека в обратном порядке ---
    lea di, [result]
    mov cx, bx          ; Восстанавливаем длину
.pop_loop:
    pop ax
    mov [di], al        ; Сохраняем символ
    inc di
    loop .pop_loop

    ; Строка result теперь "Hello!$" — '$' оказался в конце (терминатор DOS)

    ; --- Вывод результата ---
    lea dx, [result]
    mov ah, 09h
    int 21h

    ; --- Завершение ---
    mov ax, 4C00h
    int 21h

; --- Данные ---
mystr   db '$!olleH'
len     db 7               ; Длина строки
result  db 8 dup(0)        ; Буфер для результата
