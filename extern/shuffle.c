
/* Shuffle data from A to B. 
 * -------------------------
 * SOLARIS ONLY CURRENTLY
 *
 * This file use solaris threads and mmapped io for maximum 
 * performance. It could be used as an freaked up 'cp' command..
 *
 * It can only be used with Solaris 2.4 and up. 
 * (Yes, I know, not exactly portable.) 
 *
 * This file is part of the Roxen WWW server, but is not in any
 * way nessesary to run it. To use this one, do 'make
 * shuffle-install'. This should have been done automatically if you
 * run Solaris.
 */



/* Bugfixed by Michael Widenius:
   
One problem is that the current shuffle module (on solairs) has two bugs:

- Sometimes there could be a raise condition between two threads
  and thr_suspend and thr_continue.  I changed shuffle to use
  cond_wait instead.
- If one requested a file bigger then 8 k then the mmapped variable
  was set and all following cgi:s gives 'document contains no data'.
  This is also fixed in the following new shuffle.c:
  (Sorry, I lost the original so I can't send a patch-file)

Yours, Michael Widenius

*/


#define _REENTRANT


#include <stdio.h>
#include <stdlib.h>
#include <thread.h>
#include <synch.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>
#ifdef HAVE_SYS_MMAN_H
# include <sys/mman.h>
#else
#ifdef HAVE_LINUX_MMAN_H
# include <linux/mman.h>
#endif
#endif
#include <sys/socket.h>
#include <sys/uio.h>

#include <sys/sockio.h>
#include <sys/conf.h>
#include <stropts.h>

#undef DEBUG

#ifdef DEBUG
FILE *debug;
#define dbg(X,y,z) do{fprintf(debug, "%d/ "X,thr_self(),(y),(z));fflush(debug);}while(0)
#else
#define dbg(X,y,z)
#endif

/* Global variable.. Could be used for some status info, perhaps?
 * At the moment it is used when the shuffler should exit. It won't until all
 * threads are done (all data is written to the clients, or client aborted)
 * This is somewhat misnamed, since it is the number of _active_ threads.
 */
int numthreads; 

/* A linked list of free (non-active) threads */
struct workqueue {
  void  *fromto;
  cond_t cond;
  struct workqueue *next;
} *queue_head = NULL;

mutex_t queue_lock;

inline int file_size(int fd)
{
  struct stat tmp;
  if(!fstat(fd, &tmp)) return tmp.st_size;
  return -1;
}

/* my_write and my_read is somewhat nicer than the ones built into the system.
 * They won't give up, unless the client really abort, or the source is empty. 
 */
inline int my_write(int to, char *buf, int towrite)
{
  int res=0;
  while(towrite)
  {
    while((res = write(to, buf, towrite)) < 0)
    {
      switch(errno)
      {
       case EAGAIN:
       case EINTR:
	thr_yield();
	continue;

       default:
	if(errno != EPIPE)
	  perror("Shuffle: While writing");
#ifdef DEBUG
	else
	  perror("Shuffle: DEBUG: While writing");
#endif
	res = 0;
	return 0;
      }
    }
    towrite -= res;
    buf += res;
  }
  return res;
}

inline int my_read(int from, char *buf, int towrite)
{
  int res;
  while((res = read(from, buf, towrite)) < 0)
  {
    switch(errno)
    {
    case EAGAIN:
      sleep(0);

    case EINTR:
      thr_yield();
      continue;

     default:
      perror("Shuffle: While reading");
      res = 0;
      return -1;
    }
  }
  return res;
}

/* Magic defines and ugly variable passing. Don't look.
 * This won't work if a pointer is smaller than 32 bits, but it 
 * will work if an integer is 64, but the pointer only 32. The reverse is 
 * most definately true.
 *
 * This method will also fail utterly with fd's larger than 65535. Not very
 * likely, since you may only have 1024 on Solaris 2.5. 
 *
 * The only reason for this magic is that the tread start function 
 * takes an void pointer as the only argument, and I don't really want to 
 * malloc 16 bytes for each call to this function, and it looked like to
 * much trouble to maintain a list of free blocks on my own, especially in
 * a threaded environment...
 */

#define fromfd  (((int)fromto) >> 16)
#define tofd (((int)fromto) & 65535)

void *shuffle(void *fromto)
{
  int towrite, orig;
  char *buffer = NULL;
  struct workqueue *mq = NULL;


  dbg("New thread\n",0,0);

  while(1)
  {
    char *mmapped=NULL, 

    /* This will be -1 for non-file objects. */
    orig=towrite=file_size(fromfd);

    /* If the file is smaller than 8Kb we don't even consider mmap()
     * with friends. It is slower than read() and write(). 
     *
     * The turnaround point is really around 16Kb, but I only malloc() 8Kb,
     * so files smaller than 8Kb can be read in one read().
     */
    if(towrite > 8192)
    {
      int pos;
      dbg("File larger than 8Kb, using mmap()\n",0,0);

      /* Smaller files get higher priority. This should probably be
       * a somewhat smarter routine, with more priority levels.. 
       * Unlike process priority, thread priority is higher the higher the
       * value. Probably only to confuse me :-)
       */
      if(towrite > 65535) 
	thr_setprio(1, thr_self());
      else
	thr_setprio(2, thr_self());
      
      if((pos=lseek(fromfd, 0L, SEEK_CUR))==-1) {
	perror("Shuffle: lseek failed");
	mmapped = 0;
      } else if((mmapped = mmap(0, towrite, PROT_READ,
				MAP_SHARED|MAP_NORESERVE, fromfd, 0))
	 == MAP_FAILED)
      {
	perror("Shuffle: mmap failed");
	mmapped = 0;
      } else {
	close(fromfd);
#ifdef MADV_SEQUENTIAL
	/* This memory will only be accessed once, thus: */
	madvise(mmapped, towrite, MADV_SEQUENTIAL);
#endif
	/* This is the actual data moving... All in one line :-) */
	my_write(tofd, mmapped + pos, towrite - pos);
	munmap(mmapped, towrite);
      }
    }
    if(!mmapped)
    {
#ifdef DEBUG
      int sent=0, packs=0;
#endif      
      dbg("File not mmap()ed, using sub-optimal read() and write()\n",0,0);
      if(!buffer)
	buffer = malloc(8192);
      if(!buffer)
      {
	dbg("Failed: No memory\n",0,0);
	fprintf(stderr, "Shuffle: Out of memory while shuffling.\n");
	close(tofd);
	close(fromfd);
	goto idle;
      }

      while(1)
      {
	towrite = my_read(fromfd, buffer, 8192);
#ifdef DEBUG
	if(!towrite)
	  dbg("Read 0 bytes.\n",0,0);
	sent += towrite;
	packs++;
#endif

	if(towrite <= 0)
	{
#ifdef DEBUG
	  dbg("No more data available, %d bytes sent in %d packages.\n", sent, packs);
#endif
	  break;
	}
	if(my_write(tofd, buffer, towrite) <= 0)
	{
#ifdef DEBUG
	  dbg("Client closed, %d bytes sent in %d packages.\n", sent, packs);
#endif
	  break;
	}
      }
      free(buffer);
      buffer = NULL;
      close(fromfd);
    }
    close(tofd);
  idle:
    numthreads--;
    if(!mq)
    {
      mq = malloc(sizeof(struct workqueue));
      cond_init(&mq->cond,0,0);
    }
    dbg("Idling.\n",0,0);

    mutex_lock(&queue_lock);
    mq->next = queue_head;
    queue_head = mq;
    while (cond_wait(&mq->cond,&queue_lock) == EINTR); /* Wait for request */
    mutex_unlock(&queue_lock);
    fromto = mq->fromto;
    dbg("restarted on %d -> %d.\n",fromfd,tofd);
  }
}

/*
 * Start a thread (or reuse a old one) that will send
 * all data from the 'from' filedescriptor to the 'to' one.
 */
int send_data(int from, int to)
{
  thread_t foo_thread;
  int res;
  int args;
  args = (from << 16) + to; /* this limits the number of fds to 65535 */

  if(from <= 0 || to <= 0)
  {
    fprintf(stderr, "Shuffle: Illegal fd to send_data. (%d/%d)\n", from, to);
    return 0;
  }
  {
    int flags=fcntl(from,F_GETFD);
    if (flags == -1)
#ifdef DEBUG
      dbg("fctln F_GETFD returned error: %d\n",errno,0);
#else
    ;
#endif
    else
    {
      if (flags & (O_NDELAY | O_NONBLOCK))
      {
#ifdef DEBUG
	dbg("Resetting blocking of file id: %d  flag=%d\n",from,flags);
#endif
	if (fcntl(from,F_SETFD,(flags & ~ (O_NDELAY | O_NONBLOCK))) == -1)
#ifdef DEBUG
	  dbg("fctln F_SETD returned error: %d\n",errno,0);
#else
	;
#endif
      }
    }
  }
  if(queue_head)
  {
    cond_t *cond;
    mutex_lock(&queue_lock);
    cond= &queue_head->cond;
    queue_head->fromto = (void *)args;
    queue_head = queue_head->next;
    mutex_unlock(&queue_lock);
    if (!cond_signal(cond))
    {
      numthreads++;
      return 1;
    }
  }

  while((res=thr_create(NULL,0,shuffle,(void *)args,THR_DETACHED,&foo_thread)))
  {
    switch(res)
    {
     case EAGAIN:
      break;

     case ENOMEM:
      perror("Shuffle: While creating thread");
      break;

     default:
      perror("Shuffle: While creating thread");
      fprintf(stderr, "Aborting.\n");
      return 0;
    }
  }
  numthreads++;
  return 1;
}

/*
 * Exit the shuffler 
 */
void abort_it()
{
  int j=0;
  while(numthreads && ++j<150)
    sleep(2);
#ifdef DEBUG
  dbg("Aborting\n",0,0);
#endif
  exit(0);
}

/*
 * receive a filedescriptor from a different process.
 */
int receive_fd()
{
  struct strrecvfd tmp;
  while(ioctl(0, I_RECVFD, &tmp) == -1)
  {
    switch(errno)
    {
     case EIO:  case EBADF:  case ENOTSOCK:  case EINVAL: case ESTALE:
    case EBADMSG:
      abort_it();

     case EWOULDBLOCK: case EINTR: case ENOMEM: case ENOSR:
      continue;

    case EMFILE:
      perror("Unable to allocate another FD.\n");
      break;

     default:
      abort_it();
    }
  }
  return tmp.fd;
}


#ifdef DEBUG 
int link_cnt()
{
  struct workqueue *foo;
  int i=0;
  foo = queue_head;
  while(foo)
  {
    foo = foo->next;
    i++;
  }
  return i;
}
#endif

int main(int argc, char **argv)
{
  thr_setprio(99, thr_self());
#ifdef DEBUG
  fprintf(stderr, "Starting shuffle in debug mode.\n");
  
  debug = fopen("/tmp/shuffledebug","a");
  if(!debug) debug = stderr;
  dbg("\nStarting shuffle\n",0,0);
#endif  
  while(1)
  {
    send_data(receive_fd(), receive_fd());
#ifdef DEBUG
    dbg("Shuffle: %d active threads, %d free\n", numthreads, link_cnt());
#endif
  }
}
