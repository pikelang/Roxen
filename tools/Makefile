# For gcc
CC= gcc
# For ANSI compilers
#CC= cc

#For Optimization
#CFLAGS= -O2
#For debugging
CFLAGS= -g
# For SCO ODT
#EXTRA_LIBS= -lcrypt_i

RM= /bin/rm -f
#--- You shouldn't have to edit anything else. ---

.c.o: 
	$(CC) -c $(CFLAGS) $<

all: htpasswd 

aux: $(OBJS)
	make all CC=gcc CFLAGS=-O2

aix3: $(OBJS)
	make all CC=gcc

aix4: $(OBJS)
	make all CC=gcc

sunos: $(OBJS)
	make all CC=gcc

solaris: $(OBJS)
	make all CC=gcc
hp-gcc: $(OBJS)
	make all CC=gcc

hp-cc:
	make all CC=cc CFLAGS=-Ae

sgi4: $(OBJS)
	make all CC=cc CFLAGS=-DHEAD_GETPASS

sgi5: $(OBJS)
	make all CC=cc

decmips: $(OBJS)
	make all CC=cc

decaxp: $(OBJS)
	make all CC=cc

netbsd: $(OBJS)
	make all CC=cc EXTRA_LIBS=-lcrypt

linux: $(OBJS)
	make all CC=gcc

svr4: $(OBJS)
	make all CC=cc

htpasswd: htpasswd.c
	$(CC) $(CFLAGS) htpasswd.c -o htpasswd $(EXTRA_LIBS)

clean:
	rm -f htpasswd

