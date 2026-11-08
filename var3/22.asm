; Задание 22. SSE, вариант 3.
; Поэлементное умножение массивов single precision.
; Скалярная и векторная реализации в одном самостоятельном модуле.
; ticks_scalar и ticks_sse — время repetitions проходов в тактах TSC.
; Результаты доступны в памяти; замер не включает ввод/вывод.

use16
org 100h

    ; Управляющие регистры доступны в настоящем real-mode DOS.
    smsw ax
    test ax, 1
    jnz unsupported
    mov eax, 1
    cpuid
    and edx, (1 shl 25) or (1 shl 4)
    cmp edx, (1 shl 25) or (1 shl 4)
    jne unsupported
    mov eax, cr0
    mov [saved_cr0], eax
    and eax, not ((1 shl 2) or (1 shl 3)) ; EM=0, TS=0
    or eax, 1 shl 1                    ; MP
    mov cr0, eax
    mov eax, cr4
    mov [saved_cr4], eax
    or eax, 1 shl 9                    ; OSFXSR: разрешить SSE
    mov cr4, eax
    finit
    ldmxcsr [mxcsr_default]

    mov di, multiply_scalar
    call measure
    mov dword [ticks_scalar], eax
    mov dword [ticks_scalar+4], edx
    mov di, multiply_sse
    call measure
    mov dword [ticks_sse], eax
    mov dword [ticks_sse+4], edx

    mov eax, [saved_cr4]
    mov cr4, eax
    mov eax, [saved_cr0]
    mov cr0, eax
    mov ax, 4C00h
    int 21h

unsupported:
    mov dx, error_message
    mov ah, 09h
    int 21h
    mov ax, 4C01h
    int 21h

; DI = процедура. EDX:EAX = время repetitions вызовов в тактах TSC.
; CPUID сериализует выполнение перед чтением TSC с обеих сторон.
measure:
    push ebx
    push ecx
    push esi
    xor eax, eax
    cpuid
    rdtsc
    mov dword [tsc_start], eax
    mov dword [tsc_start+4], edx
    mov cx, [repetitions]
    jcxz .stop
.repeat:
    call di
    loop .repeat
.stop:
    xor eax, eax
    cpuid
    rdtsc
    sub eax, dword [tsc_start]
    sbb edx, dword [tsc_start+4]
    pop esi
    pop ecx
    pop ebx
    ret

multiply_scalar:
    push cx
    push si
    mov cx, [count]
    xor si, si
    jcxz .done
.element:
    fld dword [array1+si]
    fmul dword [array2+si]
    fstp dword [result_scalar+si]
    add si, 4
    loop .element
.done:
    pop si
    pop cx
    ret

multiply_sse:
    push cx
    push si
    mov cx, [count]
    shr cx, 2
    xor si, si
    jcxz .tail
.vector:
    movups xmm0, dqword [array1+si]
    movups xmm1, dqword [array2+si]
    mulps xmm0, xmm1
    movups dqword [result_sse+si], xmm0
    add si, 16
    loop .vector
.tail:
    mov cx, [count]
    and cx, 3
    jcxz .done
.element:
    fld dword [array1+si]
    fmul dword [array2+si]
    fstp dword [result_sse+si]
    add si, 4
    loop .element
.done:
    pop si
    pop cx
    ret

count dw 19
repetitions dw 1000
array1 dd 1.5, -2.5, 0.0, 4.0, -5.25, 6.5, 7.0, -8.0, 0.125
       dd -0.5, 10.0, 12.25, -13.5, 14.0, 15.75, -16.0, 17.5, 18.0, -19.25
array2 dd 2.0, 3.0, -4.0, -0.5, 1.25, -2.0, 0.25, 8.0, -0.125
       dd 0.5, -10.0, 2.0, 3.5, -4.0, 0.5, 16.0, -1.5, 0.25, 4.0
result_scalar dd 19 dup(0.0)
result_sse    dd 19 dup(0.0)
ticks_scalar dq 0
ticks_sse dq 0
tsc_start dq 0
saved_cr0 dd 0
saved_cr4 dd 0
mxcsr_default dd 1F80h     ; Округление к ближайшему, без FTZ/DAZ
error_message db 'SSE and TSC in real-mode DOS are required', '$'
