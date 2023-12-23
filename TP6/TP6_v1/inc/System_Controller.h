/**
 * Archivo: System_Controller.h
 * Función: Libreria de SP810 System Controller (SYSCTRL) 
 * Location: Southbridge
 * Datasheet: https://developer.arm.com/documentation/dui0417/d/programmer-s-reference/system-controller--sysctrl-?lang=en
 * Autor: Gabriel Crisafio
**/

#ifndef SYSCTRL_LIB_H
#define SYSCTRL_LIB_H


// SYSCTRL 0
//     Controls the remap signal, watchdog 0 clock enable, and timer enables for timers 0,1,2 and 3.
// SYSCTRL 1
//     Controls watchdog 1 clock enable, and timer enables for timers 4,5,6 and 7.

#define SYSCTRL0 0x10001000
#define SYSCTRL1 0x1000A000

#endif // SYSCTRL_LIB_H

