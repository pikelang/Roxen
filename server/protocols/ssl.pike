#define SSL_DEBUG
inherit "protocols/http";

private static int free_port()
{
  int i;
  object port = ((program)"/precompiled/port")();
  
  /* There has to be a better way. */
  /* This is quite ugly, really.  */

  for(i=random(40000)+10000; i<65535; i+=random(20)+1) 
  {
    if(port->bind(i, 0, "127.0.0.1"))
    {
      destruct(port);
      return i;
    }
  }
  destruct( port );
  return 0;
}

static private int ___first;
void got_data(object f, string s)
{
  if(!___first)
  {
    ___first = 1;
    // There should be more info passed here in the future.
    if(sscanf(s, "%s\0%s", remoteaddr, s)==1)
    {
      conf->received+=strlen(remoteaddr);
#ifdef SSL_DEBUG
      perror("SSL: Real Remote-Addr: "+remoteaddr+"\n");
#endif
      return;
    }
#ifdef SSL_DEBUG
// I want to be able to see the difference between the two messages
    perror("SSL: Real RemoteAddr: "+remoteaddr+"\n");
#endif
  }
  ::got_data(f, s);
}

static string is_arg(string what)
{
  what -= "\r";
  if(!strlen(what))  return 0;
  if(what[0]=='#')   return 0;
  what = (replace(what,"\t"," ")/" "-({""}))*" ";
  if((what == " ") || !strlen(what)) return 0;
#ifdef SSL_DEBUG
  perror("SSL: Option '"+what+"'\n");
#endif
  return what;
}

// This is called once when the port is to be opened.
// Should return the real port to use, or nothing, if it
// is the same port as the one it gets as an argument.
//
// The port that is given as an argument is the one that the
// user think will be used.
array real_port(array port)
{
  array args = ({ });
  string arg;
  int p;

  if(!file_stat("bin/ssl"))
  {
    report_error("No SSL support installed.\n");
    return port;
  }

#ifdef SSL_DEBUG
  perror("Starting SSL handler for port "+port[0]+", IP "+port[2]+".\n");
#endif
  //                      port[2]==ip       port[0]==port
  args += ({ "--listen", (string)port[2], (string)port[0] });

  foreach(port[3]/"\n", arg)
  {
    string val;
    if(arg = is_arg(arg))
    {
      if(sscanf(arg, "%s %s", arg, val)>1)
      {
	args += ({ "--"+arg, val });
      } else {
	args += ({ "--"+arg });
      }
    }
  }

  if(!(p = roxen->query_var("ssl_port:"+port[0]+"@"+port[2])))
  {
    p = free_port();
    roxen->set_var("ssl_port:"+port[0], p);
    args += ({ "--server", "127.0.0.1", (string)p });

#ifdef SSL_DEBUG
    perror("Starting: bin/ssl "+args*" "+"\n");
#endif
    // Might have to be run as root. (port below 1000..)
    if(!fork()) 
    {
      catch
      {
	exece("bin/ssl", args);
      };
      perror("Failed to exece bin/ssl!!\n");
      exit(0);
    };
  }
  return ({  p, "ssl", "127.0.0.1", "" });
}


void assign(object f, object c)
{
#ifdef SSL_DEBUG
  perror("SSL: Assign..\n");
#endif
  if((f->query_address()/"0")[0] != "127.") // Test for 127.0
  {
#ifdef SSL_DEBUG
    perror("SSL: Odd address..\n");
#endif
    end("!");
  }
  ::assign(f, c);
}
