

all: ntstartexe ntstartdll

ntstartexe:
	rntany msdev ntroxen.dsw -MAKE "ntstart - Release" $(REBUILD)

ntstartdll:
	rntany msdev ntroxen.dsw -MAKE "startdll - Release" $(REBUILD)

release: bump_version all

bump_version:
	./bump_ntstart_version