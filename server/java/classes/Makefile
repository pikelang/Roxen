
CLASSPATH = servlet.jar

# Java SE release to compile for.
JAVASE = 8

JAVAFLAGS = -deprecation -encoding iso-8859-1 --release $(JAVASE)

JAVAC = /usr/local/jdk1.2/bin/javac

SRCDIR = ../src

roxen_servlet.jar : servlet_classes
	jar cf $@ se/idonex/servlet/*.class

servlet_classes : $(SRCDIR)/se/idonex/servlet/*.java
	CLASSPATH=$(CLASSPATH) $(JAVAC) $(JAVAFLAGS) $^ -d .

