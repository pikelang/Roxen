
CLASSPATH = servlet.jar

JAVAFLAGS = -deprecation -encoding iso-8859-1

JAVAC = javac

SRCDIR = ../src

all : roxen_module.jar roxen_servlet.jar

roxen_servlet.jar : servlet_classes
	jar cf $@ com/roxen/servlet/*.class

servlet_classes : $(SRCDIR)/com/roxen/servlet/*.java
	CLASSPATH=$(CLASSPATH) $(JAVAC) $(JAVAFLAGS) $^ -d .

roxen_module.jar : module_classes
	jar cf $@ com/roxen/roxen/*.class

module_classes : $(SRCDIR)/com/roxen/roxen/*.java
	CLASSPATH=$(CLASSPATH) $(JAVAC) $(JAVAFLAGS) $^ -d .
