#include <stdlib.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include "uri/uri.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
        char *buf = calloc(size, sizeof(char*));
        if (!buf)
                return 0;
        strncpy(buf, (char*)data, size);
        buf[size] = '\0';
        struct uri uri;
        uri_parse(&uri, buf);
        free(buf);

        return 0;
}
