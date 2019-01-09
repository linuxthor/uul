BITS 64
osabi 0x09               ; FreeBSD 

global _start
_start:
    mov  rax, 12        ; Haiku create_sem / BSD chdir / Linux brk 
    mov  rdi, tmp
    mov  rsi, tmp
    syscall

    cmp  rax, 0xffff
    jl   maybe_haiku

linux:
    mov  rax, 1          ; Linux sys_write
    mov  rdi, 1
    mov  rsi, linz
    mov  rdx, lbyte
    syscall

    mov  rax, 60         ; Linux sys_exit
    mov  rdi, 42
    syscall

maybe_haiku:
    cmp  rax, 1
    jl   bors

haiku:
    ;
    ; Haiku code
    ;
    mov  rax, 144         ; Haiku
    mov  rdi, 1
    mov  rsi, 0
    mov  rdx, hmsg
    mov  r10, hlen
    syscall

    jmp  hexit

bors:
    ;
    ; SunOS code 
    ;
    mov rdi, sunz
    mov rax, 12            ; chdir 
    syscall

    cmp rax,0
    jne bsd

    mov rdi,1
    mov rsi,suno
    mov rdx,sunob
    mov rax,4
    syscall

    jmp bexit

    ;   
    ; BSD code
    ;
bsd:
    mov rdi,1
    mov rsi,obsd
    mov rdx,obyte
    mov rax,4            ; sys_write
    syscall

bexit:
    mov rdi,69
    mov rax,1            ; sys_exit
    syscall

hexit:
    mov rdi, 0
    mov rax, 56
    syscall

section .data
    sunz db '/system',0
    tmp  db '/tmp',0
    suno db 'SunOS',0x0a
    sunob equ $-suno
    obsd db 'BSD',0x0a
    obyte equ $-obsd
    linz db 'Linux',0x0a
    lbyte equ $-linz
    hmsg db 'Haiku',0x0a
    hlen equ $-hmsg

section .note.openbsd.ident
    align   2
    dd      8
    dd      4
    dd      1
    db      'OpenBSD',0 
    dd      0 
    align   2

section .note.netbsd.ident
    dd      7,4,1
    db      'NetBSD',0
    db      0
    dd      200000000

section .comment
    db      0,"GCC: (GNU) 4.2.0",0          ; Haiku
                                                                                                                                                        
