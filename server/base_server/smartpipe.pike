/* A somewhat more optimized Pipe.pipe... */

array to_send = ({});
function done_callback;
mixed id;
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
  if(done_callback) done_callback(id);
  current_input = 0;
  id = 0;
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

string buffer="";

#if !constant(min)
#define min(a,b) ((a)>(b)?(b):(a))
#endif

void next_buffer()
{
  if(current_input_len < 0) 
  {
    buffer=0;
    return;
  }
  int toread;
  toread = min(current_input_len, 8192);
  buffer = current_input->read(toread,1); // WARNING! BLOCKING!
  current_input_len -= strlen(buffer);
  if(current_input_len < 0) current_input_len = -1;
}

void write_more_from_file()
{
  if(!strlen(buffer)) next_buffer();
  if(!buffer || !strlen(buffer)) {
    next_input();
    return;
  }
  int len;
  len = write_out(buffer);
  sent += len;
  if(sent <= 0)
  {
    finish();
    return;
  }
  sent += len;
  buffer = buffer[len..];
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

#if efun(thread_create)
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
#endif

void next_input()
{
  if(!sizeof(to_send))
  {
    finish();
    return;
  }
  
  current_input = to_send[0][0];
  current_input_len = to_send[0][1] || 0x7fffffff;
  to_send = to_send[1..];

  if(current_input_len < 8192)
  {
    outfd->set_blocking();
    outfd->write(objectp(current_input)
		 ?current_input->read(current_input_len)
		 :current_input);
    next_input();
    return;
  }

  if(stringp(current_input))
  {
    outfd->set_nonblocking(0,write_more,0);
    return;
  }
#if constant(spider.shuffle)
  if(outfd->query_fd()>0 && current_input->query_fd()>0)
  {
    outfd->set_blocking();
    spider.shuffle(current_input,outfd,_pipe_done,0,current_input_len);
    return;
  }
#endif
#if efun(thread_create)
  shuffle( );
  return;
#else
      /* Do something smarter here... */
  outfd->set_nonblocking(0,write_more_from_file,0);
  return;
#endif
  finish();
}

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

void set_done_callback(function f, mixed i)
{
  done_callback = f;
  id = i;
}
