/**********************************************************/
/* Controlador de GPIO para el Mini Web Server            */
/* (Modificado con límite de 10 logs)                     */
/**********************************************************/

// --- LIBRERÍAS ESTÁNDAR DE C ---
#include <stdio.h>      // Para printf, perror, fopen, NULL, etc.
#include <stdlib.h>     // Para exit, atoi (aunque no se usa aquí)
#include <string.h>     // Para strncpy, strlen, strstr, strcspn (manejo de strings)
#include <unistd.h>     // Para read, write, close, sleep (llamadas al sistema)
#include <time.h>       // Para la fecha y hora (time, localtime, strftime)
#include <fcntl.h>      // Para open() y flags (O_RDONLY, O_WRONLY)
#include <signal.h>     // Para signal, SIGINT (capturar Ctrl+C)

// --- LIBRERÍAS DE COMUNICACIÓN ENTRE PROCESOS (IPC) ---
#include <sys/ipc.h>    // Para ftok, semget, semop (Funciones IPC de System V)
#include <sys/sem.h>    // Para struct sembuf (operaciones de semáforo)
#include <sys/types.h>  // Para key_t (tipo de dato de la llave)
#include <errno.h>      // Para perror (mostrar errores del sistema)

// --- Definiciones de archivos y semáforo ---
// *** VÍNCULO ***: El archivo de datos compartido con servidor.c
#define HTML_FILE   "datos_http.txt" 
// Archivo temporal usado solo por este proceso
#define TEMP_FILE   "datos_http.tmp" 
// *** VÍNCULO ***: El archivo de dispositivo para hablar con gpio-td3-driver.c
#define DRIVER_FILE "/dev/gpio_td3"  

// Llave para el semáforo. DEBE SER IDÉNTICA a la de servidor.c
// *** VÍNCULO ***: Esta es la "dirección" del semáforo que servidor.c creó.
#define SEM_KEY_PATH "."
#define SEM_KEY_ID   'S'

// --- Prototipos de funciones (declaraciones) ---
// Le dice al compilador que estas funciones existen y serán definidas más abajo.
void sem_wait(int semid); // Operación P (wait/bajar)
void sem_post(int semid); // Operación V (post/subir)
int buscar_en_validos(int semid, const char* codigo);
void loguear_intento(int semid, const char* codigo, int es_valido);
void handle_sigint(int sig); // Handler de Ctrl+C

// --- FUNCIÓN PRINCIPAL ---
int main()
{
    // --- Declaración de variables locales ---
    int semid; // ID del semáforo (obtenido de semget)
    key_t key; // Llave (key_t) para el semáforo (obtenida de ftok)
    int fd_read, fd_write;  // Descriptores de archivo para el driver
    char buffer_leido[10];  // Buffer para leer NNNN* del driver
    char codigo_nnnn[5];    // Buffer para guardar solo los 4 dígitos
    int bytes_leidos;       // Resultado de la llamada read()
    int es_codigo_valido;   // Flag (0 o 1) para guardar el resultado

    // --- 1. Obtener el ID del semáforo existente ---
    
    // 1a. Generar la *misma* llave (key_t) que generó el servidor
    // ftok crea una llave única basada en un path y un ID.
    key = ftok(SEM_KEY_PATH, SEM_KEY_ID);
    if (key == -1) {
        // Si ftok falla (ej: el path no existe)
        perror("Error en ftok (asegúrese que está en la carpeta correcta)");
        return 1; // Salir con código de error
    }

    // 1b. Obtener el ID del semáforo.
    // *** VÍNCULO ***: NO usamos IPC_CREAT. Este proceso *espera* que el 
    // servidor.c ya lo haya creado.
    semid = semget(key, 1, 0666); 
    if (semid == -1) {
        // Si semget falla (el semáforo no existe)
        perror("Error en semget (¿El servidor principal está corriendo?)");
        return 1; // Salir con código de error
    }
    printf("Controlador conectado al Semáforo (id %d).\n", semid);

    // --- 2. Registrar el handler de Ctrl+C ---
    // Si el usuario presiona Ctrl+C (señal SIGINT), se llamará a la función handle_sigint
    signal(SIGINT, handle_sigint);
    printf("Controlador iniciado. Presione Ctrl+C para salir.\n");

    // --- 3. Bucle principal del controlador (infinito) ---
    while (1) // Bucle que se ejecuta para siempre
    {
        // 3a. Abrir y Leer desde el driver
        printf("\nEsperando código NNNN* desde %s...\n", DRIVER_FILE);
        // *** VÍNCULO ***: Abre el archivo /dev/gpio_td3
        fd_read = open(DRIVER_FILE, O_RDONLY);
        if (fd_read < 0) {
            perror("Error al abrir " DRIVER_FILE " para leer, reintentando");
            sleep(1); // Esperar 1s antes de reintentar
            continue; // Volver al inicio del while
        }

        // --- LLAMADA BLOQUEANTE ---
        // *** VÍNCULO ***: Llama a la función .read de gpio-td3-driver.c
        // El programa se detendrá (dormirá) en esta línea hasta que 
        // el driver (kernel) tenga 5 teclas y le envíe los datos.
        bytes_leidos = read(fd_read, buffer_leido, sizeof(buffer_leido) - 1);
        
        close(fd_read); // Cerrar el descriptor de lectura

        if (bytes_leidos < 0) {
            // Si la lectura da error
            perror("Error al leer desde el driver");
            continue; 
        }
        
        if (bytes_leidos == 0) {
            // Esto no debería pasar si el driver es bloqueante, pero es buena práctica
            printf("Error: read() devolvió 0 (EOF) inesperadamente.\n");
            sleep(1);
            continue; 
        }

        // 3b. Limpiar el buffer
        buffer_leido[bytes_leidos] = '\0'; // Poner el terminador nulo al final
        // Busca el primer \r o \n y lo reemplaza por \0
        buffer_leido[strcspn(buffer_leido, "\r\n")] = 0; 

        printf("Driver envió: '%s'\n", buffer_leido);

        // 3c. Validar formato NNNN*
        // Comprueba si la longitud es 5 Y el 5to caracter (índice 4) es '*'
        if (strlen(buffer_leido) != 5 || buffer_leido[4] != '*') {
            printf("Formato incorrecto (se esperaba NNNN*). Descartando.\n");
            continue; // Volver al inicio del while
        }

        // 3d. Extraer el código NNNN
        strncpy(codigo_nnnn, buffer_leido, 4); // Copiar los primeros 4 chars
        codigo_nnnn[4] = '\0'; // Asegurar terminador nulo

        // 3e. Buscar en el archivo (usando semáforo)
        // *** VÍNCULO ***: Llama a la función que lee datos_http.txt
        es_codigo_valido = buscar_en_validos(semid, codigo_nnnn);

        // 3f. Loguear el intento (Válido o Inválido)
        // *** VÍNCULO ***: Llama a la función que escribe en datos_http.txt
        loguear_intento(semid, codigo_nnnn, es_codigo_valido);

        // 3g. Escribir el resultado de vuelta al driver
        // *** VÍNCULO ***: Abre el archivo /dev/gpio_td3
        fd_write = open(DRIVER_FILE, O_WRONLY);
        if (fd_write < 0) {
            perror("Error al abrir " DRIVER_FILE " para escribir");
            continue; 
        }
        // si el codigo es VALIDO --> escribo "Valido" en /dev/gpio --> LED VERDE
        // si el codigo es INVALIDO --> escribo "Invalido" en /dev/gpio --> LED ROJO
        if (es_codigo_valido) {
            printf("Código '%s' VÁLIDO. Escribiendo 'Valido' en driver.\n", codigo_nnnn);
            // *** VÍNCULO ***: Llama a la función .write de gpio-td3-driver.c
            write(fd_write, "Valido\n", 7); 
        } else {
            printf("Código '%s' INVÁLIDO. Escribiendo 'Invalido' en driver.\n", codigo_nnnn);
            // *** VÍNCULO ***: Llama a la función .write de gpio-td3-driver.c
            write(fd_write, "Invalido\n", 9); 
        }
        
        close(fd_write); // Cerrar el descriptor de escritura
    } // Fin del while(1)

    // --- 4. Fin (Nunca se alcanza por el while(1)) ---
    printf("Controlador terminado.\n");
    return 0;
}

/**
 * Busca un código en la sección de "Validos" (primera tabla) de datos_http.txt
 */
int buscar_en_validos(int semid, const char* codigo)
{
    FILE *fp; // Puntero a archivo
    char lineBuffer[1024]; // Buffer para leer líneas
    char search_str[32];   // String a buscar (ej: "<td>1234</td>")
    int found = 0; // Flag de resultado (0 = no encontrado)
    int in_first_table = 0; // Flag para buscar solo en la primera tabla

    sprintf(search_str, "<td>%s</td>", codigo); // Prepara el string a buscar

    // --- INICIO Sección Crítica (Lectura) ---
    // *** VÍNCULO ***: Pide el semáforo. Si servidor.c lo tiene, se bloquea.
    printf("Buscando: Tomando semáforo...\n");
    sem_wait(semid); 

    fp = fopen(HTML_FILE, "r"); // Abrir archivo para leer
    if (fp == NULL) {
        perror("Error: No se pudo abrir datos_http.txt para buscar");
        sem_post(semid); // ¡Importante liberar el semáforo antes de salir!
        return 0; 
    }

    // Lee el archivo línea por línea
    while (fgets(lineBuffer, sizeof(lineBuffer), fp) != NULL) 
    {
        if (strstr(lineBuffer, "<table>")) { // Detecta inicio de tabla
            in_first_table = 1;
        }

        if (in_first_table) { // Si estamos en la primera tabla
            if (strstr(lineBuffer, search_str)) { // Buscar el código
                found = 1; // ¡Encontrado!
                break; // Salir del bucle
            }
        }

        if (strstr(lineBuffer, "</table>") && in_first_table) { // Fin de la 1ra tabla
            break;
        }
    }

    fclose(fp); // Cierra el archivo
    printf("Buscando: Liberando semáforo...\n");
    sem_post(semid); // Libera el semáforo
    // --- FIN Sección Crítica ---

    return found; // Devuelve 1 (encontrado) o 0 (no encontrado)
}

/**
 * Inserta una línea de log en la *segunda* tabla (Logs) de datos_http.txt
 * CON LÍMITE DE 10 REGISTROS (BORRA EL MÁS ANTIGUO)
 */
void loguear_intento(int semid, const char* codigo, int es_valido)
{
    char fecha_str[11]; // DD/MM/YYYY\0
    char hora_str[9];  // HH:MM:SS\0
    char new_log_line[256]; // Buffer para la nueva fila HTML
    // Operador ternario: si es_valido es 1, usa "Valido", si no, "Invalido"
    const char* estado_str = es_valido ? "Valido" : "Invalido"; 
    FILE *fp_orig, *fp_temp;
    char lineBuffer[2048]; // Buffer para leer/copiar líneas

    // --- 1. Obtener Fecha y Hora ---
    time_t now = time(NULL); // Obtener tiempo actual (segundos desde 1970)
    struct tm *t = localtime(&now); // Convertir a struct tm (fecha/hora local)
    strftime(fecha_str, sizeof(fecha_str), "%d/%m/%Y", t); // Formatear fecha
    strftime(hora_str, sizeof(hora_str), "%H:%M:%S", t); // Formatear hora

    // --- 2. Formatear la nueva línea de Log ---
    sprintf(new_log_line, "<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n", 
            fecha_str, hora_str, codigo, estado_str);

    // --- 3. Sección Crítica: Modificar datos_http.txt ---
    // *** VÍNCULO ***: Pide el semáforo. Si servidor.c lo tiene, se bloquea.
    printf("Logueando: Esperando semáforo para escribir el log...\n");
    sem_wait(semid); 
    printf("Logueando: Semáforo tomado. Modificando log en %s...\n", HTML_FILE);

    // --- PASO 1 (CONTAR): Contar registros existentes en la 2da tabla ---
    int registro_count = 0;
    int table_count = 0; // 0 = tabla 1 (códigos), 1 = tabla 2 (logs)
    fp_orig = fopen(HTML_FILE, "r");
    if (fp_orig == NULL) {
        perror("Error: No se pudo abrir datos_http.txt (para contar)");
        sem_post(semid); 
        return;
    }
    
    // Lee el archivo línea por línea
    while (fgets(lineBuffer, sizeof(lineBuffer), fp_orig) != NULL) 
    {
        if (strstr(lineBuffer, "</table>")) { // Detectar fin de tabla
            table_count++;
            continue; // Saltar esta línea e ir a la siguiente
        }
        
        // Si estamos en la 2da tabla (table_count == 1) y es una fila de datos
        if (table_count == 1 && strstr(lineBuffer, "<tr>") && strstr(lineBuffer, "<td>")) {
            registro_count++; // Incrementar contador
        }
    }
    fclose(fp_orig);
    printf("Registros existentes: %d\n", registro_count);

    // --- PASO 2 (CALCULAR): Calcular cuántos borrar ---
    int rows_to_skip = 0; // Filas a borrar
    if (registro_count >= 10) {
        // Si hay 10 o más, calculamos cuántas sobran + 1 (la nueva)
        rows_to_skip = (registro_count - 10) + 1;
    }
    printf("Se borrarán %d registros antiguos para mantener el límite de 10.\n", rows_to_skip);

    // --- PASO 3 (ESCRIBIR): Reescribir el archivo (borrando y agregando) ---
    // (Técnica de Archivo Temporal)
    fp_orig = fopen(HTML_FILE, "r"); // Volver a abrir para leer
    if (fp_orig == NULL) {
        perror("Error: No se pudo re-abrir datos_http.txt (para escribir)");
        sem_post(semid);
        return;
    }
    fp_temp = fopen(TEMP_FILE, "w"); // Abrir temporal para escribir
    if (fp_temp == NULL) {
        perror("Error: No se pudo crear el archivo temporal");
        fclose(fp_orig);
        sem_post(semid);
        return;
    }

    table_count = 0;
    int skipped_count = 0; // Cuántas filas hemos borrado (saltado)
    int inserted = 0;      // Si ya insertamos la nueva línea

    // Copiamos línea por línea de original a temporal
    while (fgets(lineBuffer, sizeof(lineBuffer), fp_orig) != NULL) 
    {
        // --- Lógica de borrado ---
        int is_log_section = (table_count == 1); // Estamos en la 2da tabla
        int is_data_row = (strstr(lineBuffer, "<tr>") && strstr(lineBuffer, "<td>"));

        // Si es una fila de log, y aún no hemos saltado las filas necesarias...
        if (is_log_section && is_data_row && (skipped_count < rows_to_skip)) 
        {
            skipped_count++;
            printf("Borrando registro antiguo %d/%d...\n", skipped_count, rows_to_skip);
            continue; // No escribir esta línea (la borra)
        }
        
        // --- Lógica de inserción ---
        if (!inserted && strstr(lineBuffer, "</table>") != NULL) 
        {
            table_count++;
            // Si es el fin de la 2da tabla (table_count == 2) y no hemos insertado...
            if (table_count == 2) 
            {
                fputs(new_log_line, fp_temp); // Escribir la NUEVA línea
                inserted = 1;
                printf("Nueva línea de log insertada.\n");
            }
        }
        
        fputs(lineBuffer, fp_temp); // Copiar la línea actual al temporal
    }

    fclose(fp_orig);
    fclose(fp_temp);

    // Reemplazar el archivo original con el temporal
    remove(HTML_FILE); // Borrar el viejo
    rename(TEMP_FILE, HTML_FILE); // Renombrar el nuevo

    printf("Logueo completo. Liberando semáforo.\n");
    sem_post(semid); // Liberar semáforo
    // --- Fin de la Sección Crítica ---
}


/**********************************************************/
/* Funciones de Semáforo (Copiadas del servidor)          */
/**********************************************************/

// Implementación de sem_wait (Operación P)
// antes de modificar el archivo se TOMA EL SEMAFORO, si esta ocupado espero (BLOQUEANTE)
void sem_wait(int semid)
{
    struct sembuf sops; // Estructura de operación de semáforo
    sops.sem_num = 0;  // Operar sobre el primer (y único) semáforo del set
    sops.sem_op = -1;  // Restar 1 al valor (esperar)
    sops.sem_flg = 0;  // Operación bloqueante (espera si el semáforo es 0)
    if (semop(semid, &sops, 1) == -1) { // Ejecutar la operación
        perror("Error en sem_wait (semop P)");
    }
}

// Implementación de sem_post (Operación V)
// LIBERA el semaforo
void sem_post(int semid)
{
    struct sembuf sops;
    sops.sem_num = 0; // Operar sobre el primer semáforo
    sops.sem_op = 1;  // Sumar 1 al valor (liberar)
    sops.sem_flg = 0; // Operación bloqueante
    if (semop(semid, &sops, 1) == -1) { // Ejecutar la operación
        perror("Error en sem_post (semop V)");
    }
}

/**********************************************************/
/* AÑADIDO: Handler para Ctrl+C (Sin cambios)             */
/**********************************************************/
// Se llama cuando el usuario presiona Ctrl+C en la terminal
void handle_sigint(int sig)
{
    printf("\nCtrl+C detectado. Cerrando el controlador...\n");
    // *** VÍNCULO ***: No necesita destruir el semáforo, ya que
    // servidor.c es el "dueño" y se encarga de esa tarea.
    exit(0); // Salir limpiamente
}
