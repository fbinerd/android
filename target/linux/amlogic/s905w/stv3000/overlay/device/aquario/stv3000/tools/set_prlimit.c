#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/resource.h>

int main(int argc, char **argv) {
    struct rlimit limit;
    pid_t pid;

    if (argc != 3) {
        fprintf(stderr, "usage: %s PID BYTES\n", argv[0]);
        return 2;
    }

    pid = (pid_t)strtol(argv[1], NULL, 10);
    limit.rlim_cur = limit.rlim_max = (rlim_t)strtoull(argv[2], NULL, 10);
    if (prlimit(pid, RLIMIT_MEMLOCK, &limit, NULL) != 0) {
        perror("prlimit");
        return errno ? errno : 1;
    }
    return 0;
}
