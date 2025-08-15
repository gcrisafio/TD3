/**
* Archivo: paginacion.s
* Función: Crea e inicializa las tablas de paginación
* Autor: Gabriel Crisafio
**/

    .global _paginacion
    .global Incrementar_Puntero_L2
    .global Funcion_Paginacion

    .extern _STACK_INIT
    .extern Gic_init
    .extern _tabla_nivel_1
    .extern _exception_page_init
    .extern _timer0_page_init
    .extern _gic_page_init
    .extern _memory_page_init
    .extern _dinamic_pages_init
    @ Direcciones físicas
    .extern _ADDR_TIMER_O
    .extern _ADDR_GIC_C
    .extern _ADDR_GIC_D
    .extern _ISR_TABLE_START    
    .extern _PUBLIC_RAM_INIT
    .extern _PUBLIC_STACK_INIT
    .extern _PUBLIC_PAGES_INIT
    .extern _PUBLIC_USR_MEM_INIT

    .extern _long_tables

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
**/
// Tabla de primer nivel
Paginacion_ISR_Table:
    @ Primer entrada: Excepción (0x00000000)
    LDR R0, =0x00000000
    LDR R1, =0x00000000 @ Cargar la dirección de _Direccion_Fisica en R6
    LDR R3, =0x1 //attr_L1 
    LDR R4, =0x813 //attr_L1 
    BL Funcion_Paginacion

Paginacion_Timer:
    LDR R0, =0x10011000
    LDR R1, =0x10011000 @ Cargar la dirección de _Direccion_Fisica en R6
    LDR R3, =0x1 // attr_L1
    LDR R4, =0x813 //attr_L2
    BL Funcion_Paginacion

Paginacion_GIC_CPU_Interface:
    LDR R0, =0x1E000000
    LDR R1, =0x1E000000 @ Cargar la dirección de _Direccion_Fisica en R6
    LDR R3, =0x1 // attr_L1
    LDR R4, =0x813 //attr_L2
    BL Funcion_Paginacion

Paginacion_GIC_Distributor:
    LDR R0, =0x1E001000
    LDR R1, =0x1E001000 @ Cargar la dirección de _Direccion_Fisica en R6
    LDR R3, =0x1 // attr_L1
    LDR R4, =0x813 //attr_L2
    BL Funcion_Paginacion

Paginacion_Stack:
    LDR R0, =0x70020000
    LDR R1, =0x70020000 @ Cargar la dirección de _Direccion_Fisica en R6
    LDR R3, =0x1 // attr_L1
    LDR R4, =0x813 //attr_L2
    BL Funcion_Paginacion

    ADD R0, R0, #0x1000 @ Debemos Paginar todos los Stack: proxima pagina en 0x70021000 = 0x70020000 + 4K
    ADD R6, R6, #0x1000 @ Hacemos lo mismo con Direccion_Fisica  
    LDR R3, =0x1 // attr_L1
    LDR R4, =0x813 //attr_L2
    BL Funcion_Paginacion
// HASTA ACA ANDA

Paginar_L1:
    LDR R0, =_tabla_nivel_1
    LDR R1, =_tabla_nivel_1 @ Cargar la dirección de _Direccion_Fisica BORRAR ESTOS COMPENTARIOS DE R6 (YA NO LO USAMOS)
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
    //POP {PC}
    LDR PC, =prueba

/**
* Se termina la creación e inicialización de la paginación
**/
prueba:
    MOV R0, #0
    BX LR     


    LDR R0, =0x1E000000
    LDR R6, =0x1E000000 @ Cargar la dirección de _Direccion_Fisica en R6
    LDR R5, =_tabla_nivel_1        @ Cargar la dirección de L1 en R5
    BL Incrementar_Puntero_L2 @ Cargar direccion L2 en R4
    BL Funcion_Paginacion

    LDR R0, =0x1E001000
    LDR R6, =0x1E001000 @ Cargar la dirección de _Direccion_Fisica en R6
    LDR R5, =_tabla_nivel_1        @ Cargar la dirección de L1 en R5
    BL Incrementar_Puntero_L2 @ Cargar direccion L2 en R4
    BL Funcion_Paginacion

    LDR R0, =0x70020000
    LDR R6, =0x70020000 @ Cargar la dirección de _Direccion_Fisica en R6
    LDR R5, =_tabla_nivel_1        @ Cargar la dirección de L1 en R5
    BL Incrementar_Puntero_L2 @ Cargar direccion L2 en R4
    BL Funcion_Paginacion

    ADD R0, R0, #0x1000 @ Debemos Paginar todos los Stack: proxima pagina en 0x70021000 = 0x70020000 + 4K
    ADD R6, R6, #0x1000 @ Hacemos lo mismo con Direccion_Fisica  
    LDR R5, =_tabla_nivel_1        @ Cargar la dirección de L1 en R5
    BL Incrementar_Puntero_L2 @ Cargar direccion L2 en R4
    BL Funcion_Paginacion
    @ conocemos que la suma de todos los Stack entra en 8K (2 paginas)


   @               @ Tercer entrada: USR_MEM (0x70080000)
   @ ldr r0, =_memory_page_init + 0x80*4
   @ ldr r1, =_PUBLIC_USR_MEM_INIT + 0x30 + 2 
   @ str r1, [r0, #0]

    /***************************************/ 
    /*   Paginación de las páginas         */
    /***************************************/
Paginacion_L1:
    LDR R0, =_PUBLIC_PAGES_INIT
    LDR R6, =_PUBLIC_PAGES_INIT @ Cargar la dirección de _Direccion_Fisica en R6
    LDR R5, =_tabla_nivel_1        @ Cargar la dirección de L1 en R5
    BL Incrementar_Puntero_L2 @ Cargar direccion L2 en R4
    BL Funcion_Paginacion

@ Pagino toda la tabla de nivel 1 en un bucle menos la primer entrada
    mov r7, r4
    MOV R2, R0, LSR #12  @ R2 = R0 >> 12 = 0x00abcd1
    AND R2, R2, #0xFF    @ b = R2 = R2 & 0xFF = 0x0000d1 <-- 2do puntero de Direccion Virtual

    mov r3, #0x1000
    mov r4, #15
    mov r5, #4                          
    ldr r6, =_PUBLIC_PAGES_INIT
    mov r10, r6         @ Para mantener la iteracion y tener la direccion de la entrada
@ pagino las diferentes entradas de la tabla de nivel 1 para la paginacion dinamica
_table_level_1:
    add r2, r2, #0x01   @ 0x51, 0x52, ... 0x5E, 0x5F
    mul r8, r2, r5      @ Multiplico por 4 cada valor de la suma anterior en cada iteración
    add r9, r7, r8      @ _memory_page_init + (0x51, 0x52, ... 0x5E, 0x5F)
    add r10, r10, r3    @ 0x70051000, 0x70052000, ... 0x7003E000, 0x7003F000
    orr r10, r10, #0x32 @ _PUBLIC_PAGES_INIT + 0x32
    mov r0, r9
    mov r1, r10
    str r1, [r0, #0]    @ Genero la entrada de la tabla nivel 1 
    sub r4, #1          @ decremento el contador del loop
    cmp r4, #0
    bne _table_level_1    

Paginacion_L2:
    LDR R0, =L2_first_page
    LDR R6, =L2_first_page @ Cargar la dirección de _Direccion_Fisica en R6
    LDR R5, =_tabla_nivel_1        @ Cargar la dirección de L1 en R5
    BL Incrementar_Puntero_L2 @ Cargar direccion L2 en R4
    BL Funcion_Paginacion

@                 @ entrada: Exception (0x70060000)
@    ldr r0, =_memory_page_init + 0x60*4
@    ldr r1, =_exception_page_init + 0x30 + 2     
@    str r1, [r0, #0]
@                 @ entrada: Timer (0x70061000)     
@    ldr r0, =_memory_page_init + 0x61*4
@    ldr r1, =_timer0_page_init + 0x30 + 2         
@    str r1, [r0, #0]
@                 @ entrada: GIC (0x70062000)    
@    ldr r0, =_memory_page_init + 0x62*4
@    ldr r1, =_gic_page_init + 0x30 + 2           
@    str r1, [r0, #0]
@                 @ entrada: RAM (0x70063000) 
@    ldr r0, =_memory_page_init + 0x63*4
@    ldr r1, =_memory_page_init + 0x30 + 2           
@    str r1, [r0, #0]
@                 @ entrada: Dinamic Pages (0x70064000) 
@    ldr r0, =_memory_page_init + 0x64*4
@    ldr r1, =_dinamic_pages_init + 0x30 + 2           
@    str r1, [r0, #0]
    

Paginacion_RAM:
    LDR R0, =0x70010000
    LDR R6, =0x70010000 @ Cargar la dirección de _Direccion_Fisica en R6
@Tablas_RAM:
    LDR R5, =_tabla_nivel_1        @ Cargar la dirección de L1 en R5
    BL Incrementar_Puntero_L2 @ Cargar direccion L2 en R4
    BL Funcion_Paginacion

    @guardar R4

@    ADD R0, R0, #0x1000 @ Debemos Paginar toda la RAM: proxima pagina en 0x70011000 = 0x70010000 + 4K, Paginamos cada 4K hasta 
@    ADD R6, R6, #0x1000 @ Hacemos lo mismo con Direccion_Fisica  
@    LDR R9, =_Fin_RAM
@    CMP R9, R0 @ Comparo R9 y R0, se activan flags en CPSR
@    BGT  @ if R9 > R0 --> Paginamos

/**
*   Configuración para el uso de la paginación (MMU)
**/
// TTRB0 debe apuntar a la tabla de directorio de páginas (Tabla 1)
    ldr r0, =_tabla_nivel_1
    mcr p15, 0, r0, c2, c0, 0
// Todos los dominios van a ser clientes (0x55555555)
    ldr r0, =0x55555555
    mcr p15, 0, r0, c3, c0, 0
// Habilito el MMU
    mrc p15, 0, r1, c1, c0, 0     @ Leer el registro de control (SCTLR) en r1
    bic r1, r1, #(1 << 29)        @ Poner el bit 29 en 0 (lo limpia)
    orr r1, r1, #0x1              @ Poner el bit 0 en 1 (habilita MMU)
    mcr p15, 0, r1, c1, c0, 0     @ Escribir el valor modificado de nuevo en el registro de control



/**
* Se termina la creación e inicialización de la paginación
**/
    BX LR      
//NOTA acoplar a las paginas que definimos, para eso usar un parametro mas por Registro ej R7 (ver que no se use dentro de las funciones o sino usar stack)
//    R7 = atributos de pagina

@ R0 = Direccion Virtual
@ LDR R6, =_Direccion_Fisica ; Cargar la dirección de _Direccion_Fisica en R6
@ LDR R5, =_L1        ; Cargar la dirección de _L1 en R5
@ LDR R4, =_L2        ; Cargar direccion L2 en R4
@ BL Funcion_Paginacion
.arm
Funcion_Paginacion:
      PUSH {LR}
// Se separa Direccion Virtual en a b c para hacer Offset
@ R0 = 0xabcd1234, ponga en R5 = 0xabc y en R2 = d1
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
    @ luego cargar en R6 = _Direccion_Fisica + (R2 * 4)
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

.section .data
contador:
    .word 0

.section .data 
    ptr_L2_actual:
        .word L2_first_page // Base = L2_first_page (primer pagina L2), se va incrementando por cada pagina

    LDR R10, =Size_L2
    ADD R4, R4, R10  @ Cargar direccion L2 en R4
    BX LR

.section .data
attr:
      .word 0x32

    