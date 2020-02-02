#ifndef C_OPENSSL_BRIDGE_H
#define C_OPENSSL_BRIDGE_H

#include <openssl/crypto.h>
#include <stdint.h>

void bridge_openssl_free(char *buffer) { OPENSSL_free(buffer); }
void bridge_openssl_free_unsigned(uint8_t *buffer) { OPENSSL_free(buffer); }
uint8_t *bridge_openssl_malloc(size_t num) { return OPENSSL_malloc(num); }

#endif
