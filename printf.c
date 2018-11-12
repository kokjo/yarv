#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdarg.h>

#include "printf.h"

const char hexchars[] = "0123456789ABCDEF";

void va_printf(struct output *out, char const *fmtstr, va_list va){
    int escape = 0;
    unsigned int size = 0;
    unsigned int i;
    unsigned int num;
    unsigned char *str;

#ifdef ENABLE_PERCENT_D
    char digit_buffer[16];
#endif

    while(*fmtstr){
        if(escape){
            escape = 0;
            switch(*fmtstr){
                case '%':
                    out->out(out, '%');
                    break;
                case 's':
                    str = va_arg(va, unsigned char *);
                    for(i = 0; str[i]; i++) out->out(out, str[i]);
                    break;
                case 'h':
                    size = size >> 1;
                    escape = 1;
                    break;
                case 'p':
                    size = 4;
                    out->out(out, '0');
                    out->out(out, 'x');
                case 'x':
                    num = va_arg(va, unsigned int);
                    if(size == 4){
                        out->out(out, hexchars[(num >> 28) & 0xf]);
                        out->out(out, hexchars[(num >> 24) & 0xf]);
                        out->out(out, hexchars[(num >> 20) & 0xf]);
                        out->out(out, hexchars[(num >> 16) & 0xf]);
                        size = size >> 1;
                    }
                    if(size == 2){
                        out->out(out, hexchars[(num >> 12) & 0xf]);
                        out->out(out, hexchars[(num >> 8) & 0xf]);
                    }
                    out->out(out, hexchars[(num >> 4) & 0xf]);
                    out->out(out, hexchars[(num >> 0) & 0xf]);
                    break;
#ifdef ENABLE_PERCENT_D
                case 'd':
                    num = va_arg(va, unsigned int);
                    i = 0;
                    do{
                        digit_buffer[i++] = '0' + (num % 10);
                        num = num / 10;
                    } while(num);
                    while(i--){
                        out->out(out, digit_buffer[i]);
                    }
                    break;
#endif
#ifdef ENABLE_PERCENT_Z
                case 'z':
                    str = va_arg(va, unsigned char *);
                    unsigned int len = va_arg(va, unsigned int);
                    for (i = 0; i < len; i++) {
                        out->out(out, hexchars[(str[i] >> 4) & 0xf]);
                        out->out(out, hexchars[(str[i] >> 0) & 0xf]);
                    }
                    break;
#endif
            }
        } else if(*fmtstr == '%'){
            escape = 1;
            size = 4;
        } else {
            out->out(out, *fmtstr);
        }
        fmtstr += 1;
    }
}


void buffer_out(struct output *_s, char ch){
    struct buffer_output *s = (struct buffer_output *) _s;
    if(s->len) {
        *s->buf = ch;
        s->buf++;
        s->len--;
    }
}

int snprintf(char *buf, size_t len, char const *fmtstr, ...){
    struct buffer_output s = {
        .out = {
            .out = buffer_out,
        },
        .buf = buf,
        .len = len
    };
    va_list va;
    va_start(va, fmtstr);
    va_printf(&s.out, fmtstr, va);
    return len - s.len;
}

int sprintf(char *buf, char const *fmtstr, ...){
    struct buffer_output s = {
        .out = {
            .out = buffer_out,
        },
        .buf = buf,
        .len = SIZE_MAX
    };
    va_list va;
    va_start(va, fmtstr);
    va_printf(&s.out, fmtstr, va);
    return SIZE_MAX - s.len;

}
