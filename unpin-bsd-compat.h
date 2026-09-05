/* The Linux-only spellings the Debian port of OpenBSD nc uses, for a libc
 * that has none of them -- macOS.
 *
 * SOCK_CLOEXEC / SOCK_NONBLOCK (socket flags, Linux 2.6.27) and accept4() do
 * not exist there, and the port reaches for all three: netcat.c opens its
 * connect socket with SOCK_NONBLOCK, its unix sockets with SOCK_CLOEXEC, and
 * accepts with accept4(). The flags carry real behaviour -- a blocking connect
 * socket would break the -w timeout -- so they are re-implemented with the
 * fcntl() calls that predate them, not defined away to 0.
 *
 * IPTOS_LOWCOST is the other gap: macOS defines IPTOS_LOWDELAY, so the port's
 * own fallback block is skipped, and defines no IPTOS_LOWCOST for the -T
 * keyword table to name.
 *
 * Include AFTER <sys/socket.h> -- socket() and accept4() become macros here.
 */
#ifndef UNPIN_BSD_COMPAT_H
#define UNPIN_BSD_COMPAT_H

#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <unistd.h>

#ifndef SOCK_CLOEXEC
/* Bits no socket type uses, so they survive the OR and are masked back out. */
#define UNPIN_SOCK_CLOEXEC  0x10000000
#define UNPIN_SOCK_NONBLOCK 0x20000000
#define SOCK_CLOEXEC  UNPIN_SOCK_CLOEXEC
#define SOCK_NONBLOCK UNPIN_SOCK_NONBLOCK

static int
unpin_setfl(int fd, int flags)
{
    int fl, e;

    if (fd < 0)
        return fd;
    if ((flags & UNPIN_SOCK_CLOEXEC) && fcntl(fd, F_SETFD, FD_CLOEXEC) == -1)
        goto bad;
    if (flags & UNPIN_SOCK_NONBLOCK) {
        if ((fl = fcntl(fd, F_GETFL, 0)) == -1
            || fcntl(fd, F_SETFL, fl | O_NONBLOCK) == -1)
            goto bad;
    }
    return fd;
bad:
    e = errno;
    close(fd);
    errno = e;
    return -1;
}

static int
unpin_socket(int domain, int type, int protocol)
{
    int flags = type & (UNPIN_SOCK_CLOEXEC | UNPIN_SOCK_NONBLOCK);

    return unpin_setfl(socket(domain, type & ~flags, protocol), flags);
}

static int
unpin_accept4(int s, struct sockaddr *addr, socklen_t *addrlen, int flags)
{
    return unpin_setfl(accept(s, addr, addrlen), flags);
}

/* After the definitions above, so those still call the real ones. */
#define socket(d, t, p)     unpin_socket((d), (t), (p))
#define accept4(s, a, l, f) unpin_accept4((s), (a), (l), (f))
#endif /* SOCK_CLOEXEC */

/* The cosmopolitan target builds without libbsd at all (it does not compile
 * there, and cosmo's libc already carries most of what nc wants from it:
 * strlcpy, strlcat, explicit_bzero, readpassphrase). These two it does not
 * carry, and they are what is left of <bsd/stdlib.h>. */
#ifdef UNPIN_NO_LIBBSD
/* cosmo keeps these under its own tree rather than in <string.h>/<stdio.h>. */
#include <libc/str/str.h>
#include <libc/stdio/readpassphrase.h>
#include <limits.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <sys/random.h>

/* OpenBSD strtonum: a whole-string integer parse with a range, reporting the
 * reason through *errstrp rather than errno. Returns 0 on any error. */
static long long
unpin_strtonum(const char *numstr, long long minval, long long maxval,
    const char **errstrp)
{
    long long ll = 0;
    char *ep;
    int e = errno;

    if (errstrp != NULL)
        *errstrp = NULL;
    if (minval > maxval) {
        if (errstrp != NULL)
            *errstrp = "invalid";
        return 0;
    }
    errno = 0;
    ll = strtoll(numstr, &ep, 10);
    if (numstr == ep || *ep != '\0') {
        if (errstrp != NULL)
            *errstrp = "invalid";
        ll = 0;
    } else if ((ll == LLONG_MIN && errno == ERANGE) || ll < minval) {
        if (errstrp != NULL)
            *errstrp = "too small";
        ll = 0;
    } else if ((ll == LLONG_MAX && errno == ERANGE) || ll > maxval) {
        if (errstrp != NULL)
            *errstrp = "too large";
        ll = 0;
    }
    errno = e;
    return ll;
}
#define strtonum(s, lo, hi, e) unpin_strtonum((s), (lo), (hi), (e))

/* arc4random_uniform: unbiased value in [0, upper_bound). nc uses it in one
 * place, to shuffle the port list for -r. Rejection sampling on getrandom(),
 * which cosmo provides on every OS it runs on; a failure there is fatal rather
 * than quietly falling back to something weaker. */
static uint32_t
unpin_arc4random_uniform(uint32_t upper_bound)
{
    uint32_t r, min;

    if (upper_bound < 2)
        return 0;
    min = -upper_bound % upper_bound;
    for (;;) {
        if (getrandom(&r, sizeof r, 0) != (ssize_t)sizeof r)
            err(1, "getrandom");
        if (r >= min)
            return r % upper_bound;
    }
}
#define arc4random_uniform(n) unpin_arc4random_uniform((n))
#endif /* UNPIN_NO_LIBBSD */

/* Cosmopolitan has no <arpa/telnet.h>. nc uses exactly five of its constants,
 * all in atelnet() -- the RFC 854 WILL/WONT DO/DONT answer behind -t. */
#ifndef IAC
#define IAC  255
#define DONT 254
#define DO   253
#define WONT 252
#define WILL 251
#endif

#ifndef IPTOS_LOWCOST
#define IPTOS_LOWCOST 0x02
#endif

/* RFC 791 precedence, for the -T keyword table. The port defines the DSCP and
 * the type-of-service names when they are missing, but not these three. */
#ifndef IPTOS_PREC_NETCONTROL
#define IPTOS_PREC_NETCONTROL      0xe0
#endif
#ifndef IPTOS_PREC_INTERNETCONTROL
#define IPTOS_PREC_INTERNETCONTROL 0xc0
#endif
#ifndef IPTOS_PREC_CRITIC_ECP
#define IPTOS_PREC_CRITIC_ECP      0xa0
#endif
#ifndef IPTOS_MINCOST
#define IPTOS_MINCOST IPTOS_LOWCOST
#endif

#endif /* UNPIN_BSD_COMPAT_H */
