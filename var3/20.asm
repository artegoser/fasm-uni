; Задание 20. FPU, вариант 3.
; F(x) = (2^(1/x-1) - sin(x-1)) * (3-x) /
;        (cos^2(1-x) + log2(2+abs(1-x))). Интервал [1, 3].
; 10 точек, включая границы; ОДЗ: x <> 0 (знаменатель >= 1).
; Аргументы и результаты — single precision, вывод — 7 значащих цифр.

use16
org 100h

    finit
    fld dword [x2]
    fsub dword [x1]
    fidiv word [intervals]
    fstp qword [step]
    xor si, si
    xor di, di
    mov cx, 10

.point:
    cmp di, 9
    je .last
    mov [index], di
    fld qword [step]
    fimul word [index]
    fadd dword [x1]
    jmp .save_x
.last:
    fld dword [x2]          ; Последняя точка — точно правая граница
.save_x:
    fstp dword [xs+si]
    fld dword [xs+si]
    call print_real
    mov dx, separator
    mov ah, 09h
    int 21h

    fld dword [xs+si]
    ftst
    fstsw ax
    sahf
    fstp st0
    je .domain_error       ; Нуль или NaN

    ; 2^z = (1 + (2^(z-round(z))-1)) * 2^round(z), z = 1/x-1.
    ; Аргумент F2XM1 находится в [-0.5, 0.5].
    fld1
    fdiv dword [xs+si]
    fsub dword [one]
    fld st0
    frndint
    fxch st1
    fsub st0, st1
    f2xm1
    fld1
    faddp st1, st0
    fscale
    fstp st1

    fld dword [xs+si]
    fsub dword [one]
    fld st0
    fsincos                ; cos(x-1), sin(x-1), x-1, 2^z
    fmul st0, st0
    fxch st1
    fsubp st3, st0         ; cos²(x-1), x-1, 2^z-sin(x-1)
    fxch st1
    fabs
    fadd dword [two]
    fld1
    fxch st1
    fyl2x
    faddp st1, st0          ; Знаменатель
    fdivp st1, st0
    fld dword [three]
    fsub dword [xs+si]
    fmulp st1, st0
    fstp dword [results+si]
    mov byte [valid+di], 1
    fld dword [results+si]
    call print_real
    jmp .next

.domain_error:
    mov byte [valid+di], 0
    mov dword [results+si], 0
    mov dx, domain_message
    mov ah, 09h
    int 21h

.next:
    mov dx, newline
    mov ah, 09h
    int 21h
    add si, 4
    inc di
    dec cx
    jnz .point

    mov ax, 4C00h
    int 21h

; ST0 -> десятичная научная запись. ST0 извлекается, регистры сохраняются.
; Вход — конечное single precision число. Стек FPU на выходе пуст.
print_real:
    pushad
    xor bx, bx             ; Десятичный порядок
    ftst
    fstsw ax
    sahf
    ja .normalize
    je .zero
    fabs
    mov dl, '-'
    mov ah, 02h
    int 21h

.normalize:
    fcom dword [ten]
    fstsw ax
    sahf
    jb .small
    fdiv dword [ten]
    inc bx
    jmp .normalize
.small:
    fcom dword [one]
    fstsw ax
    sahf
    jae .convert
    fmul dword [ten]
    dec bx
    jmp .small
.zero:
    ; Нуль не требует нормализации.
.convert:
    fimul dword [million]
    fbstp tbyte [mantissa]  ; Каждая полутетрада содержит десятичную цифру
    mov eax, dword [mantissa]
    cmp eax, 10000000h
    jne .digits
    mov eax, 01000000h
    inc bx                 ; Округление 9.9999995 -> 1.000000e+1
.digits:
    mov di, number_buffer+7
    mov cx, 6
.digit:
    mov dl, al
    and dl, 0Fh
    add dl, '0'
    mov [di], dl
    dec di
    shr eax, 4
    loop .digit
    add al, '0'
    mov [number_buffer], al

    mov al, bl             ; Порядок single precision не превышает двух цифр
    mov dl, '+'
    test al, al
    jns .exponent
    mov dl, '-'
    neg al
.exponent:
    mov [exponent_sign], dl
    aam                    ; AH = десятки, AL = единицы
    test ah, ah
    jz .one_digit
    add ax, 3030h
    xchg al, ah
    mov word [exponent_digits], ax
    jmp .print
.one_digit:
    add al, '0'
    mov ah, '$'
    mov word [exponent_digits], ax
.print:
    mov dx, number_buffer
    mov ah, 09h
    int 21h
    popad
    ret

x1       dd 1.0
x2       dd 3.0
xs       dd 10 dup(0.0)
results  dd 10 dup(0.0)
valid    db 10 dup(0)
step     dq 0.0
index    dw 0
intervals dw 9
one      dd 1.0
two      dd 2.0
three    dd 3.0
ten      dd 10.0
million  dd 1000000
mantissa dt 0.0
number_buffer db '0.000000e'
exponent_sign db '+'
exponent_digits db '00$'
separator db '  ', '$'
newline db 13, 10, '$'
; «Значение аргумента не входит в ОДЗ» в кодировке DOS CP866.
domain_message db 087h, 0ADh, 0A0h, 0E7h, 0A5h, 0ADh, 0A8h, 0A5h, 20h
               db 0A0h, 0E0h, 0A3h, 0E3h, 0ACh, 0A5h, 0ADh, 0E2h, 0A0h, 20h
               db 0ADh, 0A5h, 20h, 0A2h, 0E5h, 0AEh, 0A4h, 0A8h, 0E2h, 20h
               db 0A2h, 20h, 08Eh, 084h, 087h, '$'
