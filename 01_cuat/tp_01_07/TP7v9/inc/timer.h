/**
 * Archivo: timer.h
 * Función: Libreria para manejo de Timers
 * Autor: Gabriel Crisafio
**/

#ifndef TIMER_LIB_H
#define TIMER_LIB_H

#include <stdint.h>


// Memory Map
// Define las direcciones base de los bancos de timers
#define TIMER_BANK_1 0x10011000 // Timer 0-1 
#define TIMER_BANK_2 0x10012000 // Timer 2-3
#define TIMER_BANK_3 0x10018000 // Timer 4-5
#define TIMER_BANK_4 0x10019000 // Timer 6-7


// Offset
// Define los offsets para los timers dentro de un Banco
#define TIMER_A_OFFSET 0x00 
#define TIMER_B_OFFSET 0x20

// Definicion de Funciones
// Macros para conversiones de tiempo y frecuencia
#define TIMER_LOAD_MS(ms) ((ms) * 1000)
    // 10 x 1MHz/10**3 = 10mseg x 1MHz 

// Seleccion de un TIMER
// Selecciona la base de acuerdo al Timer que se va a usar
#define TIMER 0

#if (TIMER < 2)
#define TIMER_BASE_ADDRESS TIMER_BANK_1
#elif ((TIMER >= 2) && (TIMER < 4))
#define TIMER_BASE_ADDRESS TIMER_BANK_2
#elif ((TIMER >= 4) && (TIMER < 6))
#define TIMER_BASE_ADDRESS TIMER_BANK_3
#else
#define TIMER_BASE_ADDRESS TIMER_BANK_4
#endif

// Selecciona el offset dependiendo del Timer del banco
#define TIMER_OFFSET ((TIMER % 2) ? TIMER_B_OFFSET : TIMER_A_OFFSET)

#define TIMER0_ADDR + TIMER_OFFSET

// Definición de la estructura de control y configuración del Timer
/* Pag. 34 - Table 3-1 (ARM Dual-Timer Module SP804) */
typedef volatile struct {
    uint32_t LOAD;        /* Load                     */
    uint32_t VALUE;       /* Current value            */
    uint32_t CTRL;        /* Control                  */
    uint32_t INTCRL;      /* Interrupt clear          */
    uint32_t RIS;         /* Raw interrupt status     */
    uint32_t MIS;         /* Masked interrupt status  */
    uint32_t BGLOAD;      /* Background load          */
} _timer_t; //estructura para Timer

#endif // TIMER_LIB_H
