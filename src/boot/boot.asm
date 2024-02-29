ORG 0x7c00
BITS 16

CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

_start:
    jmp short step2
    nop

times 33 db 0

jmp 0:step2

step2:
    cli             ; clear interrupts
    mov ax, 0x0
    mov ds, ax
    mov es, ax   
    mov ss, ax
    mov sp, 0x7c00  ; set stack pointer
    sti             ; enable interrupts

.load_protected:
    cli
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 0x1
    mov cr0, eax
    jmp CODE_SEG:load32
    

; GDT
gdt_start:
gdt_null:
    dd 0x0
    dd 0x0

; offset 0x8
gdt_code:
    dw 0xffff       ; Segment limit first 0-15 bits
    dw 0            ; Base address first 0-15 bits
    db 0            ; Base address second 16-23 bits
    db 0x9a         ; Access byte
    db 11001111b    ; 4 bits flags, 4 bits limit 16-19 bits 
    db 0            ; Base address third 24-31 bits

; offset 0x10
gdt_data:
    dw 0xffff       ; Segment limit first 0-15 bits
    dw 0            ; Base address first 0-15 bits
    db 0            ; Base address second 16-23 bits
    db 0x92         ; Access byte
    db 11001111b    ; 4 bits flags, 4 bits limit 16-19 bits 
    db 0            ; Base address third 24-31 bits

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

[BITS 32]
load32:
    mov eax, 1
    mov ecx, 100
    mov edi, 0x0100000
    call ata_lba_read
    jmp CODE_SEG:0x100000
    
ata_lba_read:
    ; Send the highest 8 bits of the LBA
    mov ebx, eax
    shr eax, 24
    or eax, 0xE0   ; Select the master drive
    mov dx, 0x1f6
    out dx, al
  
    ; Send the total sectors to read
    mov eax, ecx
    mov dx, 0x1F2
    out dx, al

    ; Send more bits of the LBA
    mov eax, ebx
    mov dx, 0x1F3
    out dx, al

    ; Send more bits of the LBA
    mov dx, 0x1F4
    mov eax, ebx    ; Restore backup LBA
    shr eax, 8
    out dx, al

    ; Send upper 16 bits of the LBA
    mov dx, 0x1F5
    mov eax, ebx    ; Restore backup LBA
    shr eax, 16
    out dx, al

    mov dx, 0x1F7
    mov al, 0x20
    out dx, al

    ; Read all sectors into memory
.next_sector:
    push ecx

; Sometimes the drive is busy, so wait for it to be ready
.try_again:
    mov dx, 0x1F7
    in al, dx
    test al, 8
    jz .try_again

; We need to read 256 words at a time
    mov ecx, 256
    mov dx, 0x1F0
    rep insw
    pop ecx
    loop .next_sector
    ; End of reading sectors
    ret

times 510-($-$$) db 0
dw 0xAA55