; Задание 23. AVX, вариант 3.
; Поэлементное умножение single precision массивов, 8 чисел за команду.
; COM-программа, весь код use16. AVX требует protected mode: на время
; вычислений включается 16-битный защищённый режим, затем возврат в DOS.
; Запуск — в настоящем real-mode DOS, без EMM386/virtual-8086.
; Массив результатов — result_avx; ввод/вывод для этого задания не требуется.

use16
org 100h

    smsw ax
    test ax, 1
    jnz unsupported
    mov eax, 1
    cpuid
    and ecx, (1 shl 26) or (1 shl 28) ; XSAVE и AVX
    cmp ecx, (1 shl 26) or (1 shl 28)
    jne unsupported

    ; Дескрипторы с теми же базами и лимитами, что у сегментов COM.
    xor eax, eax
    mov ax, cs
    mov [real_address+2], ax
    shl eax, 4
    mov [gdt_code+2], ax
    shr eax, 16
    mov byte [gdt_code+4], al

    xor eax, eax
    mov ax, ds
    mov [saved_ds], ax
    shl eax, 4
    mov [gdt_data+2], ax
    mov edx, eax
    shr eax, 16
    mov byte [gdt_data+4], al
    add edx, gdt
    mov dword [gdtr+2], edx
    mov ax, es
    mov [saved_es], ax

    xor eax, eax
    mov ax, ss
    mov [saved_ss], ax
    shl eax, 4
    mov [gdt_stack+2], ax
    shr eax, 16
    mov byte [gdt_stack+4], al

    pushf
    cli                    ; В защищённом режиме нет вызовов BIOS/DOS
    db 66h                 ; Сохранить все 32 бита базы GDTR
    sgdt pword [saved_gdtr]
    mov eax, cr0
    mov [saved_cr0], eax
    and eax, not ((1 shl 2) or (1 shl 3)) ; EM=0, TS=0
    or eax, 1 shl 1
    mov cr0, eax
    mov eax, cr4
    mov [saved_cr4], eax
    or eax, (1 shl 9) or (1 shl 18) ; OSFXSR и OSXSAVE
    mov cr4, eax
    xor ecx, ecx
    xgetbv
    mov dword [saved_xcr0], eax
    mov dword [saved_xcr0+4], edx
    or eax, 7              ; Разрешить x87, XMM и YMM
    xsetbv

    lgdt pword [gdtr]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 8:protected_mode

protected_mode:
    mov ax, 16
    mov ds, ax
    mov es, ax
    mov ax, 24
    mov ss, ax
    vldmxcsr [mxcsr_default]

    mov cx, [count]
    shr cx, 3
    xor si, si
    jcxz .tail
.vector:
    vmovups ymm0, qqword [array1+si]
    vmulps ymm0, ymm0, qqword [array2+si]
    vmovups qqword [result_avx+si], ymm0
    add si, 32
    loop .vector
.tail:
    mov cx, [count]
    and cx, 7
    jcxz .done
.element:
    vmovss xmm0, [array1+si]
    vmulss xmm0, xmm0, [array2+si]
    vmovss [result_avx+si], xmm0
    add si, 4
    loop .element
.done:
    vzeroupper
    xor ecx, ecx
    mov eax, dword [saved_xcr0]
    mov edx, dword [saved_xcr0+4]
    xsetbv
    mov eax, [saved_cr4]
    mov cr4, eax
    mov eax, [saved_cr0]
    mov cr0, eax
    jmp far dword [real_address]

real_mode:
    mov ax, [cs:saved_ds]
    mov ds, ax
    mov ax, [saved_es]
    mov es, ax
    mov ax, [saved_ss]
    mov ss, ax
    db 66h                 ; Восстановить все 32 бита базы GDTR
    lgdt pword [saved_gdtr]
    popf
    mov ax, 4C00h
    int 21h

unsupported:
    mov dx, error_message
    mov ah, 09h
    int 21h
    mov ax, 4C01h
    int 21h

count dw 19
array1 dd 1.5, -2.5, 0.0, 4.0, -5.25, 6.5, 7.0, -8.0, 0.125
       dd -0.5, 10.0, 12.25, -13.5, 14.0, 15.75, -16.0, 17.5, 18.0, -19.25
array2 dd 2.0, 3.0, -4.0, -0.5, 1.25, -2.0, 0.25, 8.0, -0.125
       dd 0.5, -10.0, 2.0, 3.5, -4.0, 0.5, 16.0, -1.5, 0.25, 4.0
result_avx dd 19 dup(0.0)
mxcsr_default dd 1F80h
saved_cr0 dd 0
saved_cr4 dd 0
saved_xcr0 dq 0
saved_ds dw 0
saved_es dw 0
saved_ss dw 0
real_address dw real_mode, 0
saved_gdtr dw 0
           dd 0
gdtr dw gdt_end-gdt-1
     dd 0
gdt:
    dq 0
gdt_code:
    dw 0FFFFh, 0
    db 0, 09Ah, 0, 0       ; 16-битный сегмент кода, D=0
gdt_data:
    dw 0FFFFh, 0
    db 0, 092h, 0, 0
gdt_stack:
    dw 0FFFFh, 0
    db 0, 092h, 0, 0       ; 16-битный стек, B=0
gdt_end:
error_message db 'AVX, XSAVE and real-mode DOS are required', '$'
