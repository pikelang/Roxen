# For use with sprshd.
#
# $Id: Makefile,v 1.3 2000/08/02 18:21:46 mast Exp $

LIBS=-llibcmt -lkernel32 -ladvapi32 -lshell32

all: roxen.exe

roxen.o: roxen.c roxen_service.h

roxen_service.o: roxen_service.c roxen_service.h

roxen.res: roxen.rc ../../roxen.ico
	$(RM) roxen.ico
	cp ../../roxen.ico .
	rntany rc /foroxen.res roxen.rc

roxen.exe: roxen.o roxen_service.o roxen.res
	$(CC) $(LDFLAGS) roxen.o roxen_service.o $(LIBS) roxen.res -o roxen

clean:
	$(RM) roxen roxen.exe roxen.ico roxen.res roxen.o roxen_service.o
