.global _Pruebas_de_excepciones
.section .aplicacion,"ax"@progbits          // Sección de codigo.
.arm

_Pruebas_de_excepciones:
      BL _Prueba_Undefined_Instruction
      BL _Prueba_SVC

_Prueba_Undefined_Instruction:       ##Bootloader    // Símbolo que le indica al linker
                              //  donde arranca el programa.
      MOV R1, #1              
      .word 0xE7FFFFFF // Genero Instruccion No Definida
      MOV PC, LR

_Prueba_SVC:
      // R1:R0 = 35
      // R3:R2 = 53
      MOV R0,#0x1
      MOV R1,#0x1
      MOV R2,#0x2
      MOV R3,#0x3
      SWI 0
      MOV PC, LR

_Prueba:
      LDR R2, =argumento     
      LDR R0, [R2]

_leer_ascii:
      LDR R12, =asciz_string      // Posicion del string
      LDRB R0, [R12]              // guardar 1er caracter
      LDR R3, =argumento
      STRB R0, [R3]              // poner 1er caracter en argumento

prueba_bss:
      LDR R0, [R12]              // guardar string
      LDR R3, =factorial
      STR R0, [R3]

_prueba_stack:
      LDR R5,=asciz_string
      LDR R0, =constante              
      PUSH {R0}
      PUSH {R1}
      PUSH {R2}
      B .
      POP {R0}

      B .

// Seccion de datos inicializados
.section .data
asciz_string:
    .asciz "HOL"

.section .data
argumento: 
      .word 4            // Argumento del factorial.

.section .data
constante:
      .word 0xAA55AA55

// Seccion de datos no inicializados
.section .bss            // Sección de datos no inicializados.
factorial: 
      .space 4   // Reservar una palabra para guardar el factorial.
