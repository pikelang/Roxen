
CLASSPATH = servlet.jar

JAVAFLAGS = -deprecation -encoding iso-8859-1

JAVAC = javac

SRCDIR = ../src

all : roxen_module.jar roxen_servlet.jar

roxen_servlet.jar : servlet_classes
	jar cf $@ se/idonex/servlet/*.class

servlet_classes : $(SRCDIR)/se/idonex/servlet/*.java
	CLASSPATH=$(CLASSPATH) $(JAVAC) $(JAVAFLAGS) $^ -d .

roxen_module.jar : module_classes
	jar cf $@ se/idonex/roxen/*.class

module_classes : $(SRCDIR)/se/idonex/roxen/*.java
	CLASSPATH=$(CLASSPATH) $(JAVAC) $(JAVAFLAGS) $^ -d .
