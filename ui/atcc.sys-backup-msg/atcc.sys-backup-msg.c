#include <string.h>
#include <sys/un.h>
#include <sys/socket.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <ctype.h>
#include <unistd.h>
#include "common.h"

#define BUF_SIZE 10             /* Maximum size of messages exchanged between client and server */

int main(int argc, char **argv)
{
    struct sockaddr_un svaddr;
    int sfd;
    ssize_t numBytes;
    char resp[BUF_SIZE]={0};
    char msg[BUF_SIZE]={0};
    /*
    * Check for proper usage.
    */
    if (argc < 2 || strcmp(argv[1], "--help") == 0) {
         printf( "Usage: %s <status>\n", argv[0]);
         exit(EXIT_FAILURE);
    }
    /* Create client socket */
    if (get_prog_socket() == NULL)
    {
        perror("Create client socket path name fail ");
        exit(EXIT_FAILURE);
    }

    sfd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sfd == -1)
    {
        perror("socket fail ");
        exit(EXIT_FAILURE);
    }
  
    /* establish a connection to the server */
    memset(&svaddr, 0, sizeof(struct sockaddr_un));
    svaddr.sun_family = AF_UNIX;
    strncpy(svaddr.sun_path, get_prog_socket(), sizeof(svaddr.sun_path) - 1);
    strncpy(msg,argv[1],strlen(argv[1]));

    if (connect(sfd, (struct sockaddr *)&svaddr, sizeof(struct sockaddr_un))<0)
    {
	   perror("connect socket error");	
	   close(sfd);
	   exit(EXIT_FAILURE);
    }
    /* Send messages to server*/ 
    if (send(sfd, msg, BUF_SIZE,0) <0)
    {
        perror("write to server error !");
	close(sfd);
	exit(EXIT_FAILURE);
    }
  
    /*timeout*//*
    struct timeval timeout;
    timeout.tv_sec = 5;  //set timeout 5 secs
    timeout.tv_usec = 0;
    setsockopt(sfd, SOL_SOCKET, SO_RCVTIMEO, (const char *)&timeout, sizeof(timeout));
    */

    numBytes = recv(sfd, resp,BUF_SIZE,0);
    if (numBytes < 0)
    {
	if (errno == EAGAIN || errno == EWOULDBLOCK) {    
	    perror("client recv() timeout");
	}
	else
            perror("client recv() failed");
           
    }
    else if (numBytes == 0)
    {
        printf("The server closed the connection\n");
          
    }
    close(sfd);
    exit(EXIT_SUCCESS);
}

