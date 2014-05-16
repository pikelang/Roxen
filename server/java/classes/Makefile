
CLASSPATH = servlet.jar

JAVAFLAGS = -deprecation -encoding iso-8859-1

JAVAC = javac

SRCDIR = ../src

MODULEDIR = ../../modules
LOCALMODULEDIR = ../../../local/modules

all : roxen_module.jar roxen_servlet.jar compile_modules

roxen_servlet.jar : servlet_classes
	jar cf $@ com/roxen/servlet/*.class

servlet_classes : $(SRCDIR)/com/roxen/servlet/*.java
	CLASSPATH=$(CLASSPATH) $(JAVAC) $(JAVAFLAGS) $^ -d .

roxen_module.jar : module_classes
	jar cf $@ com/roxen/roxen/*.class

module_classes : $(SRCDIR)/com/roxen/roxen/*.java
	CLASSPATH=$(CLASSPATH) $(JAVAC) $(JAVAFLAGS) $^ -d .

compile_modules: roxen_module.jar 
	CLASSPATH=roxen_module.jar find $(MODULEDIR) -name '*.java' \
		-exec $(JAVAC) $(JAVAFLAGS) {} \;
	@test ! -d $(LOCALMODULEDIR) || \
		CLASSPATH=roxen_module.jar \
		find $(LOCALMODULEDIR) -name '*.java' \
		-exec $(JAVAC) $(JAVAFLAGS) {} \;

clean:
	-rm com/roxen/servlet/*.class roxen_module.jar roxen_servlet.jar
