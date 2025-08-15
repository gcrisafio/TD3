/**
* Archivo: paginacion.s
* Función: Crea e inicializa las tablas de paginación
* Autor: Gabriel Crisafio
**/

    .global _paginacion

    .extern _tabla_nivel_1
    .extern _long_tables

    .extern _habilitar_INT

    .section .text_pagination,"ax"@progbits

_paginacion:
    PUSH {LR}
@ Borro (pongo en 0) todo el espacio de memoria en donde se colocan las tablas 
@ de paginación
    ldr r1, =_tabla_nivel_1
    ldr r2, =_long_tables
    mov r0, #0
_borrado:
    strb r0, [r1], #1
    subs r2, #1
    bne _borrado
/**
* Creo e inicializo las tablas de paginación
Funcion_Paginacion: configura las paginas L1 y L2 
    in:
        R0 = Direccion Virtual
        R1 = Direccion Fisica
        R3 = attr de tabla L1
        R4 = attr de tabla L2
**/
Paginacion_ISR_Table:
    @ Primer entrada: Excepción (0x00000000)
    LDR R0, =0x00000000
    LDR R1, =0x00000000 
    LDR R3, =0x1 //attr_L1 
    LDR R4, =0x813 //attr_L1 
    BL Funcion_Paginacion

Paginacion_Timer:
    LDR R0, =0x10011000
    LDR R1, =0x10011000 
    LDR R3, =0x1 // attr_L1
    LDR R4, =0x813 //attr_L2
    BL Funcion_Paginacion

Paginacion_GIC_CPU_Interface:
    LDR R0, =0x1E000000
    LDR R1, =0x1E000000 
    LDR R3, =0x1 // attr_L1
    LDR R4, =0x813 //attr_L2
    BL Funcion_Paginacion

Paginacion_GIC_Distributor:
    LDR R0, =0x1E001000
    LDR R1, =0x1E001000 
    LDR R3, =0x1 // attr_L1
    LDR R4, =0x813 //attr_L2
    BL Funcion_Paginacion

Paginacion_Stack:
    LDR R0, =0x70020000
    LDR R1, =0x70020000 
    LDR R3, =0x1 // attr_L1
    LDR R4, =0x813 //attr_L2
    BL Funcion_Paginacion

    ADD R0, R0, #0x1000 @ Debemos Paginar todos los Stack: proxima pagina en 0x70021000 = 0x70020000 + 4K
    ADD R6, R6, #0x1000 @ Hacemos lo mismo con Direccion_Fisica  
    LDR R3, =0x1 // attr_L1
    LDR R4, =0x813 //attr_L2
    BL Funcion_Paginacion
    
/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ PRUEBAS @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ */
Paginacion_text_ROM_section:
// viendo variable _PUBLIC_SIZE_APLICACION sabemos que entra en una pagina de 4K (size = 0x130)
    LDR R0, =__inicializacion_start__ // VMA de section .text
    LDR R1, =__inicializacion_start__
    LDR R3, =0x1 // attr_L1
    LDR R4, =0x813 //attr_L2
    BL Funcion_Paginacion

Paginacion_vector_table:
// viendo variable _PUBLIC_SIZE_APLICACION sabemos que entra en una pagina de 4K (size = 0x130)
    LDR R0, =_VECTOR_TABLE_START // VMA de section .text
    LDR R1, =_VECTOR_TABLE_START
    LDR R3, =0x1 // attr_L1
    LDR R4, =0x813 //attr_L2
    BL Funcion_Paginacion

Paginacion_text_section:
// viendo variable _PUBLIC_SIZE_APLICACION sabemos que entra en una pagina de 4K (size = 0x130)
    LDR R0, =__aplicacion_start__ // VMA de section .text
    LDR R1, =__aplicacion_start__
    LDR R3, =0x1 // attr_L1
    LDR R4, =0x813 //attr_L2
    BL Funcion_Paginacion

Paginacion_data_section:
// viendo variable _PUBLIC_SIZE_APLICACION sabemos que entra en una pagina de 4K (size = 0x130)
    LDR R0, =__data_start__ // VMA de section .text
    LDR R1, =__data_start__
    LDR R3, =0x1 // attr_L1
    LDR R4, =0x813 //attr_L2
    BL Funcion_Paginacion

Paginacion_bss_section:
// viendo variable _PUBLIC_SIZE_APLICACION sabemos que entra en una pagina de 4K (size = 0x130)
    LDR R0, =__bss_start__ // VMA de section .text
    LDR R1, =__bss_start__
    LDR R3, =0x1 // attr_L1
    LDR R4, =0x813 //attr_L2
    BL Funcion_Paginacion

/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ PRUEBAS@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ */

Paginar_L1:
    LDR R0, =_tabla_nivel_1
    LDR R1, =_tabla_nivel_1 
    LDR R3, =0x1 // attr_L1
    LDR R4, =0x813 //attr_L2
    BL Funcion_Paginacion

incrementar_pagina_L1:
    ADD R0, R0, #0x1000
    ADD R1, R1, #0x1000
    BL Funcion_Paginacion
    LDR R5, =contador
    LDR R6, [R5]
incremento_contador:
    ADD R6, R6,#1
    STR R6, [R5]
    CMP R6, #4 // se que son 4 paginas
    BNE incrementar_pagina_L1
    MOV R6, #0
    STR R6, [R5]

Paginar_L2:
    LDR R0, =Primer_Pagina_L2
    LDR R1, =Primer_Pagina_L2 
    LDR R3, =0x1 // attr_L1
    LDR R4, =0x813 //attr_L2
    BL Funcion_Paginacion
incrementar_pagina_L2:
    ADD R0, R0, #0x1000
    ADD R1, R1, #0x1000
    LDR R5, =ptr_L2_actual
    LDR R6, [R5]
    CMP R0, R6
    BGT Fin_paginacion
    BL Funcion_Paginacion
    B incrementar_pagina_L2

Fin_paginacion:

Configurar_TTBR0:
    ldr r0, =_tabla_nivel_1
    mcr p15, 0, r0, c2, c0, 0
// Todos los dominios van a ser clientes (0x55555555)
    ldr r0, =0x55555555
    mcr p15, 0, r0, c3, c0, 0
// Habilito el MMU
Habilitar_MMU:
    mrc p15, 0, r1, c1, c0, 0     @ Leer el registro de control (SCTLR) en r1
    bic r1, r1, #(1 << 29)        @ Poner el bit 29 en 0 (lo limpia)
    orr r1, r1, #0x1              @ Poner el bit 0 en 1 (habilita MMU)
    mcr p15, 0, r1, c1, c0, 0     @ Escribir el valor modificado de nuevo en el registro de control
Finalizacion:
    POP {LR} // a partir de aca salta a la direccion PC = 0x000C
    MOVS PC, LR
  //  para mi que falta paginar los handler de excepciones

@@ Funcion Paginacion:
    @ R0 = Direccion Virtual
    @ R1 = Direccion_Fisica 
    @ R3 = attr de tabla L1
    @ R4 = attr de tabla L2
.arm
Funcion_Paginacion:
      PUSH {LR}
// Se separa Direccion Virtual en a b c para hacer Offset
@ej R0 = 0xabcd1234, ponga en R5 = 0xabc y en R2 = d1
Separacion_Direccion_Virtual:
    MOV R5, R0, LSR #20 @ a = R5 = R0 >> 20 = 0x00000abc

    MOV R6, R0, LSR #12  @ R6 = R0 >> 12 = 0x00abcd1
    AND R6, R6, #0xFF    @ b = R6 = R6 & 0xFF = 0x0000d1

Tabla_Nivel_1:
    LDR R7, =_tabla_nivel_1        @ Cargar la dirección de L1 en R7
    ADD R7, R7, R5, LSL #2 @ R7 = _L1 + (a*4) <-- L1+Offset: Sumar el desplazamiento (R5 * 4) a la dirección base
    LDR R11, [R7]
    CMP R11, #0
    BNE Leer_L1
    Configurar_L1:
        BL Incrementar_Puntero_L2
        ADD R8, R2, R3
        STR R8, [R7]
        B Configurar_Tabla_Nivel_2
    Leer_L1:
        LDR R10, [R7]
        LDR R12, =constante
        LDR R9, [R12]
        AND R11, R10, R9
        MOV R2, R11

Configurar_Tabla_Nivel_2:
    ADD R8, R2, R6, LSL #2 @ R8 = L2 + (b*4)   Sumar el desplazamiento (R2 * 4) a la dirección base
    ADD R9, R1, R4 @ Atributos R/W
    STR R9, [R8]

      POP {PC}

Incrementar_Puntero_L2:
    leer_ptr_L2:
        LDR R11,=ptr_L2_actual
        LDR R10, [R11]
    incrementar_ptr_L2:
        LDR R9,=Size_L2
        ADD R10, R10, R9 // ptr_L2 = ptr_L2 + size_L2
        STR R10, [R11]
    retornar_por_R2:
        MOV R2, R10

    BX LR

.section .data
constante:
      .word 0xFFFFFC00

.section .bss
contador:
    .space 4

.section .data 
    ptr_L2_actual:
        .word L2_first_page // Base = L2_first_page (primer pagina L2), se va incrementando por cada pagina