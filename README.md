# vga-animation
Double buffered animation with vertical synchronization. Implemented as bootloader for 80286 with VGA. Written in NASM.

## Building
```$ nasm -f bin src/main.asm -o floppy.bin```

## Running with QEMU
```$ qemu-system-i386 -drive format=raw,file=floppy.bin```

## Design
### Algorithm
1. Clear *backbuffer.*
2. Draw on *backbuffer.*
3. Wait for vertical blank.
4. Copy *backbuffer* to *framebuffer.*

### Vertical Synchronization
VGA's mode `0x13` is memory mapped to memory segment `0xA000` with a contiguous layout of 320x200 byte color-indexed pixels.
Writing to this framebuffer directly creates noticable screen tearing, so a backbuffer is created.
This allows us to compute rendering outside of the vertical blank phase.

The backbuffer is cleared with a reset color to prepare for rendering. Afterwards, the rasterization happens over the newly-cleared backbuffer.

Finally, the vertical blanking bit is polled from the adapter's serial port.
It idles here until the vertical blanking bit indicates that it has entered the vertical blanking phase, finally copying backbuffer to memory-mapped framebuffer.

### Calling Conventions
I did not pass arguments of a function on the stack, rather I expected certain registers to be filled before calling a function.
This works fine as long as functions do not require too many arguments.

### The Symbol
I chose the chinese symbol "雙" (pinyin: *shuāng*) which means 'double' as it is relevant due to this being a double-buffered rendering.

The symbol's sprite was too large (4096 bytes) to fit within the boot sector (512 bytes), so it was placed on the subsequent sectors after the boot sector.
This required a BIOS system call to load sectors into memory.
