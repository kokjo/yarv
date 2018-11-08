#include <stdint.h>
#include <stdbool.h>

// a pointer to this is a null pointer, but the compiler does not
// know that because "sram" is a linker symbol from sections.lds.
extern uint32_t sram;

#define reg_gpio_do   (*(volatile uint32_t*)0x03000000)
#define reg_gpio_di   (*(volatile uint32_t*)0x03000000)
#define reg_gpio_oe   (*(volatile uint32_t*)0x03000004)
#define reg_gpio_alt  (*(volatile uint32_t*)0x03000008)

extern uint32_t _sidata, _sdata, _edata, _sbss, _ebss,_heap_start;

void main() {
    // zero out .bss section
    for (uint32_t *dest = &_sbss; dest < &_ebss;) {
        *dest++ = 0;
    }

    // blink the user LED
    uint32_t led_timer = 0;
       
    reg_gpio_oe = 0x00000001;

    while (1) {
        reg_gpio_do = (led_timer >> 12) & 1;
        led_timer = led_timer + 1;
    } 
}
