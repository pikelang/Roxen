

all: ntstartexe ntstartdll

ntstartexe:
	rntany devenv ntroxen.sln /build Release /project ntstart $(REBUILD)

ntstartdll:
	rntany devenv ntroxen.sln /build Release /project startdll $(REBUILD)

release: bump_version all

bump_version:
	./bump_ntstart_version
