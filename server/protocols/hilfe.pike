inherit Protocols.TELNET;

Protocol my_port_obj;
Configuration my_conf;
Readline rl;
Stdio.File fd;
Handler handler;
AdminUser user;

class myRequestID
{
  inherit RequestID;
  void create()
  {
    port_obj = my_port_obj;
    conf = my_conf;


    client = ({ "telnet" });
    prot = "HILFE";
    method = "GET";

    variables = ([]);
    misc = ([]);
    cookies = ([]);
    throttle = ([]);
    client_var = ([]);
    request_headers = ([]);
    prestate = (<>);
    config = (<>);
    supports = (<>);
    pragma = (<>);

    rest_query = "";
    extra_extension = "";

    not_query = raw_url = "/";
  }

  void set_path( string f )
  {
    raw_url = Roxen.http_encode_string( f );
    if( strlen( f ) > 5 )
    {
      string a;
      switch( f[1] )
      {
       case '<':
         if (sscanf(f, "/<%s>/%s", a, f)==2)
         {
           config = (multiset)(a/",");
           f = "/"+f;
         }
         // intentional fall-through
       case '(':
         if(strlen(f) && sscanf(f, "/(%s)/%s", a, f)==2)
         {
           prestate = (multiset)( a/","-({""}) );
           f = "/"+f;
         }
      }
    }
    not_query = Roxen.simplify_path( scan_for_query( f ) );
  }

  void set_url( string url )
  {
    Configuration c;
    foreach( indices(roxen->urls), string u )
    {
      mixed q = roxen->urls[u];
      if( glob( u+"*", url ) )
        if( (c = q->port->find_configuration_for_url(url, this_object(), 1 )) )
        {
          conf = c;
          break;
        }
    }

    if(!c)
    {
      // pass 2: Find a configuration with the 'default' flag set.
      foreach( roxen->configurations, c )
        if( c->query( "default_server" ) )
        {
          conf = c;
          break;
        }
        else
          c = 0;
    }
    if(!c)
    {
      // pass 3: No such luck. Let's allow default fallbacks.
      foreach( indices(roxen->urls), string u )
      {
        mixed q = roxen->urls[u];
        if( (c = q->port->find_configuration_for_url( url,this_object(), 1 )) )
        {
          conf = c;
          break;
        }
      }
    }

    string host;
    sscanf( url, "%s://%s/%s", prot, host, url );
    misc->host = host;
    set_path( url );
  }

  static string _sprintf()
  {
    return 
        sprintf("RequestID(conf=%O; not_query=%O)", conf, not_query );
  }
}

class Handler
{
  inherit Tools.Hilfe.Evaluator;
  roxenloader.ErrorContainer ec = roxenloader.ErrorContainer();

  void got_data( string d )
  {
    mixed oc = master()->get_inhibit_compile_errors( );
    master()->set_inhibit_compile_errors( ec );
    add_input_line( d );
    master()->set_inhibit_compile_errors( oc );
    if( strlen( ec->get() ) )
    {
      write( replace(ec->get(),"\t"," ") );
      ec->errors = "";
    }
    ec->warnings = "";
    write( strlen(input)?">> ": "> " );
    user->settings->set("hilfe_history",
                        rl->readline->get_history()->encode());
    user->settings->save();
  }

  void create()
  {
    write = rl->readline->write;
    constants["RequestID"] = myRequestID;
    constants["conf"] = my_conf;
    constants["port"] = my_port_obj;
    constants["user"] = user;
    user->settings->defvar( "hilfe_history", Variable.String("", 65535,0,0 ) );
    user->settings->restore( );
    string hi;
    if( (hi = user->settings->query("hilfe_history")) != "" )
      rl->readline->get_history()->create( 512, hi/"\n" );
    ::create();
    got_data("");
  }
}

#define USER 0
#define PASSWORD 1
#define LEAVE 2
#define DATA 3
int state = USER;

void got_user_line( mixed q, string line )
{
  switch( state )
  {
   case USER:
     if(!(user = roxen.find_admin_user( line-"\n" ) ) )
     {
       rl->readline->write("No such user: '"+(line-"\n")+"'\n");
     } 
     else 
     {
       state++;
     }
     break;
   case PASSWORD:
     if( !crypt(line-"\n", user->password) )
     {
       rl->readline->write("Wrong password\n");
       state=USER;
     } 
     else
     {
       state++;
     }
     break;
   default:
     handler->got_data( line );
  }

  switch( state )
  {
   case USER:
     rl->set_secret( 0 );
     rl->readline->write("User: ");
     break;
   case PASSWORD:
     rl->set_secret( 1 );
     rl->readline->write("Password: ");
     break;
   case LEAVE:
     rl->set_secret( 0 );
     state++;
     handler = Handler( );
     signal( signum("ALRM"), handle_alarm );
     update_lu();
     handle_alarm();
     break;
  }
}

int last_update;
void update_lu()
{
  last_update = time();
  call_out( update_lu, 1.0 );
}
void handle_alarm( )
{
  alarm( 1 );
  if( time()-last_update > 5 )
    throw( "Too long evaluation\n" );
}

void begone()
{
  catch(fd->write("Bye\n"));
  destruct(fd);
  destruct( this_object() );
}

void write_more()
{
}

int n;
static void init2( )
{
  if( rl->readline )
  {
    rl->readline->write("Welcome to Roxen Hilfe 1.0\n", 1);
    rl->readline->write("Username: ");
    return;
  }
  n++;
  if( n < 100 )
    call_out( init2, 0.1 );
  else 
  {
    rl->message("Failed to set up terminal.\n");
    begone();
  }
}

static void create(object f, object c, object cc)
{
  my_port_obj = c; 
  my_conf = cc;
  rl = Readline( f, got_user_line, 0, begone, 0 );
  call_out( init2, 0.1 );
}
