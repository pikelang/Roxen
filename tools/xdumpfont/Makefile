all: xdumpfont readfont

CC=gcc
CFLAGS=-O


xdumpfont:  xdumpfont.o
	$(CC) $(CFLAGS) -o xdumpfont xdumpfont.o -lX11 -lsocket -lnsl

readfont:  readfont.o fontdemo.o
	$(CC) $(CFLAGS) -o readfont readfont.o fontdemo.o

banner: readfont.o banner.o
	$(CC) $(CFLAGS) -o banner readfont.o banner.o

readfont.o: readfont.h
fontdemo.o: readfont.h

fonts_made: xdumpfont
	pike makefonts.lpc; touch fonts_made

fonts: fonts_made
