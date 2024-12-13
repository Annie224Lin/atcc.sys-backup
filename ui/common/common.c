#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "common.h"



char *SOCKET_PROGRESS_PATH = NULL;

char *get_prog_socket(void) {
        if (!SOCKET_PROGRESS_PATH || !strlen(SOCKET_PROGRESS_PATH)) {
                const char *tmpdir = getenv("TMPDIR");
                if (!tmpdir)
                        tmpdir = "/home";

                if (asprintf(&SOCKET_PROGRESS_PATH, "%s/%s", tmpdir, SOCKET_PROGRESS_DEFAULT) == -1)
                        return (char *)"/home/"SOCKET_PROGRESS_DEFAULT;
        }

        return SOCKET_PROGRESS_PATH;
}


