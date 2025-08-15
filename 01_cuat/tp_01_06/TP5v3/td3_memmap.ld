                        /* 
    Definiciones necesarias: formato de salida, arquitectura y punto de entrada
*/
OUTPUT_FORMAT("elf32-littlearm")
OUTPUT_ARCH(arm)

/*
    DEFINICION:
    .inicio: secciones que se ejecutan en ROM

*/

/* 
    Definiciones de simbolos necesarios
*/
_PUBLIC_ROM_INIT = 0x70010000; /* inicio de ROM */
_PUBLIC_STACK_INIT = 0x70300000;
_PUBLIC_RAM_INIT = 0x70030000;
_VECTOR_TABLE_VMA = 0x00000000;
_APLICACION_VMA = 0x70600000;
_DATA_VMA = 0x70500000;
_BSS_VMA = 0x70400000;
_PUBLIC_PAGES_INIT = 0x70050000; 

_tabla_nivel_1 = _PUBLIC_PAGES_INIT;
Size_L1 = 0x4000;
Size_L2 = 0x400;
L2_first_page = _tabla_nivel_1 + Size_L1 -Size_L2; /* el -Size_L2 es para el algoritmo*/
Primer_Pagina_L2 = _tabla_nivel_1 + Size_L1; 
_long_tables = Size_L1 + Size_L2*10;

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
    public_stack : org = _PUBLIC_STACK_INIT, len = 0x4000
}

/* 
    Definición de las secciones
*/
SECTIONS
{    
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

    .inicializacion _PUBLIC_ROM_INIT : AT (_PUBLIC_ROM_INIT) 
        { 
        . = ALIGN(4);
        __inicializacion_start__ = .;
        *(.inicializacion_reset_vector) /* esta es la 1er seccion de entrada que se ejecuta porque esta al comienzo de la ROM (0x7001 0000). El 1er codigo que se ejecuta en el procesador debe encontrarse en 0x70001 0000*/
        *(.inicializacion*) /* seccion que se ejecuta en ROM*/
        __inicializacion_end__ = .;
        } 
        _PUBLIC_SIZE_INICIALIZACION = __inicializacion_end__ - __inicializacion_start__;

    .vector_table _VECTOR_TABLE_VMA : AT (_PUBLIC_ROM_INIT+_PUBLIC_SIZE_INICIALIZACION)
        { 
            . = ALIGN(4);
            _VECTOR_TABLE_START = .;
            *(.vector_table*) 
            _VECTOR_TABLE_END = .;
        } 
            _PUBLIC_SIZE_VECTOR_TABLE = _VECTOR_TABLE_END - _VECTOR_TABLE_START;
            _VECTOR_TABLE_LMA = _PUBLIC_ROM_INIT+_PUBLIC_SIZE_INICIALIZACION;

    .aplicacion _APLICACION_VMA : AT( _PUBLIC_ROM_INIT +_PUBLIC_SIZE_INICIALIZACION+_PUBLIC_SIZE_VECTOR_TABLE) /* AT: Definimos LMA de seccion 'text' a continuacion de seccion 'inicio' */
        { 
        . = ALIGN(4);
        __aplicacion_start__ = .;
        *(.text_perifericos)
        *(.text_pagination)
        *(.aplicacion*) /* la sintaxis .text* permite que todas las secciones que su nombre empiece con ".text" se guardan en esta seccion */

        __exception_handlers_start__ = .;
        *(.section_exception_handlers*) 
        __exception_handlers_end__ = .;

        __aplicacion_end__ = .;
        } 
    _PUBLIC_SIZE_APLICACION = __aplicacion_end__ - __aplicacion_start__;
    _SECTION_APLICACION_LMA = _PUBLIC_ROM_INIT +_PUBLIC_SIZE_INICIALIZACION+_PUBLIC_SIZE_VECTOR_TABLE ; /* LMA de .text  */

    .data _DATA_VMA : AT( _PUBLIC_ROM_INIT + _PUBLIC_SIZE_INICIALIZACION +_PUBLIC_SIZE_VECTOR_TABLE +_PUBLIC_SIZE_APLICACION)
        { 
        . = ALIGN(4);
        __data_start__ = .;
        *(.data*) 
        __data_end__ = .;
        } 
    _PUBLIC_SIZE_DATA = __data_end__ - __data_start__;
    _PUBLIC_LMA_SECTION_DATA = _PUBLIC_ROM_INIT + _PUBLIC_SIZE_INICIALIZACION +_PUBLIC_SIZE_VECTOR_TABLE + _PUBLIC_SIZE_APLICACION;

    .bss _BSS_VMA : {
        . = ALIGN(4);
        __bss_start__ = .;
        *(.bss*)
        __bss_end__ = .;
        } 


/* Para tener de prueba, genero el mapa de memoria "Stack" con Regiones. Se define origen y len en MEMORY. Luego, se vuelca ese bloque de memoria a esa region usando > public_stack    */
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

        } > public_stack     /* vuelco bloque de memoria a region public_stack*/
    /* queda comprimidas las secciones y se ahorra en binario*/
}
