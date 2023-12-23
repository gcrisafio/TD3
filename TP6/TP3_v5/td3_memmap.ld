                        /* 
    Definiciones necesarias: formato de salida, arquitectura y punto de entrada
*/
OUTPUT_FORMAT("elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(_start)


/*
    DEFINICION:
    .inicio: secciones que se ejecutan en ROM

*/

/* 
    Definiciones de simbolos necesarios
*/
_PUBLIC_ROM_INIT = 0x70010000; /* inicio de ROM */
_PUBLIC_STACK_INIT = 0x70020000;
_PUBLIC_RAM_INIT = 0x70030000;

_PUBLIC_LMA_SECTION_DATA = _PUBLIC_ROM_INIT + _PUBLIC_SIZE_INICIO + _PUBLIC_SIZE_TEXT;
_PUBLIC_VMA_SECTION_DATA = _PUBLIC_RAM_INIT + _PUBLIC_SIZE_TEXT;


_ISR_TABLE_START = 0x00000000; /* Direccion de Table_Vector*/

/* Constantes a utilizar */
C_STACK_SIZE   = 4K;
IRQ_STACK_SIZE = 128;
FIQ_STACK_SIZE = 128;
SVC_STACK_SIZE = 128;
ABT_STACK_SIZE = 128;
UND_STACK_SIZE = 128;

/* 
    Definición del mapa de memoria
*/
MEMORY
{
    public_ram	: org = _PUBLIC_RAM_INIT, len = 0x1000
    public_stack : org = _PUBLIC_STACK_INIT, len = 8832
}

/* 
    Definición de las secciones
*/
SECTIONS
{    
    __isr_table_start__ = _ISR_TABLE_START;
    . = _PUBLIC_RAM_INIT;
    /* 
        usamos la siguiente notacion para definir la VMA y LMA para cada seccion:
            .seccion VMA : LMA 
            {
                *(.seccion*)
            }
    */
    /* La seccion 'inicio' se ejecuta en ROM, por lo tanto, LMA=VMA */
    /* 
    como codigo ejecutado en ROM (VMA=LMA), se deja vacio el 2do argumetno y el Linker toma por default que VMA=LMA        
    .inicio ROM :   
    */

    .inicio _PUBLIC_ROM_INIT : AT (_PUBLIC_ROM_INIT) 
        { 
        __ROM_start__ = .;
        *(.inicio_reset_vector) /* esta es la 1er seccion de entrada que se ejecuta porque esta al comienzo de la ROM (0x7001 0000). El 1er codigo que se ejecuta en el procesador debe encontrarse en 0x70001 0000*/
        *(.inicio*) /* seccion que se ejecuta en ROM*/
        __ROM_end__ = .;
        } 
        _PUBLIC_SIZE_INICIO = __ROM_end__ - __ROM_start__;
    /*  __inicio_fin = . direccion donde termina seccion 'inicio' */


   /*. = _PUBLIC_RAM_INIT; seccion 'text' tiene VMA=0x70030000 (lugar en RAM donde se va a ejecutar) */
   /*  .text : AT(__inicio_fin) /* Definimos LMA de seccion 'text' a continuacion de seccion 'inicio' */
    .text _PUBLIC_RAM_INIT : AT( _PUBLIC_ROM_INIT +_PUBLIC_SIZE_INICIO) /* AT: Definimos LMA de seccion 'text' a continuacion de seccion 'inicio' */
        { 
        __text_start__ = .;
        *(.text*) /* la sintaxis .text* permite que todas las secciones que su nombre empiece con ".text" se guardan en esta seccion */
        __text_end__ = .;
        } 
    _PUBLIC_SIZE_TEXT = __text_end__ - __text_start__;
    _SECTION_TEXT_LMA = LOADADDR (.text) ; /* LMA de .text  */

    .data _PUBLIC_RAM_INIT + _PUBLIC_SIZE_TEXT : AT( _PUBLIC_ROM_INIT + _PUBLIC_SIZE_INICIO + _PUBLIC_SIZE_TEXT)
        { 
        __data_start__ = .;
        *(.data*) 
        __data_end__ = .;

        } > public_ram
    _PUBLIC_SIZE_DATA = __data_end__ - __data_start__;
    _SECTION_DATA_LMA = LOADADDR (.data) ; /* LMA de .text  */

    .bss _PUBLIC_RAM_INIT + _PUBLIC_SIZE_TEXT  + _PUBLIC_SIZE_DATA : {
        . = ALIGN(4);
        __bss_start__ = .;
        *(.bss*)
        __bss_end__ = .;
        } > public_ram

    .stack : {

        /* Se ordenan los Stack para cada modo  */
        __stack_start__ = .;

        *(.stack*) /* Stack definido a mano */

        . += IRQ_STACK_SIZE;
        . = ALIGN(4);
        __irq_stack_top__ = .;

        . += FIQ_STACK_SIZE;
        . = ALIGN(4);
        __fiq_stack_top__ = .;

        . += SVC_STACK_SIZE;
        . = ALIGN(4);
        __svc_stack_top__ = .;

        . += ABT_STACK_SIZE;
        . = ALIGN(4);
        __abt_stack_top__ = .;

        . += UND_STACK_SIZE;
        . = ALIGN(4);
        __und_stack_top__ = .;

        . += C_STACK_SIZE;
        . = ALIGN(4);
        __sys_stack_top__ = .;

        __stack_end__ = .;

        } > public_stack
    /* queda comprimidas las secciones y se ahorra en binario*/
}
