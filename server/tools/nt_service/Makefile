# For use with sprshd.

LIBS=-llibcmt -lkernel32 -ladvapi32 -lshell32

all: roxen.exe

roxen.o: roxen.c roxen_service.h

roxen_service.o: roxen_service.c roxen_service.h

roxen.exe: roxen.o roxen_service.o
	$(CC) $(LDFLAGS) roxen.o roxen_service.o $(LIBS) -o roxen
