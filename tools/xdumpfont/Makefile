all: xdumpfont readfont

CC=gcc
CFLAGS=-g -O9 -mv8 -funroll-loops -pipe -I/usr/openwin/include 


xdumpfont:  xdumpfont.o
	gcc -pipe -L/usr/openwin/lib -R/usr/openwin/lib -mv8 -O9 -g -o xdumpfont xdumpfont.o -lX11

purexdumpfont: xdumpfont.o
	purify gcc -pipe -L/usr/openwin/lib -R/usr/openwin/lib -mv8 -O9 -g -o purexdumpfont xdumpfont.o -lX11

readfont:  readfont.o fontdemo.o
	gcc -mv8 -pipe -g -o readfont readfont.o fontdemo.o

banner: readfont.o banner.o
	gcc -mv8 -pipe -g -o banner readfont.o banner.o

readfont.o: readfont.h
fontdemo.o: readfont.h

fonts_made: xdumpfont
	ulpc makefonts.lpc; touch fonts_made

fonts: fonts_made