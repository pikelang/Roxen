/*
 * A throttling pipe connection
 * by Francesco Chemolli
 * (C) 1999 Idonex AB.
 *
 * Hm... storing the stuff to send in a string might lead to problems on 
 * ftp-servers. Will have to be changed. Also, reading stuff from disk 
 * on demand might be very interesting to save memory and increase 
 * performance. We'll see.
 */

constant cvs_version="$Id";

#ifdef THROTTLING_DEBUG
#undef THROTTLING_DEBUG
#define THROTTLING_DEBUG(X) perror("Throttling: "+X+"\n")
#else
#define THROTTLING_DEBUG(X)
#endif

private object(Stdio.File) outfd=0; //assigned by output
private string tosend="";
private function done_callback;
private array(mixed) done_callback_args;
private int sent=0;

private object throttler=0;
//this object will take care of the per-virtual-server throttling
//will be assigned by assign_throttler if needed.

//throttling related stuff
private int last_write=0; //time of the last write operation
private int writing_starttime=0;
private int bucket=0x7fffffff;
private int fill_rate=0; //if != 0, we're throttling
private int max_depth=0;


//API functions

//return the number of sent bytes
int bytes_sent() {
  return sent;
}

//set the fileobject to write to. Also start the writing process up
void output (object(Stdio.File) fd) {
  THROTTLING_DEBUG("slwpipe: output to "+fd->query_address());
  outfd=fd;
  last_write=writing_starttime=time(1);
  fd->set_nonblocking(0,write_some,0);
  call_out(check_for_closing,10);
}

//add a fileobject to the write-queue
//different semantics from smartpipe: input is read immediately and not
//when sending the results. Will use more memory (and save FDs), we can
//change this at a later moment
void input (object what, int len) {
  if (len<0)
    len=0x7fffffff;
  tosend+=what->read(len);
}

//add a string to the write-queue
void write(string what) {
  tosend+=what;
}

//the name says it all
void set_done_callback(function|void f, void|mixed ... args) {
  done_callback=f;
  done_callback_args=args;
}

//extra API functions
void throttle (int rate, int depth, int initial) {
  THROTTLING_DEBUG("slowpipe: throttle. rate="+rate+", depth="+depth+
                   ", initial="+initial);
  fill_rate=rate;
  max_depth=depth;
  bucket=initial;
}

void assign_throttler(void|object throttler_object) {
  THROTTLING_DEBUG("slowpipe: assign_throttler");
  throttler=throttler_object;
}

//internals

//write callback
private void write_some () {
  int towrite;
  //have we finished?
  if (strlen(tosend)<=0) {
    finish();
    return;
  }

  //are we throttling?
  if (!fill_rate) {
    towrite=0xfffffff;
  } else {
    //let's fill the bucket up
    int now=time(1);
    bucket+=(now-last_write)*fill_rate;
    if (bucket>max_depth)
      bucket=max_depth;
    last_write=now;

    //check: if we can't write, let's simulate a delay in the callback
    if (bucket<=0) {
      THROTTLING_DEBUG("slowpipe: write some delaying for "
                       +outfd->query_address());
      call_out(write_some,1);
      return;
    }
    towrite=bucket;
  }
  THROTTLING_DEBUG("slowpipe: write_some, trying to write "+towrite+" bytes");
  if (!throttler)
    finally_write(towrite);
  else
    throttler->request(towrite,finally_write);
}

void finally_write(int howmuch) {
  THROTTLING_DEBUG("slowpipe: finally_write. howmuch="+howmuch);
  int written;
  //actual write
  written=outfd->write( tosend[..howmuch-1] );
  THROTTLING_DEBUG("slowpipe: actually wrote "+written);
  if (written==-1) {
    finish();
    return;
  }
  sent+=written;
  if (fill_rate)
    bucket -= written;
  tosend=tosend[written..];
  if (throttler && howmuch != written )
    throttler->report_unused(howmuch-written);
}


void check_for_closing()
{
  THROTTLING_DEBUG("slowpipe: check_for_closing "+
                   (outfd?outfd->query_address():"unknown")
                   );
  if(!outfd || !outfd->query_address()) {
#ifdef FD_DEBUG
    write("Detected closed FD. Self-Destructing.\n");
#endif
    finish();
  } else
    call_out(check_for_closing, 10);
}

void finish() {
  int delta=time(1)-writing_starttime;
  THROTTLING_DEBUG("slowpipe: cleaning up and leaving ("+
                   delta+" sec, "+(sent?(sent/delta):0)+" bps)");;
  if (outfd) {
    outfd->set_blocking();
    outfd=0;
  }
  tosend=0;
  remove_call_out(check_for_closing);
  if (done_callback)
    done_callback(@done_callback_args);
  destruct(this_object());
}
