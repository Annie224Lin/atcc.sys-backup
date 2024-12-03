#include <string.h>
#include <sys/un.h>
#include <sys/socket.h>
#include <sys/epoll.h>
#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <ctype.h>
#include "common.h"
#include <time.h> 
#include <unistd.h>
#include <pthread.h>
#include <fcntl.h>
#include "atcc.sys-backup-ui.h"

 
#define EPOLL_SIZE (100);
#define MAX_EVENTS (10)


pthread_mutex_t gUpdateMutex = PTHREAD_MUTEX_INITIALIZER;
time_t gProgressScopeTime = 0;
int background_is_ready = 0 ; 
struct BACKUP_STATUS_INFO  status_info ;
int is_running = 0 ;
int is_getstatus_ready = 0 ;
int progress_cnt= 0 ;

void setnonblocking(int fd) {
    int flag = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, flag | O_NONBLOCK);
}

int get_backup_status_info(struct BACKUP_STATUS_INFO* pInfo ,char * status )
{
    int get_status = 0 ;
    for (unsigned int i = 0; i<BACKUP_STATUS_VALUE; i++)
    {
            if (0 == strncmp(status_table[i].status_str,status ,strlen(status_table[i].status_str)))
        {
            memcpy(pInfo, &status_table[i], sizeof(struct BACKUP_STATUS_INFO));
                    get_status = 1 ;
            break;
        }
    }
    if (!get_status)
    {
            is_getstatus_ready = 0;
    }
    return get_status;
}

void ui_error()
{
    memset(&status_info,0,sizeof(struct BACKUP_STATUS_INFO));
    get_backup_status_info(&status_info , "FAILURE");
    return ;
}

void ui_set_text(const char * message)
{
    if (!background_is_ready)
		return ;      
    char cmd[CMD_LEN]={'\0'};;
    snprintf(cmd, sizeof(cmd), "%s %s %s","psplash-write \"MSG ", message,"\"" );
    if( -1 == system(cmd)){
        ui_error() ;
    }

    return ;

}

void ui_update_progress_bar()
{
    char cmd[CMD_LEN]={'\0'};;
    memset(cmd , 0 , sizeof(cmd));

    if (!background_is_ready)
                return ;

    snprintf(cmd, sizeof(cmd), "%s %d \"","psplash-write \"PROGRESS",status_info.bar_percent );
    pthread_mutex_trylock(&gUpdateMutex);
    if( -1 == system(cmd)){
	    ui_error() ;
    }
    pthread_mutex_unlock(&gUpdateMutex);

    return ;
}

#if 0
time_t gProgressScopeDuration = 60*10 ;  //assume totoal time is 10 mins
void ui_update_progress_bar(unsigned  int elapsed)
{
   
    float  percent = 0 ;
    char cmd[CMD_LEN]={'\0'};;    
    memset(cmd , 0 , sizeof(cmd));
    if (!background_is_ready)
		return ;
    if (msg.status == IDLE || msg.status == FAILURE) 
	    percent=ProgressBarEmpty ;
    else if (msg.status ==  DONE) 
	    percent=ProgressBarFull ;
    else {
   
   // 	elapsed = difftime(time(NULL),gProgressScopeTime);
        percent = (float)elapsed/gProgressScopeDuration*100 ;
     }
     if (percent > 100 )
	{
		percent=100 ;
		printf("progress_bar has something wrong ,ercenc: %.2f%% \n" ,percent);
	}

     snprintf(cmd, sizeof(cmd), "%s %.2f \"","psplash-write \"PROGRESS",percent );
     system(cmd);
}
#endif

void ui_set_cleanall()
{
    if (!background_is_ready)
        return  ;
	
    char cmd[CMD_LEN]={'\0'};
    snprintf(cmd, sizeof(cmd), "%s","psplash-write \"QUIT\"" );	 
    if( -1 == system(cmd)){
        ui_error() ;
    }     
    return ;
}

//if file exist , it means server is ready.
void create_init_status_file()
{
    FILE *fileP;
    char fileName[] = "/etc/.adv_init_done";   
    fileP = fopen(fileName, "r");
    if (fileP == NULL)
    {
        fileP = fopen(fileName, "w");
    }
    fclose(fileP);
}

void ui_set_background()
{    
    char cmd[CMD_LEN]={'\0'};
    switch (status_info.status) {
	case IDLE :
            background_is_ready = 1 ;
            snprintf(cmd, sizeof(cmd), "%s %s %s %s %s %s %s","psplash -i ", status_info.bitmap_str ,"-b", BACKGROUND_COLOR , "-t", TEXT_COLOR ,"&" );
            if( -1 == system(cmd)){
     		    ui_error() ;
            }	   
	    break;
	case INIT:
	    create_init_status_file();
	    break;
	case FAILURE:		
            ui_set_cleanall();
	    snprintf(cmd, sizeof(cmd), "%s %s %s %s %s %s %s","psplash -i ", status_info.bitmap_str ,"-b", BACKGROUND_COLOR, "-t", ERROR_TEXT_COLOR ,"&" );
	    if( -1 == system(cmd)){
     		    ui_error() ;
            }	
            break;
	case START:	    
	case FORMAT_USB:
	case RUN:
	case IN_PROCESS:		
	case SUCCESS:        
	case DONE:
    	case FAILURE_DONE:
	default :
		break;
    }
    return ;
} 

static void *progress_thread()
{
    unsigned int  elapsed = 0 ;
    char text[CMD_LEN]={0};
    int h = 0 ;
    int m = 0;
    int s = 0;
    int i = 0;

    for (;;) {
	if  (!is_getstatus_ready )
	{
	    break ;
	}
	pthread_mutex_trylock(&gUpdateMutex);
	// move the progress bar forward on timed intervals, if configured
	memset(text , 0 ,sizeof(text));
	if (status_info.status > 0 && status_info.status != FAILURE && status_info.status != FAILURE_DONE && is_running){	
	    elapsed = difftime(time(NULL),gProgressScopeTime);
            h= elapsed/3600;
            m= elapsed/60%60;
            s= elapsed%60;
	}
	else 
	{
	    h = m = s = 0;
	    gProgressScopeTime =time(NULL);
	} 
 	if  (status_info.status > 0 && status_info.status == FAILURE && is_running)
	{
		snprintf(text, sizeof(text),"%s",status_info.text_str);
		ui_set_text(text);
		sleep(2);
		snprintf(text, sizeof(text),"%s",status_info.text_str2);
                ui_set_text(text);
                sleep(2);

	}
	else
	{
		if (progress_cnt>=5) 
			progress_cnt=0 ;
		switch(progress_cnt) {
		   case 0:
        		snprintf(text, sizeof(text),"Cost time :%d:%d:%d.%s.",h,m,s,status_info.text_str);			   	 	      		      break;
                   case 1:
                        snprintf(text, sizeof(text),"Cost time :%d:%d:%d.%s..",h,m,s,status_info.text_str);
                        break;
                   case 2:
                        snprintf(text, sizeof(text),"Cost time :%d:%d:%d.%s...",h,m,s,status_info.text_str);
                        break;
		   case 3:	
		        snprintf(text, sizeof(text),"Cost time :%d:%d:%d.%s....",h,m,s,status_info.text_str);
                        break;
		   case 4:		   
                        snprintf(text, sizeof(text),"Cost time :%d:%d:%d.%s.....",h,m,s,status_info.text_str);
                        break;
		   default: 
			 snprintf(text, sizeof(text),"Cost time :%d:%d:%d.%s.....",h,m,s,status_info.text_str);
		        break;
		}
		ui_set_text(text);
		sleep(2);
		progress_cnt++;
	}
//	if ( status_info.status != IDLE && status_info.status != START && status_info.status != FAILURE && status_info.status != FAILURE_DONE && status_info.status != INIT)
//		sleep(1);

	pthread_mutex_unlock(&gUpdateMutex);    
    }    	
    pthread_exit(NULL);
    return NULL;
}


int main(int argc, char *argv[])
{
    struct sockaddr_un svaddr;
    struct sockaddr_un peer;
    int sfd ,sfd2;
    char msg[BUF_SIZE]={'\0'};
    ssize_t numBytes;    
    socklen_t addrlen = sizeof(peer);

    is_getstatus_ready = 1 ;   
    get_backup_status_info(&status_info , "IDLE");
    ui_set_background();	
    ui_update_progress_bar();
    gProgressScopeTime =time(NULL);

    pthread_t t;
    pthread_create(&t, NULL, progress_thread, NULL);

    /* Create server socket*/
    sfd = socket(AF_UNIX, SOCK_STREAM, 0); 
    if (sfd == -1){
        perror("create socket fail . Server is failed to receive ");
        exit(EXIT_FAILURE);
    }
    if (remove(get_prog_socket()) == -1 && errno != ENOENT){
         exit(EXIT_FAILURE);
    }
    
    memset(&svaddr, 0, sizeof(struct sockaddr_un));
    svaddr.sun_family = AF_UNIX;
    if (get_prog_socket()==NULL)
    {
       perror("create socket path name fail . Server is failed to receive ");
       exit(EXIT_FAILURE);

    }
    strncpy(svaddr.sun_path, get_prog_socket(), sizeof(svaddr.sun_path) - 1);

    int opt = 1;
    setsockopt(sfd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    setnonblocking(sfd);
 
    /* bind to unique pathname , and an entry is created in the file system directory. */  
    if (bind(sfd, (struct sockaddr *) &svaddr, sizeof(struct sockaddr_un)) == -1)
    {
        perror("bind socket fail . Server is failed to receive");
        exit(EXIT_FAILURE);
    }

    /* listen incoming client connections on the created socket */
    if (listen(sfd, 10) < 0)
    {
       perror("listen failed .  Server is failed to receive  ");
         
    }   
    /*connection establishment*/
    printf("Server is ready to receive !!\n");

    is_running = 1;
	 
    int epoll_size = EPOLL_SIZE;
    int efd = epoll_create(epoll_size);
    if (efd == -1) {
        perror("epoll create error");
        return -1;
    }
 
    struct epoll_event ev, events[MAX_EVENTS];
    ev.data.fd = sfd;
    ev.events = EPOLLIN ; //Level-triggered 
    //add server socket and event to epoll
    if (epoll_ctl(efd, EPOLL_CTL_ADD, sfd, &ev) == -1) {
        perror("epoll ctl ADD error");
        return -1;
    }
    
    int timeout = 1000; // 1 sec 
    while (1) {
	int nfds;
	do {
	    //Use epoll_wait to poll the fd in epoll to see if an event occurs, and then read it out for processing
	    //negative timeout value will make the function to wait until an event happens. If the timeout value is 0, then the function returns immediately with any sockets associated an IO event. if timeout value > 0 and block time > timeout value , return function and set nfds=0
	    nfds = epoll_wait(efd, events, MAX_EVENTS, timeout) ;   
	} while (nfds < 0 && errno == EINTR);

        if (nfds == 0) {
            continue;
   	}
        for (int i = 0; i < nfds; i++) {
            int fd = events[i].data.fd;
            //printf("events[%d] events:%08x\n", i, events[i].events);
	    if (fd == sfd) { 
		// When a client connects, the server obtains the client's connection socket
                sfd2 = accept(sfd, (struct sockaddr *)&peer, &addrlen);
                if (sfd2 == -1) {
                    perror("accept error");
                    continue;
                }
                setnonblocking(sfd2);
                ev.data.fd = sfd2;
                ev.events = EPOLLIN;
		//add client socket to epoll
                if (epoll_ctl(efd, EPOLL_CTL_ADD, sfd2, &ev) == -1) {
                    perror("epoll ctl ADD new fd error");
                    close(sfd2);
                    continue;
                }
            } else { 
		 //Data arrives or the connection is closed
                if (events[i].events & EPOLLIN) {
                   //printf("fd:%d is readable\n", fd);
                   memset(msg, 0, BUF_SIZE);
                   unsigned int len = 0;
                   numBytes= recv(fd, msg , BUF_SIZE, 0);
                   if (numBytes == 0) {
                   	//printf("remove fd:%d\n", fd);
                   	epoll_ctl(efd, EPOLL_CTL_DEL, fd, NULL);
                        close(fd);
                        break;
                    } else if ((numBytes == -1) && ((errno == EINTR) || (errno == EAGAIN) || (errno == EWOULDBLOCK))) {
                        //printf("fd:%d recv errno:%d done\n", fd, errno);
                    	break;
                    } else if ((numBytes == -1) && !((errno == EINTR) || (errno == EAGAIN) || (errno == EWOULDBLOCK))) {
                        //printf("remove fd:%d errno:%d\n", fd, errno);
                        epoll_ctl(efd, EPOLL_CTL_DEL, fd, NULL);
                        close(fd);
                        break;
                    }else {
                        //printf("read buffer:%d , msg=%s\n", numBytes ,msg);
                        len = numBytes;
                	memset(&status_info,0,sizeof(struct BACKUP_STATUS_INFO));
                        if (send(fd, msg, BUF_SIZE, 0) < 0)
                        {
                                perror("Could not send datagram!! \n");
                                ui_error();
                                break;
                        }
 			if (!get_backup_status_info(&status_info , msg))
                        {
                                ui_error();
                                break ;
                        }
        	        ui_set_background();
                 	ui_update_progress_bar();
                    }
          	 }
		
		if ((events[i].events & EPOLLERR) ||((events[i].events & EPOLLHUP))) {
                    printf("fd:%d error\n", fd);
		    break;
                }
            }
        }
        if (status_info.status == FAILURE )
        {
            ui_error();
            //wait for user press key , status become to DONE.
            continue;
        }

        if (status_info.status == DONE || status_info.status ==  FAILURE_DONE )
            break;


    }

    is_running =0 ;
    pthread_join(t, NULL);	

    /*closes open socket descriptor*/
    close(sfd);
    close(sfd2);

    /*removes the UNIX path name from the file system*/
    remove(get_prog_socket());
    printf("finish ui server\n");      
    return 0 ;
}

