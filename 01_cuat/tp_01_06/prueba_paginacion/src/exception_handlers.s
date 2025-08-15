/**
 * Archivo: exception_handlers.s
 * Función: manejadores de las excepciones
 * Autor: Gabriel Crisafio
 **/




.global UND_Handler
.global SVC_Handler
.global PREF_Handler
.global ABT_Handler
.global IRQ_Handler
.global FIQ_Handler
.extern Incrementar_Puntero_L2
.extern Funcion_Paginacion

.section .text_handlers,"ax"@progbits


//NOTA cuando el procesador entra a un Handler de Excepcion se guarda CPSR --> SPSR automaticamente

UND_Handler:  
    /* Guardar R10 = "INV" */
    PUSH { R10, R12 } // dentro del Handler voy a utilizar R10 y R12, pusheo a la pila para guardar contenido anterior y no cortar secuencia
    LDR R12, =_UND_string
    LDR R10, [R12]
    POP { R10, R12 } // restauro valores

    MOVS PC, LR


SVC_Handler:
    /* Guardar R10 = "SVC" */
    PUSH { R10, R12 } // dentro del Handler voy a utilizar R10 y R12, pusheo a la pila para guardar contenido anterior y no cortar secuencia
    LDR R12, =_SVC_string
    LDR R10, [R12]
    POP { R10, R12 } // restauro valores

    MOVS PC, LR

PREF_Handler:
    SUB LR, LR, #4 // LR = LR - 4

    MOVS PC, LR


ABT_Handler:
    SUB LR, LR, #8 // LR = LR - 8

    /* Deshabilitamos Interrupciones */
    CPSID I // se debe deshabilitar para que Abort_Handler tenga mayor prioridad
            // hasta el momento, solo hay interrupciones de IRQ, si hubiese FIQ deberian deshabilitarse

    /* Guardar R10 = "MEM" */
    PUSH { R10, R12 } // dentro del Handler voy a utilizar R10 y R12, pusheo a la pila para guardar contenido anterior y no cortar secuencia
    LDR R12, =_ABT_string
    LDR R10, [R12]

    MRC p15, 0, R0, c6, c0, 0           @Leo la dirección de falla DFAR
    /* Utilizar puntero actual de L2 como Direccion Virtual */
    LDR R5, =_tabla_nivel_1        @ Cargar la dirección de L1 en R5
    BL Incrementar_Puntero_L2 @ Cargar direccion L2 en R4
    BL Funcion_Paginacion


    POP { R10, R12 } // restauro valores

    CPSIE I // Habilitamos interrupciones nuevamente

    MOVS PC, LR

IRQ_Handler:
    SUB LR, LR, #4 // LR = LR - 4
    STMFD R13!, { r0-r3 , r14 }

    /* Guardar R10 = "IRQ" */
    LDR R12, =_IRQ_string
    LDR R10, [R12]
    /* Espacio de Scheduler */

    /* Handler Code */
    BL kernel_handler_irq

    LDMFD R13!, { r0-r3, pc }^
    MOVS PC, LR

// en Caso de que GIC tenga mas de una INT: Handler Anidado
//IRQ_Handler:
//    SUB     lr, lr, #4
//    SRSFD    sp!, #0x1f      @ use SRS to save LR_irq and SPSR_irq in one step onto the
//                             @ System mode stack
//    CPS        #0x1f           @ Use CPS to switch to system mode
//  
//    PUSH       {r0-r3, r12}    @S tore remaining AAPCS registers on the System mode stack
//    AND        r1, sp, #4      @ Ensure stack is 8-byte aligned. Store adjustment and
//                               @ LR_sys to stack
//
//    SUB        sp, sp, r1
//
//    PUSH       {r1, lr}
//
//    BL                         @ identify_and_clear_source
//
//    CPSIE       i              @ Enable IRQ with CPS
//
//    BL          kernel_handler_irq
//
//    CPSID       i              @ Disable IRQ with CPS
//
//    POP         {r1, lr}       @ Restore LR_sys
//    ADD         sp, sp, r1     @ Unadjust stack
//    POP         {r0-r3, r12}   @ Restore AAPCS registers
//    RFEFD       sp!            @ Return using RFE from the System mode stack


FIQ_Handler:
    SUB LR, LR, #4 // LR = LR - 4

    MOVS PC, LR


/* Seccion de datos inicializados */ 
.section .data
_IRQ_string:
    .asciz "IRQ"

.section .data
_UND_string:
    .asciz "INV"

.section .data
_ABT_string:
    .asciz "MEM"

.section .data
_SVC_string:
    .asciz "SVC"