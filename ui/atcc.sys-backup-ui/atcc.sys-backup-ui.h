#ifndef ATCC_SYS_BACKUP_UI_H
#define ATCC_SYS_BACKUP_UI_H

#define BACKGROUND_COLOR "0x000a30"
//#define TEXT_COLOR  "0x6d6d70"
#define TEXT_COLOR  "0xffffff"
#define ERROR_TEXT_COLOR "0xff0000"
#define CMD_LEN 160

struct BACKUP_STATUS_INFO
{
         BACKUP_STATUS status ;
         const char status_str[16];
         const char bitmap_str[32];
         const char text_str[128];
	 const char text_str2[128];
         const unsigned int bar_percent ;
}backup_info;

struct BACKUP_STATUS_INFO  status_table[] = {
        {
                IDLE,
                "IDLE",
                "/res/images/backup.bmp",
                "checking disk.Do not shut down.",
		"",
		0,
        },{
                INIT,
                "INIT",
                "/res/images/backup.bmp",
                "Checking disk.Do not shut down.",
		"",
                0,
        },{
                START,
                "START",
                "/res/images/backup.bmp",
                "Now start backing up system.Do not shut down.",
		"",
		10,

        },{
                FORMAT_USB,
                "FORMAT_USB",
                "/res/images/backup.bmp",
                "Format USB drive right now.",	
		"",
		20,
        },{
                RUN,
                "RUN",
                "/res/images/backup.bmp",
                "Copy system data.Do not shut down." ,
		"",
		30,
        },{
                IN_PROCESS,
                "IN_PROCESS",
                "/res/images/backup.bmp",
                "Backup files on USB drive.Do not shut down.",
		"",
		60,
        },{
                FAILURE,
                "FAILURE",
                "/res/images/backup.bmp",
		"OH!there is something wrong.The backup system was canceled.",
		"Please press any key or wait ten seconds to reboot.Countdown is in progress..",
		0,

        },{
                SUCCESS,
                "SUCCESS",
                "/res/images/backup.bmp",
                "The backup system operation is almost complete.",
		"",
		90,
        },{
                DONE,
                "DONE",
                "/res/images/backup.bmp",
                "Backup system files is ready.Reboot the system now. ", //DONE
		"",
		100,
        },{
                FAILURE_DONE,
                "FAILURE_DONE",
                "/res/images/backup.bmp",
                "Reboot the system now. ", 
		"",
		0,

        },


};
#endif
