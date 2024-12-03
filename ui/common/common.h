#ifndef COMMON_H
#define COMMON_H

#ifndef _GNU_SOURCE
#define _GNU_SOURCE 1
#endif

#define SOCKET_PROGRESS_DEFAULT  "atcc.sys-backup-prog"
#define BUF_SIZE 10             /* Maximum size of messages exchanged between client and server */
#define BACKUP_STATUS_VALUE  10



typedef enum {
        IDLE,
	INIT,
        START,
	FORMAT_USB,
        RUN,
	IN_PROCESS,        
        FAILURE,
	SUCCESS,
        DONE,
        FAILURE_DONE,     
} BACKUP_STATUS;
char *get_prog_socket(void);

#endif
