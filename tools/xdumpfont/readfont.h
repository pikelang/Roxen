#ifndef _SYS_TYPES_H
#include <sys/types.h>
#endif
#ifndef _NETINET_IN_H
#include <netinet/in.h>
#endif

typedef struct {
  int width, spacing;
  unsigned char *data;
} Char;

typedef struct {
  ulong version;
  ulong numchars;
  ulong height;
  ulong baseline;
  Char *c;

/* Internal use only. */
  void *handle;
  int size;
} Font;


Font *OpenFont(char *filename);
void CloseFont(Font *font);

#define FONT_FILE_VERSION 1

