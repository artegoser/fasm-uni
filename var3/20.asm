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
    mov [index], di
    fld qword [step]
    fimul word [index]
    fadd dword [x1]
    cmp di, 9
    jne .save_x
    fstp st0
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
    je .domain_error
    jp .domain_error

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
    fsin
    fsubp st1, st0          ; Числитель без множителя (3-x)

    fld1
    fsub dword [xs+si]
    fcos
    fmul st0, st0
    fld1
    fsub dword [xs+si]
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
    fistp dword [mantissa]
    cmp dword [mantissa], 10000000
    jne .digits
    mov dword [mantissa], 1000000
    inc bx                 ; Округление 9.9999995 -> 1.000000e+1
.digits:
    push bx
    mov eax, [mantissa]
    mov ebx, 1000000
    mov di, number_buffer
    mov cx, 7
.digit:
    xor edx, edx
    div ebx
    add al, '0'
    mov [di], al
    inc di
    cmp cx, 7
    jne .fraction
    inc di                 ; Пропустить десятичную точку
.fraction:
    mov esi, edx
    mov eax, ebx
    xor edx, edx
    mov ebx, 10
    div ebx
    mov ebx, eax
    mov eax, esi
    loop .digit
    mov dx, number_buffer
    mov ah, 09h
    int 21h
    pop ax                 ; Порядок
    mov dl, '+'
    test ax, ax
    jns .exponent
    mov dl, '-'
    neg ax
.exponent:
    push ax
    mov ah, 02h
    int 21h
    pop ax

    ; Как в задании 13: цифры целого через деление и стек.
    xor cx, cx
    mov bx, 10
.divide:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .divide
.print_digit:
    pop dx
    add dl, '0'
    mov ah, 02h
    int 21h
    loop .print_digit
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
mantissa dd 0
number_buffer db '0.000000e$'
separator db '  ', '$'
newline db 13, 10, '$'
; «Значение аргумента не входит в ОДЗ» в кодировке DOS CP866.
domain_message db 087h, 0ADh, 0A0h, 0E7h, 0A5h, 0ADh, 0A8h, 0A5h, 20h
               db 0A0h, 0E0h, 0A3h, 0E3h, 0ACh, 0A5h, 0ADh, 0E2h, 0A0h, 20h
               db 0ADh, 0A5h, 20h, 0A2h, 0E5h, 0AEh, 0A4h, 0A8h, 0E2h, 20h
               db 0A2h, 20h, 08Eh, 084h, 087h, '$'
