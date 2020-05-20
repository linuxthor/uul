# uul

*"..It's a Unix system! I know this!.."*

Uul (pronounced "ool") is a PoC 'Universal Unix Loader.' This code when assembled produces an x86_64 
ELF binary that can run unmodified on a number of different Unix(-like) systems. The code will 
determine the flavour of \*nix it's being run on and jump into a code path specific to that system.

Unmodified the uul ELF binary has been tested to work on:

- Linux
- FreeBSD
- OpenBSD
- NetBSD
- Dragonfly BSD
- Haiku (BeOS successor) 
- Illumos (SunOS successor) 

Structurally the file is a standard ELF x86_64 binary with two additional mandatory sections 
'.note.openbsd.ident' for OpenBSD and '.note.netbsd.ident' for NetBSD. Additionally a .comment 
section is added with a reference to a GCC version to suppress warnings on Haiku. The OSABI field 
in the ELF header is set to 0x09 ("FreeBSD") allowing FreeBSD to load the file. 

The code exploits differences in syscall numbering to determine which system 'family' it's currently
running on. 64 bit versions of Linux follow a different system call numbering to 64 bit versions of BSD/SunOS
with 64 bit versions of Haiku having yet another, different system call numbering. We can use this as a gadget 
to work out what system family we're running on based on the return value of certain system calls. 

Firstly system call 12 is executed, this is create_sem on Haiku, chdir on \*BSD and brk on Linux.
On Haiku create_sem will return a sem_id for the sem (for example 0x909) on BSD chdir will return 0 for 
success and on Linux brk will return the new value of the brk when called with a reasonable argument or the 
value of the existing brk in case of error (see the 'Linux notes' section of the brk(2) man page for the 
difference between the brk syscall, which works as described above, vs the glibc wrapper which may return 
values such as 0 or -1) 

In this PoC the first argument to syscall 12 points to the string '/tmp' as does the second argument. The 
return value from this system call is checked to see if it is less than 0xffff and if so we branch to a 
test for Haiku or BSD/Solaris. If the return value is greater than 0xffff we can enter the Linux code path as 
this appears to be the return value of brk rather than the Haiku sem_id or the BSD/SunOS chdir success value. 
Next we test to see if this is Haiku or BSD/Solaris by checking if the return value is zero - if it is greater 
than zero we enter the Haiku code path. Finally we determine if this is BSD or Solaris by attempting to chdir to 
/system which is (by default) a valid path on Solaris but not on BSD. 

Assemble on Linux with:
```
nasm -f elf64 -o uul.o uul.asm
ld -o uul uul.o
elfedit --output-osabi FreeBSD uul 

$ file uul
uul: ELF 64-bit LSB executable, x86-64, version 1 (FreeBSD), statically linked, 
for OpenBSD, for NetBSD 2.0, not stripped

```
Linux
```
strace ./uul
execve("./uul", ["./uul"], [/* 50 vars */]) = 0
brk(0x600234)                           = 0x82b000
write(1, "Linux\n", 6Linux
)                  = 6
exit(42)        
```
FreeBSD 
```
root@freebsd:~ # ktrace /tmp/uul
BSD
root@freebsd:~ # kdump
   755 ktrace   RET   ktrace 0
   755 ktrace   CALL  execve(0x7fffffffee27,0x7fffffffebc0,0x7fffffffebd0)
   755 ktrace   NAMI  "/tmp/uul"
   755 uul      RET   execve JUSTRETURN
   755 uul      CALL  chdir(0x600234)
   755 uul      NAMI  "/tmp"
   755 uul      RET   chdir 0
   755 uul      CALL  chdir(0x60022c)
   755 uul      NAMI  "/system"
   755 uul      RET   chdir -1 errno 2 No such file or directory
   755 uul      CALL  write(0x1,0x60023f,0x4)
   755 uul      GIO   fd 1 wrote 4 bytes
       "BSD
       "
   755 uul      RET   write 4
   755 uul      CALL  exit(0x45)
```
OpenBSD
```
openbsd# ktrace /tmp/UUL
BSD
openbsd# kdump
 84686 ktrace   RET   ktrace 0
 84686 ktrace   CALL  execve(0x7f7fffff4def,0x7f7fffff4cf0,0x7f7fffff4d00)
 84686 ktrace   NAMI  "/tmp/UUL"
 84686 ktrace   ARGS
        [0] = "/tmp/UUL"
 84686 UUL      RET   execve 0
 84686 UUL      CALL  chdir(0x600234)
 84686 UUL      NAMI  "/tmp"
 84686 UUL      RET   chdir 0
 84686 UUL      CALL  chdir(0x60022c)
 84686 UUL      NAMI  "/system"
 84686 UUL      RET   chdir -1 errno 2 No such file or directory
 84686 UUL      CALL  write(1,0x60023f,0x4)
 84686 UUL      GIO   fd 1 wrote 4 bytes
       "BSD
       "
 84686 UUL      RET   write 4
 84686 UUL      CALL  exit(69)
```
NetBSD
```
# ktrace /tmp/uul
BSD
# kdump
   147      1 ktrace   EMUL  "netbsd"
   147      1 ktrace   CALL  execve(0x7f7fffbfa487,0x7f7fffbf9f18,0x7f7fffbf9f28)
   147      1 ktrace   NAMI  "/tmp/uul"
   147      1 uul      EMUL  "netbsd"
   147      1 uul      RET   execve JUSTRETURN
   147      1 uul      CALL  chdir(0x600234)
   147      1 uul      NAMI  "/tmp"
   147      1 uul      RET   chdir 0
   147      1 uul      CALL  chdir(0x60022c)
   147      1 uul      NAMI  "/system"
   147      1 uul      RET   chdir -1 errno 2 No such file or directory
   147      1 uul      CALL  write(1,0x60023f,4)
   147      1 uul      GIO   fd 1 wrote 4 bytes
       "BSD\n"
   147      1 uul      RET   write 4
   147      1 uul      CALL  exit(0x45)
```
Dragonfly BSD
```
dfly# ktrace /tmp/uul
BSD
dfly# kdump
  877:1    ktrace   RET   ktrace 0
  877:1    ktrace   CALL  umtx_wakeup(0x80044ed80,0)
  877:1    ktrace   RET   umtx_wakeup 0
  877:1    ktrace   CALL  umtx_wakeup(0x80044ed80,0)
  877:1    ktrace   RET   umtx_wakeup 0
  877:1    ktrace   CALL  umtx_wakeup(0x80044ed80,0)
  877:1    ktrace   RET   umtx_wakeup 0
  877:1    ktrace   CALL  execve(0x7fffffdfdc17,0x7fffffdfd9d0,0x7fffffdfd9e0)
  877:1    ktrace   NAMI  "/tmp/uul"
  877:1    uul      RET   execve 0
  877:1    uul      CALL  chdir(0x600234)
  877:1    uul      NAMI  "/tmp"
  877:1    uul      RET   chdir 0
  877:1    uul      CALL  chdir(0x60022c)
  877:1    uul      NAMI  "/system"
  877:1    uul      RET   chdir -1 errno 2 No such file or directory
  877:1    uul      CALL  write(0x1,0x60023f,0x4)
  877:1    uul      GIO   fd 1 wrote 4 bytes
       "BSD
       "
  877:1    uul      RET   write 4
  877:1    uul      CALL  exit(0x45)
```
Haiku
```
~> strace /tmp/uul
[   521] _kern_image_relocated(0x140b) (860 us)
[   521] _kern_set_area_protection(0x36fe, 0x5) = 0x0 No error (5 us)
[   521] _kern_create_sem(0x600234, "/tmp") = 0x1175 (2 us)
Haiku
[   521] _kern_write(0x1, 0x0, 0x600249, 0x6) = 0x6 (6 us)
[   521] _kern_exit_thread(0x0) (2 us)
```
SunOS
```
root@openindiana:~# truss /tmp/uul.
execve("/tmp/uul.", 0xFFFFFD7FFFDFB388, 0xFFFFFD7FFFDFB398)  argc = 1
chdir("/tmp")                                   = 0
chdir("/system")                                = 0
SunOS
write(1, " S u n O S\n", 6)                     = 6
_exit(69)
```

Tested versions:
```
Linux   -       Ubuntu 18.04.4 LTS
FreeBSD -       FreeBSD 12.1-RELEASE r354233 GENERIC
OpenBSD -       OpenBSD 6.7 (GENERIC)
NetBSD  -       NetBSD 8.1 (GENERIC)
Dragonfly BSD - DragonFly v5.6.0-RELEASE (X86_64_GENERIC)
Haiku -         Haiku-r1-beta1
Illumos -       OpenIndiana Hipster-GUI-20181023
```
Based on two earlier PoC:    
https://github.com/linuxthor/sixnix    
https://github.com/linuxthor/OpenLSD    
