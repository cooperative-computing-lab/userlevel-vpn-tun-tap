// gcc -Wall -fPIC -shared -o keep_privileges.so keep_privileges.c

// Needed for includes to add RTLD_NEXT:
#define _GNU_SOURCE

#include <sys/types.h>
#include <unistd.h>
#include <dlfcn.h>
#include <stdarg.h>
#include <sys/ioctl.h>
#include <linux/if_tun.h>


typedef int (*ioctl_t)(int fd, unsigned long request, ...);

int ioctl(int fd, unsigned long request, ...) {
    va_list ap;
    va_start(ap, request);
    void *arg = NULL;

    if(request == TUNSETOWNER) {
        return 0;
    }

    arg = va_arg(ap, void *);
    return ((ioctl_t) dlsym(RTLD_NEXT, "ioctl"))(fd, request, arg);
}

int setgid(gid_t gid) {
    return 0;
}

int setuid(uid_t uid) {
    return 0;
}

int setgroups(size_t size, const gid_t *list) {
    return 0;
}




