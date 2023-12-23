/**
 * Archivo: low_level_cpu_access.S
 * Función: funciones de bajo nivel de acceso al control del CPU
 * Autores: Peccia - Ferreyro
 **/

 

.global _irq_enable
.global _irq_disable
.global _MMU_Enable
.global _MMU_Disablez
.global _LOAD_ISR_Vectors_Base
.global _WRITE_8
.global _WRITE_16
.global _WRITE_32
.global _READ_8
.global _READ_16
.global _READ_32
.global _HALT_CPU
.global _READ_CPSR_REGS
.global _EOI


.section .text_pub
/*
 Habilita interrupciones
 */
.align 4             // Alineado a 4 Bytes
_irq_enable:
    DSB
    MRS R0, CPSR
    BIC R0, #0x80
    MSR CPSR, R0
    DSB
    ISB
    BX LR

/*
 Deshabilita interrupciones
 */
.align 4             // Alineado a 4 Bytes
_irq_disable:
    DSB
    MRS R0, CPSR
    ORR R0, #0x40
    MSR CPSR, R0
    DSB
    ISB
    BX LR

/*
    Carga la dirección base en la Public RAM de
    la tabla de ISR
 */
_LOAD_ISR_Vectors_Base:
    MCR     P15, #0, R0, C12, C0, #0
    DSB
    BX      LR


/*
    Realiza una suspensión del uP esperando por un evento
    de interrupción para salir de ese estado. Es como la instrucción
    HLT de Intel X86.
 */
.align 4             // Alineado a 4 Bytes
_HALT_CPU:
    WFI
    BX LR

/*
    Utilizamos la instrucción WFE (Wait for Event) para generarnos 
    un "Magic Breakpoint" propio y poder debuggear el código
 */
.align 4             // Alineado a 4 Bytes
_BREAKPOINT_DEBUG:
    WFE
    BX LR

.align 4             // Alineado a 4 Bytes
_READ_CPSR_REGS:
    DSB
    MRS R0, CPSR
    BX LR

.align 4             // Alineado a 4 Bytes
_EOI:
    MOV r0,#0x1
    LDR r1,=0x48200000
    STR r0, [r1, #0x48]

    BX LR
/*
    Funciones de escritura y lecutra de 8, 16 y 32 bits
    Para las funciones _WRITE_X, desde C es: _WRITE_X(DIRECCION, VALOR) 
 */
.align 4             // Alineado a 4 Bytes
_WRITE_8:
    STRB R1, [R0]       // STR Byte el contenido de R0 en la posición R1
    BX LR

_WRITE_16:
    STRH R1, [R0]       // STR HalfWord el contenido de R0 en la posición R1
    BX LR

_WRITE_32:
    STR R1, [R0]       // STR Word el contenido de R0 en la posición R1
    BX LR

_READ_8:
    LDRB R0, [R0]
    BX LR

_READ_16:
    LDRH R0, [R0]
    BX LR

_READ_32:
    LDR R0, [R0]
    BX LR
