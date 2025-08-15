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

.section .data
.global aux @ cada Tarea lee esta variable para ceder el mando
aux: .word 0 @ Contador de ticks (asociado con IRQ_Handler), cont = 0 y cont+=1 por cada tick de IRQ

.section .aplicacion,"ax"@progbits
//NOTA cuando el procesador entra a un Handler de Excepcion se guarda CPSR --> SPSR automaticamente

UND_Handler:  
    SUB LR, LR, #4 // LR = LR - 4
    /* Guardar R10 */
    PUSH { R10 } // dentro del Handler voy a utilizar R10 pusheo a la pila para guardar contenido anterior y no cortar secuencia

    MOV R10, #0
    STR R10, [LR] // [Instruccion No Definida] = 0x0000 0000 = andeq r0, r0, r0

    POP { R10 } // restauro valores

    MOVS PC, LR // MOV PC, LR y MOV CPSR, SPSR

SVC_Handler: // Parametros R0-R1-R2-R3
    LDR R4,[LR,#-4] // veo instruccion que genero SVC para obtener el parametro
    AND R4,#0x1 // me quedo con bit 0
    CMP R4,#0x1
    BEQ suma_svc
    BNE resta_svc

suma_svc:
    // R1:R0 + R3:R2
    ADDS R0, R0, R2 // Sumar las partes bajas (R0+R2) y ajusar el flag Carry
    ADC R1, R1, R3 // Sumar las partes altas (R1+R3) incluyendo el acarreo

    MOVS PC, LR

resta_svc:
    // R1:R0 - R3:R2
    SUBS R0, R0, R2 // Resta las partes bajas (R0-R2) y ajustar el flag de acarreo
    SBC R1, R1, R3 // Restar las partes altas (R1-R3) incluyendo el acarreo

    MOVS PC, LR

PREF_Handler:
    SUB LR, LR, #4 // LR = LR - 4

    MOVS PC, LR


ABT_Handler:
    SUB LR, LR, #8 // LR = LR - 8

    /* Guardar R10 = "MEM" */
    PUSH { R10, R12 } // dentro del Handler voy a utilizar R10 y R12, pusheo a la pila para guardar contenido anterior y no cortar secuencia
    LDR R12, =_ABT_string
    LDR R10, [R12]
    POP { R10, R12 } // restauro valores

    MOVS PC, LR


IRQ_Handler:
    sub lr, lr, #4                      @retornar a la instruccion en ejecucion al momento de la interrupcion
    stmfd sp!, {r0-r12, lr}             @resguarda contexto en pila de IRQ
 
    mrs r11, spsr                       @reguarda Saved Processor Status Register
    push {r11}
 
    pop {r11}
    msr spsr, r11                       @reguarda Saved Processor Status Register
 
    ldmfd sp!, {r0-r12, pc}^            @restaura contexto y retorna

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