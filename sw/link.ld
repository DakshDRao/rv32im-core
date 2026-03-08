OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY {
    MEM (rwx) : ORIGIN = 0x00000000, LENGTH = 4K
}

SECTIONS {
    .text 0x00000000 : {
        *(.text.start)
        *(.text*)
    } > MEM

    .data : {
        *(.data*)
        *(.rodata*)
    } > MEM

    .bss : {
        *(.bss*)
    } > MEM
}