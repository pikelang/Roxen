/* $Id: https.pike,v 1.10 1999/10/08 19:08:38 grubba Exp $
 *
 * Copyright © 1996-1998, Idonex AB
 */

inherit "protocols/http" : http;
inherit "roxenlib";

mapping to_send;

#include <stdio.h>
#include <roxen.h>
#include <module.h>

// #define SSL3_DEBUG

#define CHUNK 16384

string to_send_buffer;
int done;

static void write_more();

void got_data_to_send(mixed fooid, string data)
{
#ifdef SSL3_DEBUG
  roxen_perror(sprintf("SSL3:got_data_to_send(X, \"%s\")\n", data));
#endif /* SSL3_DEBUG */
  if (!to_send_buffer) {
    to_send_buffer = data;
    my_fd->set_nonblocking(0, write_more, end);
    return;
  }
  to_send_buffer += data;
}

void no_data_to_send(mixed fooid)
{
#ifdef SSL3_DEBUG
  roxen_perror(sprintf("SSL3:no_data_to_send(X)\n"));
#endif /* SSL3_DEBUG */
  if (to_send->file) {
    to_send->file->set_blocking();
    to_send->file->close();
  }
  to_send->file = 0;
  if (!to_send_buffer) {
    // We need to wake up the sender,
    // so that it can close the connection.
    my_fd->set_nonblocking(0, write_more, end);
  }
}

string get_data()
{
#ifdef SSL3_DEBUG
  roxen_perror(sprintf("SSL3:get_data()\n"));
#endif /* SSL3_DEBUG */
  string s;
  if ((s = to_send->head))
  {
    to_send->head = 0;
    return s;
  }

  if ((s = to_send->data))
  {
    to_send->data = 0;
    return s;
  }

  s = to_send_buffer;
  to_send_buffer = 0;

  if (to_send->file) {
    /* There's a file, but no data yet
     * disable ourselves until there is.
     */
    my_fd->set_nonblocking(0, 0, end);
    return s || "";
  }

  return s;
}

static void die()
{
  my_fd->set_blocking();
  my_fd->close();
  if (done++) destroy();
}

string cache;
static void write_more()
{
#ifdef SSL3_DEBUG
  roxen_perror(sprintf("SSL3:write_more()\n"));
#endif /* SSL3_DEBUG */
  string s;
  if (!(s = (cache || get_data()))) {
//    perror("SSL3:: Done.\n");
    die();
    return;
  }

  if (sizeof(s)) {
    int pos = my_fd->write(s);

    // perror("Wrote "+pos+" bytes ("+s+")\n");
  
    if(pos <= 0) // Ouch.
    {
#ifdef DEBUG
      perror("SSL3:: Broken pipe.\n");
#endif
      die();
      return;
    }  
    if(pos < strlen(s))
      cache = s[pos..];
    else
      cache = 0;
  } else {
    cache = 0;
  }
}

string get_data_file()
{
#ifdef SSL3_DEBUG
  roxen_perror(sprintf("SSL3:get_data_file()\n"));
#endif /* SSL3_DEBUG */
  string s;
  if ((s = to_send->head))
  {
    to_send->head = 0;
    return s;
  }

  if ((s = to_send->data))
  {
    to_send->data = 0;
    return s;
  }

  if(to_send->file) {
    // Read some more data
    s = to_send->file->read(CHUNK,1);
  }

  if (!s || !sizeof(s)) {
#ifdef SSL3_DEBUG
    roxen_perror("SSL3:get_file_data(): EOF\n");
#endif /* SSL3_DEBUG */
    if (to_send->file) {
      to_send->file->close();
      to_send->file = 0;
    }
  }

  return s;
}

static void write_more_file()
{
#ifdef SSL3_DEBUG
  roxen_perror(sprintf("SSL3:write_more_file()\n"));
#endif /* SSL3_DEBUG */
  string s;

  if(!(s = (cache || get_data_file()))) {
//    perror("SSL3:: Done.\n");
    die();
    return;
  }    

  if (sizeof(s)) {
    int pos = my_fd->write(s);

    // perror("Wrote "+pos+" bytes ("+s+")\n");
  
    if(pos <= 0) // Ouch.
    {
#ifdef DEBUG
      perror("SSL3:: Broken pipe.\n");
#endif
      die();
      return;
    }  
    if(pos < strlen(s))
      cache = s[pos..];
    else
      cache = 0;
  } else {
    cache = 0;
  }
}

// Send the result.
void send_result(mapping|void result)
{
  array err;
  int tmp;
  mapping heads;
  string head_string;

  if (result) {
    file = result;
  }

  if(!mappingp(file))
  {
    if(misc->error_code)
      file = http_low_answer(misc->error_code, errors[misc->error]);
    else if(err = catch {
      file=http_low_answer(404,
			   replace(parse_rxml(conf->query("ZNoSuchFile"),
					      this_object()),
				   ({"$File", "$Me"}), 
				   ({not_query,
				       conf->query("MyWorldLocation")})));
    }) {
      internal_error(err);
    }
  } else {
    if((file->file == -1) || file->leave_me) 
    {
      if(do_not_disconnect) {
	file = 0;
	pipe = 0;
	return;
      }
      destroy();		// To mark we're not interested in my_fd anymore.
      my_fd = 0;
      file = 0;
      return;
    }

    if(file->type == "raw")
      file->raw = 1;
    else if(!file->type)
      file->type="text/plain";
  }
  
  if(!file->raw && prot != "HTTP/0.9")
  {
    string h;
    heads=
      ([
	"Content-type":file["type"],
		      "Server":replace(version(), " ", "·"),
		      "Date":http_date(time)
	 ]);
    
    if(file->encoding)
      heads["Content-Encoding"] = file->encoding;
    
    if(!file->error) 
      file->error=200;
    
    if(file->expires)
      heads->Expires = http_date(file->expires);

    if(!file->len)
    {
      if(objectp(file->file))
	if(!file->stat && !(file->stat=misc->stat))
	  file->stat = (int *)file->file->stat();
      array fstat;
      if(arrayp(fstat = file->stat))
      {
	if(file->file && !file->len)
	  file->len = fstat[1];
    
    
	heads["Last-Modified"] = http_date(fstat[3]);
	
	if(since)
	{
	  if(is_modified(since, fstat[3], fstat[1]))
	  {
	    file->error = 304;
	    method="HEAD";
	  }
	}
      }
      if(stringp(file->data)) 
	file->len += strlen(file->data);
    }

    if(mappingp(file->extra_heads)) 
      heads |= file->extra_heads;

    if(mappingp(misc->moreheads))
      heads |= misc->moreheads;
    
    array myheads = ({prot+" "+(file->rettext||errors[file->error])});
    foreach(indices(heads), h)
      if(arrayp(heads[h]))
	foreach(heads[h], tmp)
	  myheads += ({ `+(h,": ", tmp)});
      else
	myheads +=  ({ `+(h, ": ", heads[h])});


    if(file->len > -1)
      myheads += ({"Content-length: " + file->len });
    head_string = (myheads+({"",""}))*"\r\n";
    
    if(conf) conf->hsent+=strlen(head_string||"");
  }

  if(method == "HEAD")
  {
    file->data = 0;
    file->file = 0;
  }

  
  if(conf) {
    conf->sent+=(file->len>0 ? file->len : 1000);
    conf->log(file, this_object());
  }

  file->head = head_string;
  to_send = copy_value(file);	// Why make a copy?
  
  if (objectp(to_send->file)) {
    array st = to_send->file->stat && to_send->file->stat();
    if (st && (st[1] >= 0)) {
      // Ordinary file -- can't use non-blocking I/O
      my_fd->set_nonblocking(0, write_more_file, end);
    } else {
      my_fd->set_nonblocking(0, write_more, end);
      to_send->file->set_nonblocking(got_data_to_send, 0, no_data_to_send);
    }
  } else
    my_fd->set_nonblocking(0, write_more, end);
  if (done++) destroy();
}

private object my_fd_for_destruct; // Used to keep my_fd around for destroy().

void destroy()
{
#ifdef SSL3_DEBUG
  roxen_perror(sprintf("SSL3:destroy()\n"));
#endif /* SSL3_DEBUG */
  catch {
    // When the request disappear there's noone else interested in
    // my_fd, so it should destruct itself asap.
    if ((my_fd_for_destruct->destructme |= 1) == 3)
      destruct (my_fd_for_destruct);
  };
}

void create(object f, object c)
{
#ifdef SSL3_DEBUG
  roxen_perror(sprintf("SSL3:create(X, X)\n"));
#endif /* SSL3_DEBUG */
  if(f)
  {
    port_obj = c;

    my_fd = f;

#if 0
    conf = port_obj->find_configuration_for_url(/* ????? */, this_object());
#endif /* 0 */

    f->set_nonblocking(got_data,0,end);
  } else {
    // Main object. 
  }
}
