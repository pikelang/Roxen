inherit Protocols.TELNET;

Protocol my_port_obj;
Configuration my_conf;
Readline rl;
Stdio.File fd;
Handler handler;
AdminUser user;

class Request
{
  inherit RequestID;
  void create()
  {
    port_obj = my_port_obj;
    conf = my_conf;
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
  }

  void create()
  {
    write = rl->readline->write;
    ::create();
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
     rl->readline->write("> ");
     break;
  }
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
    werror("Inited!\n");
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
  my_conf = c;
  rl = Readline( f, got_user_line, 0, begone, 0 );
  call_out( init2, 0.1 );
}
