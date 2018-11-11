#include <stdint.h>
#include <stdbool.h>

// a pointer to this is a null pointer, but the compiler does not
// know that because "sram" is a linker symbol from sections.lds.
extern uint32_t sram;

#define reg_spi_cfg  (*(volatile uint32_t*)0x02000000)
#define reg_uart_div (*(volatile uint32_t*)0x02000004)
#define reg_uart_dat (*(volatile uint32_t*)0x02000008)

#define reg_gpio_do  (*(volatile uint32_t*)0x03000000)
#define reg_gpio_di  (*(volatile uint32_t*)0x03000000)
#define reg_gpio_oe  (*(volatile uint32_t*)0x03000004)
#define reg_gpio_alt (*(volatile uint32_t*)0x03000008)

extern uint32_t _sidata, _sdata, _edata, _sbss, _ebss,_heap_start;

void put_char(char c){
    reg_uart_dat = ((uint32_t) c) & 0xff;
}

void put_str(char *s){
    while(*s) put_char(*(s++));
}

void main() {
    // zero out .bss section
    for (uint32_t *dest = &_sbss; dest < &_ebss;) {
        *dest++ = 0;
    }

    // blink the user LED
    uint32_t led_timer = 0;
    reg_uart_div = 139;
       
//    reg_spi_cfg = (reg_spi_cfg & ~0x007F0000) | 0x00400000;
    reg_gpio_oe = 0x00000001;
    reg_gpio_alt = (1 << 4) | (1 << 3);

    put_str("Hello, World!\n");

    asm("fence");
    while (1) {
        reg_gpio_do = (led_timer  >> 16) & 1;
        led_timer = led_timer + 1;
    } 
}
