// This is a roxen protocol module.
// Copyright © 2001 - 2009, Roxen IS.

//<locale-token project="roxen_message"> LOC_M </locale-token>
#include <roxen.h>

#define LOC_M(X,Y)	_STR_LOCALE("roxen_message",X,Y)
#define CALL_M(X,Y)	_LOCALE_FUN("roxen_message",X,Y)

inherit Protocol;
constant supports_ipless = 0;
constant name = "hilfe";
constant prot_name = "telnet";
constant requesthandlerfile = "protocols/hilfe.pike";
constant default_port = 2345;

class Connection
{
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
    string real_auth;
    string remoteaddr = "127.0.0.1";
    protected string _sprintf()
    {
      return sprintf("myRequestID(conf=%O; not_query=%O)", conf, not_query );
    }

    protected void create()
    {
      port_obj = my_port_obj;
      conf = my_conf;


      client = ({ "telnet" });
      prot = "HILFE";
      method = "GET";

      real_variables = ([]);
      variables = FakedVariables( real_variables );
      misc = ([]);
      cookies = CookieJar();
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

    object last_module;
    string fix_msg( string msg, object|void mod )
    {
      if( functionp( mod ) ) mod = function_object( mod );
      if( mod )
	last_module = mod;
      if(msg[-1] != '\n' )
	msg += "\n";
      string m = sprintf("%O:", last_module );
      m = (m[..40]+"                                    "[..39-strlen(m)]);
      return sprintf("%s%s", m, Roxen.html_decode_string(msg) );
    }
  
    void debug_trace_enter_1( string msg, object module )
    {
      rl->readline->write( fix_msg(indent+msg,module), 1 );
      indent += "  ";
    }

    void debug_trace_leave_1( string msg )
    {
      indent = indent[..strlen(indent)-3];
    }

    string indent="";
    array old_backtrace;
    void debug_trace_enter_2( string msg, object module )
    {
      array q = backtrace() - (old_backtrace||({}));
      rl->readline->write("\n\n"+describe_backtrace( q ) );
      rl->readline->write( fix_msg(indent+msg,module), 1 );
      indent += "  ";
    }

    void debug_trace_leave_2( string msg, object module )
    {
      old_backtrace = backtrace();
      if( strlen( String.trim_all_whites(msg) ) )
	rl->readline->write( fix_msg(indent+msg,0), 1 );
      indent = indent[..strlen(indent)-3];
    }

    this_program set_debug( int level )
    {
      indent = "";
      switch( level )
      {
	case 0:
	  misc->trace_enter = 0;
	  misc->trace_leave = 0;
	  break;
	case 1:
	  misc->trace_enter = debug_trace_enter_1;
	  misc->trace_leave = debug_trace_leave_1;
	  break;
	default:
	  misc->trace_enter = debug_trace_enter_2;
	  misc->trace_leave = debug_trace_leave_2;
	  break;
      }
      return this_object();
    }

    this_program set_path( string f )
    {
      raw_url = Roxen.http_encode_invalids( f );
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
      return this_object();
    }

    this_program set_url( string url )
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

      if (!c->inited) {
	// FIXME: We can be called from the backend thread, so this
	// should be queued for a handler thread.
	c->enable_all_modules();
      }

      string host;
      sscanf( url, "%s://%s/%s", prot, host, url );
      misc->host = host;
      return set_path( "/"+url );
    }
  }

  class InsinuateFirst
  {
    mixed query( string what ) { return 0; }
    void first_try( RequestID id )
    {
      if(catch 
      {
	rl->readline->write( sprintf("Request for %s in %O from %s\n",
				     id->not_query, id->conf, id->remoteaddr),1);
      })
      {
	id->conf->pri[4]->first_modules -= ({ this_object() });
	id->conf->invalidate_cache();
      }
    }
  }

  mixed hilfe_debug( string what )
  {
    if( !stringp( what ) )
      error("Syntex: debug(\"what\");");
    switch( what )
    {
      case "accesses":
	foreach( roxen->configurations, Configuration c )
	  if( c->inited )
	  {
	    c->pri[4]->first_modules += ({ InsinuateFirst() });
	    c->invalidate_cache();
	  }
	break;

      default:
	error("Don't know how to debug "+what+"\n");
    }
  }


#if __VERSION__ > 7.2
  class Handler {
    inherit Tools.Hilfe.Evaluator;

    void got_data( string d )
    {
      if( String.trim_all_whites(d) == "quit" )
      {
	begone( );
	return;
      }
      add_input_line( d );
      write( state->finishedp() ? "> " : ">> " );
      user->settings->set("hilfe_history",
			  rl->readline->get_history()->encode());
      user->settings->save();
    }

    void create()
    {
      ::create();
      write = lambda (string msg, mixed... args) {
		if (sizeof (args)) msg = sprintf (msg, @args);
		rl->readline->write (msg);
	      };
      constants["RequestID"] = myRequestID;
      constants["conf"] = my_conf;
      constants["port"] = my_port_obj;
      constants["user"] = user;
      constants["debug"] = hilfe_debug;
      user->settings->defvar( "hilfe_history", Variable.String("", 65535,0,0 ) );
      user->settings->restore( );
      string hi;
      if( (hi = user->settings->query("hilfe_history")) != "" )
	rl->readline->get_history()->create( 512, hi/"\n" );
      rl->readline->get_history()->finishline("");
      print_version();
      got_data("");
    }
  }
#else
  class Handler
  {
    inherit Tools.Hilfe.Evaluator;
    roxenloader.ErrorContainer ec = roxenloader.ErrorContainer();
    int time_base;
  
    mixed do_evaluate(string a, int show_result)
    {
      mixed foo, c;
      foo=eval(a);

      if( foo )
      {
	mixed ff = foo->___Foo4711;
	mixed res;
	int st;
	c = catch{ st = gethrtime(); res = ff(); st = gethrtime()-st-time_base; };
	a = sprintf("%O", res);
	if(c)
	{
	  trace(0);
	  if(arrayp(c) && sizeof(c)==2 && arrayp(c[1]))
	  {
	    c[1]=c[1][sizeof(backtrace())..];
	    write(describe_backtrace(c));
	  }
	  else if(objectp(c) && c->is_generic_error)
	  {
	    c->__backtrace=c->__backtrace[sizeof(backtrace())..];
	    write(describe_backtrace(c));
	  }else{
	    write(sprintf("Error in evalutation: %O\n",c));
	  }
	}else{
	  if(show_result)
	  {
	    write("Result: "+replace(a, "\n", "\n        ")+"\n");
	    if( st > 1000 )
	      write(sprintf("Timer:  %.1fms\n", st/1000.0 ));
	    else
	      write(sprintf("Timer:  %dns\n", st ));
	  }
	  else
	  {
	    write("Result: void\n");
	    if( st > 1000 )
	      write(sprintf("Timer:  %.1fms\n", st/1000.0 ));
	    else
	      write(sprintf("Timer:  %dns\n", st ));
	  }
	  variables=foo->query_variables();
	  variables["_"] = res;
	}
      }
    }

    void got_data( string d )
    {
      if( String.trim_all_whites(d) == "quit" )
      {
	begone( );
	return;
      }
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
      int cc;
      cc = gethrtime(); lambda(){}(); time_base = gethrtime()-cc;

      write = rl->readline->write;
      constants["RequestID"] = myRequestID;
      constants["conf"] = my_conf;
      constants["port"] = my_port_obj;
      constants["user"] = user;
      constants["debug"] = hilfe_debug;
      user->settings->defvar( "hilfe_history", Variable.String("", 65535,0,0 ) );
      user->settings->restore( );
      string hi;
      if( (hi = user->settings->query("hilfe_history")) != "" )
	rl->readline->get_history()->create( 512, hi/"\n" );
      ::create();
      rl->readline->get_history()->finishline("");
      got_data("");
    }
  }
#endif // > Pike 7.2

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
	  if( !my_port_obj->query( "require_auth" ) || user->auth( "Hilfe" ) )
	    state++;
	  else
	  {
	    rl->readline->write("User lacks permission to access hilfe\n");
	    state = USER;
	  }
	}
	break;
      default:
	handler->got_data( line );
	return;
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
#ifndef THREADS
	signal( signum("ALRM"), handle_alarm );
	update_lu();
	handle_alarm();
#endif
	break;
    }
  }

#ifndef THREADS
  // This is only a good thing when we've got no threads and have to
  // use the backend. In a threaded server this code misbehaves
  // severely (handle_alarm trigs an error in a random thread).
  int last_update;
  void update_lu()
  {
    last_update = time();
    call_out( update_lu, 1.0 );
  }
  void handle_alarm( )
  {
#if constant (alarm)
    // Pike@NT doesn't have this. This "fix" ought to be better..
    alarm( 1 );
#endif
    if( time()-last_update > 5 )
      error( "Too long evaluation\n" );
  }
#endif

  void begone()
  {
    catch(fd->write("\nBye\n"));
    catch(fd->close());
    catch(destruct( fd ));
    catch(destruct( handler ));
    catch(destruct( this_object() ));
  }

  void write_more()
  {
  }

  int n;
  protected void init2( )
  {
    if( rl->readline )
    {
      rl->readline->write("Welcome to Roxen Hilfe 1.1\n", 1);
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

  protected void create(object f, object c, object cc)
  {
    my_port_obj = c; 
    my_conf = cc;
    fd = f;
    rl = Readline( f, got_user_line, 0, begone, 0 );
    call_out( init2, 0.1 );
  }
}

void create( mixed ... args )
{
  roxen.add_permission( "Hilfe", LOC_M( 12, "Hilfe" ) );
  roxen.set_up_hilfe_variables( this_object() );
  requesthandler = Connection;
  ::create( @args );
}
