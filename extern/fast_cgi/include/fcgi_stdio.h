/* 
 * fcgi_stdio.h --
 *
 *      FastCGI-stdio compatibility package
 *
 *
 * Copyright (c) 1996 Open Market, Inc.
 *
 * See the file "LICENSE.TERMS" for information on usage and redistribution
 * of this file, and for a DISCLAIMER OF ALL WARRANTIES.
 *
 * $Id: fcgi_stdio.h,v 1.1.1.1 1996/11/11 23:31:40 per Exp $
 */

#ifndef _FCGI_STDIO
#define _FCGI_STDIO 1

#include <stdio.h>
#include <sys/types.h>
#include "fcgiapp.h"

#if defined (c_plusplus) || defined (__cplusplus)
extern "C" {
#endif

/*
 * Wrapper type for FILE
 */

typedef struct {
    FILE *stdio_stream;
    FCGX_Stream *fcgx_stream;
} FCGI_FILE;

/*
 * The four new functions and two new macros
 */

int FCGI_Accept(void);
void FCGI_Finish(void);
int FCGI_StartFilterData(void);
void FCGI_SetExitStatus(int status);

#define FCGI_ToFILE(fcgi_file) (fcgi_file->stdio_stream)
#define FCGI_ToFcgiStream(fcgi_file) (fcgi_file->fcgx_stream)

/*
 * Wrapper stdin, stdout, and stderr variables, set up by FCGI_Accept()
 */

extern	FCGI_FILE	_fcgi_sF[];
#define FCGI_stdin	(&_fcgi_sF[0])
#define FCGI_stdout	(&_fcgi_sF[1])
#define FCGI_stderr	(&_fcgi_sF[2])

/*
 * Wrapper function prototypes, grouped according to sections
 * of Harbison & Steele, "C: A Reference Manual," fourth edition,
 * Prentice-Hall, 1995.
 */

void FCGI_perror(const char *str);

FCGI_FILE *FCGI_fopen(const char *path, const char *mode);
int        FCGI_fclose(FCGI_FILE *fp);
int        FCGI_fflush(FCGI_FILE *fp);
FCGI_FILE *FCGI_freopen(const char *path, const char *mode, FCGI_FILE *fp);

int        FCGI_setvbuf(FCGI_FILE *fp, char *buf, int bufmode, size_t size);
void       FCGI_setbuf(FCGI_FILE *fp, char *buf);

int        FCGI_fseek(FCGI_FILE *fp, long offset, int whence);
int        FCGI_ftell(FCGI_FILE *fp);
void       FCGI_rewind(FCGI_FILE *fp);
#ifdef HAVE_FPOS
int        FCGI_fgetpos(FCGI_FILE *fp, fpos_t *pos);
int        FCGI_fsetpos(FCGI_FILE *fp, const fpos_t *pos);
#endif
int        FCGI_fgetc(FCGI_FILE *fp);
int        FCGI_getchar(void);
int        FCGI_ungetc(int c, FCGI_FILE *fp);

char      *FCGI_fgets(char *str, int size, FCGI_FILE *fp);
char      *FCGI_gets(char *str);

/*
 * Not yet implemented
 *
 * int        FCGI_fscanf(FCGI_FILE *fp, const char *format, ...);
 * int        FCGI_scanf(const char *format, ...);
 *
 */

int        FCGI_fputc(int c, FCGI_FILE *fp);
int        FCGI_putchar(int c);

int        FCGI_fputs(const char *str, FCGI_FILE *fp);
int        FCGI_puts(const char *str);

int        FCGI_fprintf(FCGI_FILE *fp, const char *format, ...);
int        FCGI_printf(const char *format, ...);

int        FCGI_vfprintf(FCGI_FILE *fp, const char *format, va_list ap);
int        FCGI_vprintf(const char *format, va_list ap);

size_t     FCGI_fread(void *ptr, size_t size, size_t nmemb, FCGI_FILE *fp);
size_t     FCGI_fwrite(void *ptr, size_t size, size_t nmemb, FCGI_FILE *fp);

int        FCGI_feof(FCGI_FILE *fp);
int        FCGI_ferror(FCGI_FILE *fp);
void       FCGI_clearerr(FCGI_FILE *fp);

int        FCGI_fileno(FCGI_FILE *fp);
FCGI_FILE *FCGI_fdopen(int fd, const char *mode);
FCGI_FILE *FCGI_popen(const char *cmd, const char *type);
int        FCGI_pclose(FCGI_FILE *);

/*
 * The remaining definitions are for application programs,
 * not for fcgi_stdio.c
 */

#ifndef NO_FCGI_DEFINES

/*
 * Replace standard types, variables, and functions with FastCGI wrappers.
 * Use undef in case a macro is already defined.
 */

#undef  FILE
#define	FILE     FCGI_FILE

#undef  stdin
#define	stdin    FCGI_stdin
#undef  stdout
#define	stdout   FCGI_stdout
#undef  stderr
#define	stderr   FCGI_stderr

#undef  perror
#define	perror   FCGI_perror

#undef  fopen
#define	fopen    FCGI_fopen
#undef  fclose
#define	fclose   FCGI_fclose
#undef  fflush
#define	fflush   FCGI_fflush
#undef  freopen
#define	freopen  FCGI_freopen

#undef  setvbuf
#define	setvbuf  FCGI_setvbuf
#undef  setbuf
#define	setbuf   FCGI_setbuf

#undef  fseek
#define fseek    FCGI_fseek
#undef  ftell
#define ftell    FCGI_ftell
#undef  rewind
#define rewind   FCGI_rewind
#undef  fgetpos
#define fgetpos  FCGI_fgetpos
#undef  fsetpos
#define fsetpos  FCGI_fsetpos

#undef  fgetc
#define	fgetc    FCGI_fgetc
#undef  getc
#define getc     FCGI_fgetc
#undef  getchar
#define	getchar  FCGI_getchar
#undef  ungetc
#define ungetc   FCGI_ungetc

#undef  fgets
#define fgets    FCGI_fgets
#undef  gets
#define	gets     FCGI_gets

#undef  fputc
#define fputc    FCGI_fputc
#undef  putc
#define putc     FCGI_fputc
#undef  putchar
#define	putchar  FCGI_putchar

#undef  fputs
#define	fputs    FCGI_fputs
#undef  puts
#define	puts     FCGI_puts

#undef  fprintf
#define	fprintf  FCGI_fprintf
#undef  printf
#define	printf   FCGI_printf

#undef  vfprintf
#define vfprintf FCGI_vfprintf
#undef  vprintf
#define vprintf  FCGI_vprintf

#undef  fread
#define	fread    FCGI_fread
#undef  fwrite
#define fwrite   FCGI_fwrite

#undef  feof
#define	feof     FCGI_feof
#undef  ferror
#define ferror   FCGI_ferror
#undef  clearerr
#define	clearerr FCGI_clearerr

#undef  fileno
#define fileno   FCGI_fileno
#undef  fdopen
#define fdopen   FCGI_fdopen
#undef  popen
#define popen    FCGI_popen
#undef  pclose
#define	pclose   FCGI_pclose

#endif /* NO_FCGI_DEFINES */

#if defined (__cplusplus) || defined (c_plusplus)
} /* terminate extern "C" { */
#endif

#endif /* _FCGI_STDIO */

