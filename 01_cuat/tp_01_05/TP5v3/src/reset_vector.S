/**
 * Archivo: reset_vector.s
 * Función: retorno a la zona post reset
 * Autor: Gabriel Crisafio
 **/

/* Referencias a funciones externas */
.extern _Bootloader
/* Modo de funcionamiento: arm */
.code 32

.global _reset_vector

.section .inicializacion_reset_vector,"ax"@progbits // seccion .inicio que se ejecuta en ROM 
// se ejecuta reset_handler en ROM porque es el 1er programa que se ejecuta despues de reset 
// dentro de este handler se deshabilita IRQ y FIQ para que no se interrumpa el proceso de Reset
_reset_vector:
    LDR PC, =_reset

_reset:
   /*  Deshabilitamos IRQ y FIQ para que no interrumpan durante el proceso de reset en ARMv7 */
   CPSID if 
   # CPSID if esta mas optimizado (1 instruccion) que las siguientes lineas de codigo:
   @  mrs	r0,  cpsr        @ Move to general purpose Register a System register
   @  bic	r0,  r0,  #0x1f  @ BItwise bit Clear
   @  orr	r0,  r0,  #0xd3  @ OR bitwise 0xd3 -> 11010011 -> CPSR[76x43210]
   @  msr	cpsr,r0          @ Move to System register a general purpose Register

   /* N Z C V bits = 0 (OPCIONAL si se necesita en la aplicacion)*/
    mrs	r0,  cpsr
    bic	r0,  r0,  #0xf0000000  /* BItwise bit Clear N, Z, C, V bits */
    msr	cpsr,r0

   /* Informe de Datos (Marca, Version, etc) de Procesador (OPCIONAL) */
   mrc	p15, 0, r0, c0, c0, 0 // Identificacion de Procesador en R0 (https://developer.arm.com/documentation/ddi0601/2023-03/AArch32-Registers/MIDR--Main-ID-Register?lang=en)
   
   B _Bootloader

.end
