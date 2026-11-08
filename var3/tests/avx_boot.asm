; Test fixture only: boot a supplied COM at 1000h:0100h and capture its
; INT 21h exit, register state and result bytes through QEMU's debug port.
; PROGRAM, RESULT and RESULT_SIZE are supplied by verify.py via fasm -d.

use16
org 7C00h

    jmp 0:start
start:
    cli
    xor ax, ax
    mov ss, ax
    mov sp, 7C00h
    mov ds, ax
    mov word [21h*4], dos_interrupt
    mov word [21h*4+2], 0

    mov ax, 1000h
    mov es, ax
    mov bx, 100h
    mov ax, 0200h + (program_end-program+511)/512
    mov cx, 2
    xor dh, dh             ; DL retains the BIOS boot drive
    int 13h
    jc disk_error
    cli
    mov ax, 1000h
    mov ss, ax
    mov sp, 0FFFEh
    mov ds, ax
    mov es, ax
    mov bp, 5678h
    db 66h
    lgdt pword [cs:initial_gdtr]
    db 66h
    sgdt pword [cs:gdtr_before]
    sti
    jmp 1000h:100h

macro emit_word value
{
    mov ax, value
    out 0E9h, al
    mov al, ah
    out 0E9h, al
}

macro emit_dword value
{
    mov eax, value
    repeat 4
        out 0E9h, al
        shr eax, 8
    end repeat
}

dos_interrupt:
    cmp ah, 09h
    je .ignore_output
    cmp ah, 4Ch
    jne disk_error
    out 0E9h, al           ; DOS exit code
    mov bx, sp
    emit_word ss
    emit_word ds
    emit_word es
    emit_word [ss:bx+2]    ; Return CS
    lea ax, [bx+6]
    emit_word ax           ; SP before INT
    emit_word bp
    emit_word [ss:bx+4]    ; FLAGS before INT
    emit_dword cr0
    emit_dword cr4
    db 66h
    sgdt pword [cs:gdtr_after]
    mov si, gdtr_before
    mov cx, 12
.tables:
    mov al, [cs:si]
    out 0E9h, al
    inc si
    loop .tables
    mov si, RESULT
    mov cx, RESULT_SIZE
.result:
    mov al, [si]
    out 0E9h, al
    inc si
    loop .result
    mov al, 10h
    out 0F4h, al
    hlt
.ignore_output:
    iret

disk_error:
    mov al, 0EEh
    out 0E9h, al
    out 0F4h, al
    hlt

gdtr_before dw 0
            dd 0
gdtr_after dw 0
           dd 0
initial_gdtr dw 123h
             dd 12345678h ; Also detect accidental truncation to a 24-bit base
times 510-($-$$) db 0
dw 0AA55h
program:
file PROGRAM
program_end:
