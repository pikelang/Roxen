/*
 * $Id: smartpipe.pike,v 1.7 1998/03/07 03:06:01 neotron Exp $
 *
 * A somewhat more optimized Pipe.pipe...
 */

#if !constant(spider.shuffle)
# error This should not happend...
#endif

array to_send = ({});
function done_callback;
object outfd;
function write_out;
int sent;

mixed current_input;
int current_input_len;

int bytes_sent()
{
  return sent;
}

void next_input();

void finish()
{
  if(outfd)
  {
    outfd->set_blocking();
    outfd = 0;
    write_out = 0;
  }
  if(done_callback) done_callback();
  current_input = 0;
  write_out = done_callback = 0;
  to_send = 0;
}

void write_more()
{
  int len;
  len = write_out(current_input);
  sent += len;
  if(sent <= 0)
  {
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
  string q;
  while(q = r(min(8192,current_input_len),1))
  {
    if(!q || !strlen(q)) break;
    if(write_out( q ) != strlen(q)) break;
    current_input_len -= strlen(q);
    sent += strlen(q);
    if(!current_input_len) break;
  }
  next_input();
}

void next_input()
{
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
    sent +=
      outfd->write((objectp(current_input)
		   ?current_input->read(current_input_len)
		   :current_input) || "");
    next_input();
    return;
  }

  if(stringp(current_input))
  {
    outfd->set_nonblocking(0,write_more,0);
    return;
  }
  if(outfd->query_fd()>0 && current_input->query_fd()>0)
  {
    outfd->set_blocking();
    spider.shuffle(current_input,outfd,_pipe_done,0,current_input_len);
    return;
  }
  shuffle( );
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

void set_done_callback(function f)
{
  done_callback = f;
}
