/*
 * $Id: smartpipe.pike,v 1.28 1999/03/05 01:54:53 grubba Exp $
 *
 * A somewhat more optimized Pipe.pipe...
 */

#if !constant(spider.shuffle)
# error This should not happend...
#endif

array to_send = ({});
function done_callback;
array(mixed) done_cb_args;
object outfd;
function write_out;
int sent;
int last_called;
mixed current_input;
int current_input_len;

int bytes_sent()
{
  return sent;
}

void next_input();
void finish();

void check_for_closing()
{
  if(!outfd || !outfd->query_address()) {
#ifdef FD_DEBUG
    write("Detected closed FD. Self-Destructing.\n");
#endif
    finish();
  } else
    call_out(check_for_closing, 10);
}

void finish()
{
  if(outfd)
  {
    outfd->set_blocking();
    outfd = 0;
    write_out = 0;
  }
  if(done_callback)
    done_callback(@done_cb_args);
  current_input = 0;
  write_out = done_callback = 0;
  done_cb_args = 0;
  to_send = 0;
  remove_call_out(check_for_closing);
  destruct(this_object());
}

void write_more()
{
  int len;
  last_called = time(1);
  len = write_out(current_input);
  if(len <= 0)
  {
#ifdef FD_DEBUG
    write("Write failed. Self-Destructing.\n");
#endif
    finish();
    return;
  }
  sent += len;
  if(len >= strlen(current_input))
    next_input();
  else
    current_input = current_input[len..];
}

void closed()
{
  finish();
}

void _pipe_done(int s)
{
  sent += s;
  next_input();
}

void shuffle()
{
  outfd->set_blocking();
  function r = current_input->read;

  if (!r) {
    error("shuffle: No read function!\n");
  }

  string q;
  while(q = r(min(8192,current_input_len),1))
  {
    if(!q || !strlen(q))
      break;
    if(write_out( q ) != strlen(q))
      break;
    current_input_len -= strlen(q);
    sent += strlen(q);
    if(!current_input_len)
      break;
  }
  catch(current_input->close());
  next_input();
}

void next_input()
{
  remove_call_out(check_for_closing);
  if(!sizeof(to_send))
  {
    finish();
    return;
  }

  current_input = to_send[0][0];
  current_input_len = to_send[0][1] > 0 ? to_send[0][1] : 0x7fffffff;
  to_send = to_send[1..];

  if(current_input_len < 8192)
  {
    outfd->set_blocking();
    int written = 
      outfd->write((objectp(current_input)
		    ?current_input->read(current_input_len, 1)
		    :current_input) || "");
    if(written == -1) {
#ifdef FD_DEBUG
      write("Short write failed. Self-Destructing.\n");
#endif
      finish();
    } else {
      sent += written;
      next_input();
    }
    return;
  }

  if(stringp(current_input))
  {
    outfd->set_nonblocking(0, write_more, 0);
    call_out(check_for_closing, 10);
    return;
  }
  if(outfd->query_fd()>0 && current_input->query_fd()>0)
  {
    outfd->set_blocking();
    current_input->set_blocking();
    spider.shuffle(current_input,outfd,_pipe_done,0,current_input_len);
    return;
  }
#if constant(thread_create)
  thread_create(shuffle);
#else /* !constant(thread_create) */
  shuffle( );
#endif /* constant(thread_create) */
  return;
}


/// API functions.

void write(string what)
{
  to_send += ({({what,strlen(what)})});
}

void input(object what, int|void len)
{
  to_send += ({({what,len})});
}

void output(object to)
{
  outfd = to;
  write_out = to->write;
  next_input();
}

void set_done_callback(function|void f, void|mixed ... args)
{
  done_callback = f;
  done_cb_args = args;
}
