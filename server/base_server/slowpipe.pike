// This file is part of Roxen WebServer.
// Copyright © 1999 - 2009, Roxen IS.
//
//
// A throttling pipe connection
//

// Hm... storing the stuff to send in a string might lead to problems on
// ftp-servers. Will have to be changed. Also, reading stuff from disk
// on demand might be very interesting to save memory and increase
// performance. We'll see.

constant cvs_version="$Id$";

#ifdef THROTTLING_DEBUG
#undef THROTTLING_DEBUG
#define THROTTLING_DEBUG(X) if(file_len>0x6fffffff)report_debug("slowpipe: "+X+"\n")
#else
#define THROTTLING_DEBUG(X)
#endif
private mapping status = ([]);
private Stdio.File outfd=0; //assigned by output
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
private int initial_bucket=0;
private string host;


//API functions

//return the number of sent bytes
int bytes_sent() {
  return sent;
}

//set the fileobject to write to. Also start the writing process up
void output (Stdio.File fd) {
  THROTTLING_DEBUG("output to "+fd->query_address());
  catch(host = (fd->query_address()/" ")[0]);
  outfd=fd;
  last_write=writing_starttime=time(1);
  bucket=initial_bucket; //need to initialize it here, or ftp
                         //will cause problems with long-lived sessions..
  outfd->set_nonblocking(lambda(){},write_some,check_for_closing);
  call_out(check_for_closing,10);
  call_out( write_some, 0.1 );
}

//add a fileobject to the write-queue
int file_len;
Stdio.File fd_in;
void input (Stdio.File what, int len) {
  THROTTLING_DEBUG("adding file input: len="+len);
  if (len<=0)
    file_len=0x7fffffff;
  else
  {
    status->len = len;
    file_len = len;
  }
  fd_in = what;

  if (fd_in->set_nonblocking) // doesn't exist for some virtual file types
    fd_in->set_nonblocking();

//   tosend+=what->read(len);
}

// This mapping will be updated when data is sent.
void set_status_mapping( mapping m )
{
  foreach( indices( status ), string x )
    m[x] = status[x];
  status = m;
  status->start = time();
}

//add a string to the write-queue
void write(string what) {
  THROTTLING_DEBUG("adding "+sizeof(what)+"-bytes string");
  tosend+=what;
}

//the name says it all
void set_done_callback(function|void f, void|mixed ... args) {
  done_callback=f;
  done_callback_args=args;
}

//extra API functions
void throttle (int rate, int depth, int initial) {
  THROTTLING_DEBUG("throttle. rate="+rate+", depth="+depth+
                   ", initial="+initial);
  fill_rate=rate;
  max_depth=depth;
  initial_bucket=initial;
}

void assign_throttler(void|object throttler_object) {
  THROTTLING_DEBUG("slowpipe: assigning throttler object");
  throttler=throttler_object;
}

//internals

//write callback
private void write_some () {
  int towrite;
  //have we finished?
  if( !strlen(tosend) )
  {
    if( fd_in )
    {
      catch(tosend = fd_in->read( min( file_len, 32768 ) ));
      if( !tosend || !strlen(tosend) )
      {
	tosend = "";
	THROTTLING_DEBUG("read: errno: "+fd_in->errno()+"\n");
	if( fd_in->errno() == 11 )
	{
	  remove_call_out( write_some );
	  call_out( write_some, 0.01 );
	}
	else
	{
	  catch(fd_in->close());
	  fd_in = 0;
	  finish();
	}
	return;
      }
      else
	file_len -= strlen( tosend );
      if( (file_len <= 0)  )
      {
	catch(fd_in->close());
	fd_in = 0;
      }
    }
    else
    {
      finish();
      return;
    }
  }
  THROTTLING_DEBUG("write_some: still "+strlen(tosend)+" bytes to be sent");

  //are we throttling?
  if (!fill_rate) {
    towrite=32768;
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
    throttler->request(towrite,finally_write,host);
}

void finally_write(int howmuch) {
  THROTTLING_DEBUG("slowpipe: finally_write. howmuch="+howmuch);
  int written;
  //actual write
  if( catch (written=outfd->write( tosend[..howmuch-1] )) )
  {
    finish();
    return;
  }
  THROTTLING_DEBUG("slowpipe: actually wrote "+written);
  status->written += written;
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
  if(!outfd || catch(outfd->query_address()) || !outfd->query_address()) {
#ifdef FD_DEBUG
    write("Detected closed FD. Self-Destructing.\n");
#endif
    finish();
  }
  else
    call_out(check_for_closing, 2);
}

void finish()
{
  status->closed = 1;
  int delta=time(1)-writing_starttime;
  if (!delta) delta=1; //avoid division by zero errors
  THROTTLING_DEBUG("slowpipe: cleaning up and leaving ("+
                   delta+" sec, "+(sent?(sent/delta):0)+" bps)");;
  if (outfd) {
    catch(outfd->set_blocking());
    outfd=0;
  }
  tosend=0;
  remove_call_out(check_for_closing);
  if (done_callback)
    done_callback(@done_callback_args);
  destruct(this_object());
}
