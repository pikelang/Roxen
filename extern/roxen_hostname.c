/*
#if 0
>  Better documentation of hostname lookup processes

Ah. Yes, I can include a short summary here:

The protocol: Roxen-->Hostname process:

<int(base 8):len> <char:direction> <char[len]:name>

Direction:
 'H' == HOST_TO_IP
 'I' == IP_TO_HOST

Example:

7Hfoo.org
^^ ^
| \ \
|  \ \__"len" characters.
|   |  
|   host-to-ip
len

Translation: Give me the ip-number for the host foo.org.

Another example:

16I130.236.253.11

Translation: Give me the hostname for the ip-number 130.236.253.11


The response is also quite simple:

<char:direction> <(base 10)(4 characters):len-from> <char[len-from]:from> <int(base 10)(4 characters):len-to> <char[len-to]:to>

So, the responce to the first reqyest would probably be:
H0007foo.org0000

Notice that the 'to' string is of zero length. This is an
'host-not-found' error :-)

The responce to the second request would be

H0014130.236.253.110018www.lysator.liu.se

I know that the protocol is very ugly, unsymetrical and odd.
Thats life.

It should be redesigned. That would not be all that hard, really.
#endif
*/

#include <stdio.h>
/*#include <string.h>*/
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>

#ifndef AF_INET
# error AF_INET not defined.
#endif

#ifdef HAVE_MALLOC_H
# include <malloc.h>
#endif

char *get_string(int len)
{
  char *buf;
  int i, c;
  buf=(char*)malloc(len+1);
  if (!buf) abort();
  for (i=0; i<len; i++) {
    c=getchar();
    if(c==EOF) exit(0); 
    buf[i]=c;
  }
  buf[len]=0;
  return buf;
}

char *host_to_ip(char *host)
{
  struct hostent *he;
  static char buf[64];

  he=gethostbyname(host);
  if (!he) return NULL;
  sprintf(buf,"%u.%u.%u.%u",
	  (unsigned char)he->h_addr_list[0][0],
	  (unsigned char)he->h_addr_list[0][1],
	  (unsigned char)he->h_addr_list[0][2],
	  (unsigned char)he->h_addr_list[0][3]);
  return buf;
}

const char *ip_to_host(char *host)
{
  unsigned long addr;
  struct hostent *he;
  addr=inet_addr(host);
  he=gethostbyaddr((void *)&addr, 4, AF_INET);
  if(!he) return NULL;
  return he->h_name;
}


int main(int ac,char **am)
{
  int i,c;
  char *str;
  const char *res;
  for (;;)
  {
    i=0;
    for (;;)
    {
      if((c=getchar())==EOF) exit(0);
      if (c>='0' && c<='7')
      {
	i=(i<<3)+(c-'0'); 
      } else {
	break;
      }
    }
    /* c=='H' => hostname -> ip */
    /* c=='I' => ip -> hostname */

    str=get_string(i);
    if (c=='I') 
      res=ip_to_host(str);
    else 
      res=host_to_ip(str);
    if (!res)
      printf("%c%04d%s0000",c,i,str);
    else
      printf("%c%04d%s%04d%s",c,i,str,strlen(res),res);
    free(str);
    fflush(stdout);
  }
}
