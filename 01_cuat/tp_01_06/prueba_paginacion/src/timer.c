//#include "../inc/timer.h"
/*******************************************************************************
 *                             GLOBAL DATA TYPES                               *
 ******************************************************************************/
/************ INCLUDES ************/
#include <timer.h>
#include <System_Controller.h>

//con __attribute__ indica que hay seccion de entrada en C al Linker Script
// NOTA funciones en C por defecto estan en seccion .text
void timer_init()
    {
        _timer_t* const TIMER0 = ( _timer_t* )TIMER_BANK_1;
        uint32_t* const SYSTEMCTRL0 =  (uint32_t*) SYSCTRL0 ;

        *(SYSTEMCTRL0) |= 0x8000; // TIMCLK = 1MHz
        // bit [15] = 1 : tiempo de referencia TIMCLK = 1MHz , 0 : tiempo de referencia REFCLK = 32.768kHz

        TIMER0->LOAD = TIMER_LOAD_MS(10); 
            // TimerXLoad = Periodo x TIMCLK / (TIMCLKENX x PRESCALE) 
            // Timer0Load = 10mseg x 1MHz = 10**4

        TIMER0->CTRL = 0xE2;
        /*  
            bit [0]: 0 -> periodico (wrapping mode)
            bit [1]: 1 -> Timer en 32 bits
            bit [2:3]: 00 -> Prescaler = 1
            bit [4]: 0 -> Reservado, no tocar
            bit [5]: 1 -> Habilitacion de interrupciones del timer
            bit [6]: 1 -> Periodico, termina cuenta y recarga valor de LOAD
            bit [7]: 1 -> Habilitacion del modulo TIMER para comenzar a usar 
        */
    }
