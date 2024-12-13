SERVER = atcc.sys-backup-ui
CLIENT = atcc.sys-backup-msg
 
TARGETS = $(CLIENT) $(SERVER)
 
SOURCE_COMMON = $(wildcard ./common/*.c)
SOURCE_SERVER = $(SOURCE_COMMON) $(wildcard ./atcc.sys-backup-ui/*.c)
SOURCE_CLIENT = $(SOURCE_COMMON) $(wildcard ./atcc.sys-backup-msg/*.c)
OBJ_SERVER = $(patsubst %.c, %.o, $(SOURCE_SERVER))
OBJ_CLIENT = $(patsubst %.c, %.o, $(SOURCE_CLIENT))
INCLUDE_COMMON = -I./common/
CFLAGS = -Wall -c
#CC = gcc
all: $(TARGETS)
$(SERVER): $(OBJ_SERVER)
	@mkdir -p bin/
	$(CC) $(OBJ_SERVER) -lpthread -o bin/$(SERVER)
$(CLIENT): $(OBJ_CLIENT)
	@mkdir -p bin/
	$(CC) $(OBJ_CLIENT) -o bin/$(CLIENT)
%.o: %.c
	$(CC) $(INCLUDE_COMMON) $(CFLAGS) $< -o $@
.PHONY: clean
clean:
	rm -rf $(OBJ_SERVER) $(OBJ_CLIENT) bin/
