
CLASSPATH = servlet.jar

JAVAFLAGS = -deprecation -encoding iso-8859-1

JAVAC = javac

SRCDIR = ../src

MODULEDIR = ../../modules

all : chilimoon_module.jar chilimoon_servlet.jar compile_modules

chilimoon_servlet.jar : servlet_classes
	jar cf $@ com/chilimoon/servlet/*.class

servlet_classes : $(SRCDIR)/com/chilimoon/servlet/*.java
	CLASSPATH=$(CLASSPATH) $(JAVAC) $(JAVAFLAGS) $^ -d .

chilimoon_module.jar : module_classes
	jar cf $@ com/chilimoon/chilimoon/*.class

module_classes : $(SRCDIR)/com/chilimoon/chilimoon/*.java
	CLASSPATH=$(CLASSPATH) $(JAVAC) $(JAVAFLAGS) $^ -d .

compile_modules: chilimoon_module.jar 
	CLASSPATH=chilimoon_module.jar find $(MODULEDIR) -name '*.java' \
		-exec $(JAVAC) $(JAVAFLAGS) {} \;
