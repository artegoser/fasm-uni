; Задание 21. MMX, вариант 3.
; Старшие 16 бит знаковых произведений элементов двух массивов.
; Скалярная и векторная реализации в одном самостоятельном модуле.
; ticks_scalar и ticks_mmx — время repetitions проходов в тактах TSC.
; Результаты доступны в памяти; замер не включает ввод/вывод.

use16
org 100h

    mov eax, 1
    cpuid
    and edx, (1 shl 23) or (1 shl 4)
    cmp edx, (1 shl 23) or (1 shl 4)
    jne unsupported
    finit

    mov di, multiply_scalar
    call measure
    mov dword [ticks_scalar], eax
    mov dword [ticks_scalar+4], edx
    mov di, multiply_mmx
    call measure
    mov dword [ticks_mmx], eax
    mov dword [ticks_mmx+4], edx

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
    mov ax, [array1+si]
    imul word [array2+si]   ; Полный знаковый результат DX:AX
    mov [result_scalar+si], dx
    add si, 2
    loop .element
.done:
    pop si
    pop cx
    ret

multiply_mmx:
    push cx
    push si
    mov cx, [count]
    shr cx, 2
    xor si, si
    jcxz .tail
.vector:
    movq mm0, qword [array1+si]
    pmulhw mm0, qword [array2+si]
    movq qword [result_mmx+si], mm0
    add si, 8
    loop .vector
.tail:
    mov cx, [count]
    and cx, 3
    jcxz .done
.element:
    mov ax, [array1+si]
    imul word [array2+si]   ; Полный знаковый результат DX:AX
    mov [result_mmx+si], dx
    add si, 2
    loop .element
.done:
    emms                   ; Освободить общий с FPU стек регистров
    pop si
    pop cx
    ret

count dw 19
repetitions dw 1000
array1 dw -32768, 32767, -32768, 32767, -1, 0, 1, 256, -256
       dw 1000, -1000, 12345, -12345, 30000, -30000, 7, -7, 20000, -20000
array2 dw -32768, 32767, 32767, -32768, 1, -32768, -1, 256, 256
       dw -1000, -1000, -23456, -23456, 30000, 30000, -7, -7, 20000, 20000
result_scalar dw 19 dup(0)
result_mmx    dw 19 dup(0)
ticks_scalar dq 0
ticks_mmx dq 0
tsc_start dq 0
error_message db 'MMX and TSC are required', '$'
