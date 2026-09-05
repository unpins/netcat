/* b64_ntop for libcs that don't have one.
 *
 * It is a BIND/libresolv extension: glibc and the BSDs declare it in
 * <resolv.h>, musl and cosmopolitan do not, and nc's socks.c is the only
 * caller -- Basic auth for an HTTP CONNECT proxy (-X connect -x host -P user).
 * Without it the static-musl build stops at socks.c with an implicit
 * declaration, which is what kept this package on GNU netcat.
 *
 * Defined under our own name and reached through the macro, so the platforms
 * that DO declare b64_ntop see one definition rather than a clashing second.
 *
 * RFC 4648 base64, no line breaks. Returns the encoded length, or -1 when the
 * target cannot hold the string plus its NUL. Verified identical to glibc's
 * b64_ntop over 9800 random inputs of length 0..48, and against the RFC 4648
 * test vectors.
 */
#ifndef UNPIN_B64_H
#define UNPIN_B64_H

#include <stddef.h>

static int
unpin_b64_ntop(const char *src, size_t srclen, char *target, size_t targsize)
{
    static const char b64[] =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    const unsigned char *s = (const unsigned char *)src;
    size_t need = ((srclen + 2) / 3) * 4;
    size_t i, o = 0;

    if (need + 1 > targsize)
        return -1;
    for (i = 0; i + 2 < srclen; i += 3) {
        target[o++] = b64[s[i] >> 2];
        target[o++] = b64[((s[i] & 0x03) << 4) | (s[i + 1] >> 4)];
        target[o++] = b64[((s[i + 1] & 0x0f) << 2) | (s[i + 2] >> 6)];
        target[o++] = b64[s[i + 2] & 0x3f];
    }
    if (i < srclen) {
        target[o++] = b64[s[i] >> 2];
        if (i + 1 < srclen) {
            target[o++] = b64[((s[i] & 0x03) << 4) | (s[i + 1] >> 4)];
            target[o++] = b64[(s[i + 1] & 0x0f) << 2];
        } else {
            target[o++] = b64[(s[i] & 0x03) << 4];
            target[o++] = '=';
        }
        target[o++] = '=';
    }
    target[o] = '\0';
    return (int)o;
}

#define b64_ntop unpin_b64_ntop

#endif /* UNPIN_B64_H */
