/*
 * Driver de GPIO para TD3 - Modificado con Sleep Jiffies
 */

// --- LIBRERÍAS DEL KERNEL ---
#include <linux/init.h>
#include <linux/module.h>
#include <linux/device.h>
#include <linux/types.h>
#include <linux/jiffies.h>       // NECESARIO: Para manejar tiempo en el kernel
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/interrupt.h>
#include <linux/delay.h>
#include <linux/slab.h>
#include <linux/of_platform.h>
#include <linux/of_irq.h>
#include <linux/of_address.h>
#include <linux/uaccess.h>
#include <linux/pinctrl/consumer.h>
#include <linux/sched.h>         // NECESARIO: Para schedule_timeout
#include <linux/sched/signal.h>  // NECESARIO: Para signal_pending

// --- METADATOS DEL MÓDULO ---
MODULE_DESCRIPTION("Driver de GPIO para TD3 - Low CPU Usage");
MODULE_LICENSE("GPL");
MODULE_ALIAS("platform:Crisafio_td3");

/* Definiciones del driver */
#define BASE_MINOR 0
#define MINOR_COUNT 1
#define DEVICE_TYPE "gpio_td3"
#define CLASS_TYPE  "interface"
#define DEVICE_NAME "gpio_td3"

/* Direcciones FÍSICAS y Offsets (Igual que antes) */
#define CTRL_MODULE 0x44E10000
#define CTRL_MODULE_SIZE 0x2000
#define CTRL_MODULE_L1_PIN 0x8a4
#define CTRL_MODULE_L2_PIN 0x8ac
#define CTRL_MODULE_L3_PIN 0x8b4
#define CTRL_MODULE_L4_PIN 0x8bc
#define CTRL_MODULE_LED_VERDE_PIN 0x8c4
#define CTRL_MODULE_LED_ROJO_PIN 0x8c8
#define CTRL_MODULE_BUZZER_PIN 0x8cc
#define CTRL_MODULE_C1_PIN 0x890
#define CTRL_MODULE_C2_PIN 0x894
#define CTRL_MODULE_C3_PIN 0x898
#define CTRL_MODULE_C4_PIN 0x89C

#define CM_PER 0x44e00000
#define CM_PER_SIZE 0x1000
#define CM_PER_GPIO2_CLKCTRL 0xb0
#define CM_PER_GPIO2_CLKCTRL_ENABLE 0x2
#define OPTFCLKEN_GPIO_2_GDBCLK_BIT (1 << 18)
#define CM_PER_L4LS_CLKSTCTRL 0x0
#define CLKACTIVITY_GPIO_2_GDBCLK_BIT (1 << 20)

#define GPIO2 0x481ac000
#define GPIO2_SIZE  0x1000
#define GPIO_OE 0x134
#define GPIO_DATAOUT 0x13c
#define GPIO_CLEARDATAOUT 0x190
#define GPIO_SETDATAOUT 0x194
#define GPIO_DATAIN 0x138
#define GPIO_SYSCONFIG 0x10
#define GPIO_SOFTRESET 0x2

/* Configuraciones Pin Muxing */
#define CONF_PINMUX_GPIO    0x7
#define CONF_RXACTIVE       (0 << 5)
#define CONF_PULLUDEN       (0 << 3)
#define PIN_CONF    (CONF_PINMUX_GPIO | CONF_RXACTIVE | CONF_PULLUDEN)

#define CONF_MODE_GPIO_IN     0x7
#define CONF_RXACTIVE_IN      (1 << 5)
#define CONF_PUTYPESEL_IN     (0 << 4)
#define CONF_PULLUDEN_IN      (0 << 3)

/* Máscaras de bits */
#define L1_PIN (1 << 7)
#define L2_PIN (1 << 9)
#define L3_PIN (1 << 11)
#define L4_PIN (1 << 13)
#define LED_VERDE_PIN (1 << 15)
#define LED_ROJO_PIN (1 << 16)
#define BUZZER_PIN (1 << 17)
#define C1_PIN (1 << 2)
#define C2_PIN (1 << 3)
#define C3_PIN (1 << 4)
#define C4_PIN (1 << 5)

#define DEBOUNCE_MS 20
#define POLLING_MS  20 // Revisamos el teclado cada 20ms (50 veces por seg)

#define PULSE_TIME_MS 1000       // <--- FALTABA ESTO
#define LONG_PULSE_TIME_MS 2000  // <--- FALTABA ESTO

/* Direcciones VIRTUALES */
static void *cm_per_map;
static void *ctrl_module_map;
static void *gpio2_map;

/* Estados globales */
static bool gpio_td3_initialized = false;

/* Prototipos */
static int open(struct inode *, struct file *);
static ssize_t write(struct file *, const char __user *,size_t, loff_t*);
static ssize_t read(struct file *, char __user *, size_t, loff_t *);
static int close(struct inode *, struct file *);
static int probe(struct platform_device *);
static int remove(struct platform_device *);
static int init_driver(void);
static void exit_driver(void);
void set_pin(uint32_t, uint8_t);
char scan_keypad_4x4(void *gpio_base_addr, uint32_t datain_offset);

/* --- FUNCIONES DE HARDWARE --- */

void set_pin(uint32_t pins, uint8_t state){
    if(state) iowrite32 (pins, gpio2_map + GPIO_SETDATAOUT);
    else      iowrite32 (pins, gpio2_map + GPIO_CLEARDATAOUT);
}

char scan_keypad_4x4(void *gpio_base_addr, uint32_t datain_offset) {
    const char keypad_map[4][4] = {
        {'1', '2', '3', 'A'}, {'4', '5', '6', 'B'},
        {'7', '8', '9', 'C'}, {'*', '0', '#', 'D'}
    };
    const int row_pins[4] = {L1_PIN, L2_PIN, L3_PIN, L4_PIN};
    const int col_bits[4] = {2, 3, 4, 5};
    uint32_t estado_pines;
    int r, c;

    for (r = 0; r < 4; r++) {
        set_pin(row_pins[r], 1);
        // Pequeño delay de hardware para que la señal se estabilice
        // ndelay no duerme, pero es tan corto (nanosegundos) que no afecta
        ndelay(50); 
        estado_pines = ioread32(gpio_base_addr + datain_offset);
        set_pin(row_pins[r], 0);

        for (c = 0; c < 4; c++) {
            if ((estado_pines & (1U << col_bits[c])) != 0) {
                return keypad_map[r][c];
            }
        }
    }
    return '\0';
}

/* --- FUNCIÓN CLAVE MODIFICADA: USO DE JIFFIES Y SCHEDULE --- */

/**
 * obtener_codigo_teclado - Espera 5 teclas sin quemar CPU.
 * Retorna 0 si éxito, -ERESTARTSYS si fue interrumpido (Ctrl+C).
 */
int obtener_codigo_teclado(char *buffer, void *gpio_base_addr, uint32_t datain_offset) {
    int teclas_leidas = 0;
    char tecla_siendo_presionada = '\0';
    char tecla_actual;
    char tecla_confirmada;
    unsigned long timeout_jiffies; // Variable para calcular jiffies

    printk(KERN_INFO "Keypad: Ingrese codigo (Sleep Polling Mode)...\n");

    while (teclas_leidas < 5) {
        
        // 1. Verificar si el usuario presionó Ctrl+C
        if (signal_pending(current)) {
            printk(KERN_INFO "Keypad: Proceso interrumpido por usuario.\n");
            return -ERESTARTSYS;
        }

        // 2. Escaneo
        tecla_actual = scan_keypad_4x4(gpio_base_addr, datain_offset);

        if (tecla_actual != '\0') {
            if (tecla_actual != tecla_siendo_presionada) {
                
                // Debounce usando schedule_timeout en lugar de msleep
                // Dormimos DEBOUNCE_MS
                timeout_jiffies = msecs_to_jiffies(DEBOUNCE_MS);
                set_current_state(TASK_INTERRUPTIBLE);
                schedule_timeout(timeout_jiffies);

                tecla_confirmada = scan_keypad_4x4(gpio_base_addr, datain_offset);

                if (tecla_confirmada == tecla_actual) {
                    printk(KERN_INFO "Keypad: Tecla '%c'\n", tecla_actual);
                    buffer[teclas_leidas] = tecla_actual;
                    teclas_leidas++;
                    tecla_siendo_presionada = tecla_actual;
                }
            }
        } else {
            tecla_siendo_presionada = '\0';
        }

        /* * 3. EL TRUCO DE LOS JIFFIES PARA AHORRAR ENERGÍA 
         * En lugar de busy-wait, le decimos al scheduler:
         * "Sácame de la CPU durante POLLING_MS milisegundos".
         */
        
        // Calculamos cuántos jiffies corresponden a nuestros ms de espera
        timeout_jiffies = msecs_to_jiffies(POLLING_MS);
        
        // Cambiamos estado a INTERRUPTIBLE (para poder recibir Ctrl+C)
        set_current_state(TASK_INTERRUPTIBLE);
        
        // ¡Dormimos! El CPU se va a ejecutar otro proceso o a Idle.
        schedule_timeout(timeout_jiffies);
        
        // Al volver aquí, el tiempo ha pasado.
        
    } 

    buffer[5] = '\0';
    printk(KERN_INFO "Keypad: Codigo completo: %s\n", buffer);
    return 0; // Éxito
}

/* --- FILE OPERATIONS --- */

static struct cdev * char_device;
static struct file_operations my_device_ops = {
    .owner = THIS_MODULE,
    .open = open,
    .read = read,
    .release = close,
    .write = write,
};

static int open (struct inode * inode, struct file * file) {
    printk(KERN_INFO "gpio_td3: opened.\n");
    return 0;
}

static ssize_t write (struct file * file, const char __user * userbuff, size_t size, loff_t* offset) {
    static char recv_str[20]; 
    int len;

    if(!gpio_td3_initialized) return -EFAULT;

    if (size >= sizeof(recv_str)) len = sizeof(recv_str) - 1;
    else len = size;

    if (copy_from_user(recv_str, userbuff, len)) return -EFAULT;

    recv_str[len] = '\0';
    if (len > 0 && recv_str[len - 1] == '\n') recv_str[len - 1] = '\0';

    if (strcmp(recv_str, "Valido") == 0) {
        set_pin(LED_VERDE_PIN, 1);
        set_pin(BUZZER_PIN, 1); 
        // Usamos msleep (que usa jiffies internamente) para pausas largas
        msleep(PULSE_TIME_MS); 
        set_pin(LED_VERDE_PIN, 0);
        set_pin(BUZZER_PIN, 0);
    } else if (strcmp(recv_str, "Invalido") == 0) {
        set_pin(LED_ROJO_PIN, 1);
        set_pin(BUZZER_PIN, 1);
        msleep(PULSE_TIME_MS);
        set_pin(LED_ROJO_PIN, 0);
        set_pin(BUZZER_PIN, 0);
    } else if (strcmp(recv_str, "Actualizar") == 0) {
        set_pin(LED_ROJO_PIN | LED_VERDE_PIN | BUZZER_PIN, 1);
        msleep(LONG_PULSE_TIME_MS);
        set_pin(LED_ROJO_PIN | LED_VERDE_PIN | BUZZER_PIN, 0);
    }
    
    return size;
}

static ssize_t read (struct file * file, char __user * userbuff, size_t count, loff_t * offset) { 
    char codigo_ingresado[6];
    int ret;

    if (*offset > 0) return 0;

    // Llamamos a nuestra función modificada
    ret = obtener_codigo_teclado(codigo_ingresado, gpio2_map, GPIO_DATAIN);
    
    // Si la función retornó error (ej: Ctrl+C), salimos
    if (ret != 0) {
        return ret; 
    }

    if (copy_to_user(userbuff, codigo_ingresado, 6)) {
        return -EFAULT;
    }

    *offset += 6;
    return 6;
}

static int close (struct inode * inode, struct file * file) {  
    printk(KERN_INFO "gpio_td3: closed.\n");
    return 0;
}

static char * gpio_td3_devnode(struct device * dev, umode_t * mode){
    if (mode) *mode = 0666; 
    return NULL;
}

/* --- PLATFORM DRIVER --- */

static const struct of_device_id compatible_devices [] = {
    { .compatible = "ACME,gpio-td3-Crisafio"}, 
    {},
};
MODULE_DEVICE_TABLE(of,compatible_devices);

static struct platform_driver gpio_td3_driver = {
    .probe = probe,
    .remove = remove,
    .driver = {
        .name = "gpio_td3_Driver",
        .of_match_table = of_match_ptr(compatible_devices),
    },  
};

static int probe(struct platform_device * pdev){
    uint32_t reg;
    
    // Mapeos
    cm_per_map = ioremap(CM_PER, CM_PER_SIZE);
    gpio2_map = ioremap (GPIO2, GPIO2_SIZE);
    ctrl_module_map = ioremap (CTRL_MODULE, CTRL_MODULE_SIZE);
    
    if(!cm_per_map || !gpio2_map || !ctrl_module_map) return -1;

    // Clocks
    reg = ioread32(cm_per_map + CM_PER_L4LS_CLKSTCTRL);
    reg |= CLKACTIVITY_GPIO_2_GDBCLK_BIT;
    iowrite32(reg, cm_per_map + CM_PER_L4LS_CLKSTCTRL);
    iowrite32(CM_PER_GPIO2_CLKCTRL_ENABLE | OPTFCLKEN_GPIO_2_GDBCLK_BIT , cm_per_map + CM_PER_GPIO2_CLKCTRL);

    // Pin Mux
    iowrite32(PIN_CONF, ctrl_module_map + CTRL_MODULE_LED_ROJO_PIN);
    iowrite32(PIN_CONF, ctrl_module_map + CTRL_MODULE_LED_VERDE_PIN);
    iowrite32(PIN_CONF, ctrl_module_map + CTRL_MODULE_L1_PIN);
    iowrite32(PIN_CONF, ctrl_module_map + CTRL_MODULE_L2_PIN);
    iowrite32(PIN_CONF, ctrl_module_map + CTRL_MODULE_L3_PIN);
    iowrite32(PIN_CONF, ctrl_module_map + CTRL_MODULE_L4_PIN);
    iowrite32(PIN_CONF, ctrl_module_map + CTRL_MODULE_BUZZER_PIN);

    #define CONF_INPUT (CONF_MODE_GPIO_IN | CONF_RXACTIVE_IN | CONF_PUTYPESEL_IN | CONF_PULLUDEN_IN)
    iowrite32(CONF_INPUT, ctrl_module_map + CTRL_MODULE_C1_PIN);
    iowrite32(CONF_INPUT, ctrl_module_map + CTRL_MODULE_C2_PIN);
    iowrite32(CONF_INPUT, ctrl_module_map + CTRL_MODULE_C3_PIN);
    iowrite32(CONF_INPUT, ctrl_module_map + CTRL_MODULE_C4_PIN);

    // GPIO Config
    iowrite32(GPIO_SOFTRESET, gpio2_map + GPIO_SYSCONFIG);
    udelay(100);
    #define MASCARA_SALIDAS (LED_ROJO_PIN|LED_VERDE_PIN|L1_PIN|L2_PIN|L3_PIN|L4_PIN|BUZZER_PIN)
    iowrite32(~((uint32_t)MASCARA_SALIDAS), gpio2_map + GPIO_OE);
    iowrite32(MASCARA_SALIDAS, gpio2_map + GPIO_CLEARDATAOUT);

    gpio_td3_initialized = true;
    printk(KERN_INFO "gpio_td3: Probe OK. Polling con Schedule Timeout.\n");
    return 0;
}

static int remove(struct platform_device * pdev){    
    iounmap(cm_per_map);
    iounmap(gpio2_map);
    iounmap(ctrl_module_map);
    return 0;
}

/* --- INIT/EXIT --- */

static dev_t dev_number;
static struct class * device_class;
static struct device * device_sys;

static int init_driver(void)
{
    alloc_chrdev_region(&dev_number, BASE_MINOR, MINOR_COUNT, DEVICE_TYPE);
    char_device = cdev_alloc();
    char_device->ops = &my_device_ops;
    char_device->owner = THIS_MODULE;
    char_device->dev = dev_number;
    cdev_add(char_device, dev_number, MINOR_COUNT);
    device_class = class_create(THIS_MODULE, CLASS_TYPE);
    device_class -> devnode = gpio_td3_devnode;
    device_sys = device_create(device_class, NULL, dev_number , NULL, "gpio_td3");
    platform_driver_register(&gpio_td3_driver);
    return 0;
}

static void exit_driver(void){
    platform_driver_unregister(&gpio_td3_driver);
    device_destroy(device_class, dev_number);
    class_destroy(device_class);
    cdev_del(char_device);
    unregister_chrdev_region(dev_number, MINOR_COUNT);
}

module_init(init_driver);
module_exit(exit_driver);