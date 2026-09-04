bits 16
cpu 286

org 0x7C00

VGA_MAIN_SEG equ 0xA000
VGA_BACK_SEG equ VGA_MAIN_SEG - 0x1000
VGA_WIDTH equ 320
VGA_HEIGHT equ 200
VGA_SIZE equ VGA_WIDTH * VGA_HEIGHT

SPRITE_PTR equ 0x8000
SPRITE_WIDTH equ 64
SPRITE_HEIGHT equ 64
SPRITE_SIZE equ SPRITE_WIDTH * SPRITE_HEIGHT

main:
  ; load sprite from subsequent sectors
  mov ah, 0x02
  mov al, SPRITE_SIZE / 512
  mov ch, 0
  mov cl, 2
  mov dh, 0
  ; dl already contains drive number
  xor bx, bx
  mov es, bx
  mov bx, SPRITE_PTR
  int 0x13
  jc halt ; halt if failure

  ; set VGA to mode 0x13
  mov ax, 0x0013
  int 0x10

loop:
  call frame
  jmp loop

; infinitely halt program
halt:
  hlt
  jmp halt

; es: framebuffer segment
; al: color
clear_buffer:
  mov ah, al
  xor di, di
  mov cx, VGA_SIZE / 2 ; divide to get word count

  ; copy color over
  cld
  rep stosw

  ret

draw_buffer:
  mov di, VGA_MAIN_SEG
  mov es, di
  xor di, di
  mov si, VGA_BACK_SEG
  mov ds, si
  xor si, si
  mov cx, VGA_SIZE / 2 ; divide to get word count

  ; wait for vertical blanking
  ; jmp .skip_blanking ; uncomment for debugging
  mov dx, 0x03DA
.blanking:
  in al, dx
  and al, 8
  jnz .blanking
.not_blanking:
  in al, dx
  and al, 8
  jz .not_blanking
.skip_blanking:

  ; copy backbuffer over
  cld
  rep movsw

  ret

; ds:si: sprite address
; es: framebuffer segment
; ax: sprite y offset
; bx: sprite x offset
; cx: sprite width
; dx: sprite height
draw_sprite:
  mov di, VGA_WIDTH
  push dx
  mul di
  pop dx
  add ax, bx
  mov di, ax
.draw_sprite_row:
  push cx
  cld
  rep movsb ; TODO convert to movsw
  pop cx

  mov ax, VGA_WIDTH
  sub ax, cx
  add di, ax
  dec dx
  jnz .draw_sprite_row

  ret

update:
  ; set memory segment to one with variables
  xor si, si
  mov ds, si

.begin:
  cmp byte [direction], 0
  je .ne
  cmp byte [direction], 1
  je .se
  cmp byte [direction], 2
  je .sw
  cmp byte [direction], 3
  je .nw

.ne:
  cmp word [x_position], VGA_WIDTH - SPRITE_WIDTH
  jg .ne2nw
  cmp word [y_position], 0
  je .ne2se
  inc word [x_position]
  dec word [y_position]
  jmp .end
.ne2se:
  mov byte [direction], 1
  jmp .begin
.ne2nw:
  mov byte [direction], 3
  jmp .begin

.se:
  cmp word [x_position], VGA_WIDTH - SPRITE_WIDTH
  jg .se2sw
  cmp word [y_position], VGA_HEIGHT - SPRITE_HEIGHT
  jg .se2ne
  inc word [x_position]
  inc word [y_position]
  jmp .end
.se2sw:
  mov byte [direction], 2
  jmp .begin
.se2ne:
  mov byte [direction], 0
  jmp .begin

.sw:
  cmp word [x_position], 0
  je .sw2se
  cmp word [y_position], VGA_HEIGHT - SPRITE_HEIGHT
  jg .sw2nw
  dec word [x_position]
  inc word [y_position]
  jmp .end
.sw2se:
  mov byte [direction], 1
  jmp .begin
.sw2nw:
  mov byte [direction], 3
  jmp .begin
.nw:
  cmp word [x_position], 0
  je .nw2ne
  cmp word [y_position], 0
  je .nw2sw
  dec word [x_position]
  dec word [y_position]
  jmp .end
.nw2ne:
  mov byte [direction], 0
  jmp .begin
.nw2sw:
  mov byte [direction], 2
  jmp .begin

.end:
  ret

frame:
  ; clear framebuffer
  mov ax, VGA_BACK_SEG
  mov es, ax
  mov al, 0x00
  call clear_buffer

  ; draw sprite to backbuffer
  xor si, si
  mov ds, si
  mov si, SPRITE_PTR
  mov ax, [y_position]
  mov bx, [x_position]
  mov cx, SPRITE_WIDTH
  mov dx, SPRITE_HEIGHT
  call draw_sprite

  ; copy backbuffer to framebuffer
  call draw_buffer

  ; update position of sprite
  call update

  ret

; remember to update 'ds' to 0x0000 to access these!
variables:
  x_position dw (VGA_WIDTH - SPRITE_WIDTH) / 2
  y_position dw (VGA_HEIGHT - SPRITE_HEIGHT) / 2
  direction db 3 ; diagonals clockwise starting with northeast

padding:
  times 510 - ($ - $$) db 0
  dw 0xAA55 ; magic word at last two bytes

; place sprite data after boot sector
sprite:
  incbin "sprite.raw"
