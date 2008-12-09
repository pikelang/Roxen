@echo off
echo %~dp0 | "%~dp0..\pike\bin\pike" -e "string dir = Stdio.stdin.read(); string pipe = combine_path(replace(dir, \":\", \"_\"), \"../../../configurations/_mysql/pipe\"); Stdio.write_file(\"mysql_pipe.txt\", pipe);"

set /p MYSQL_PIPE= < mysql_pipe.txt
del mysql_pipe.txt

"%~dp0..\mysql\bin\mysql" -urw --pipe --socket="%MYSQL_PIPE%"
