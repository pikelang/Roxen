#!NO MODULE


inherit "common.pike";

void da_server( Stdio.Port p )
{
  set_callback( 0, lambda(Command c) {
                     return Result( "error", "Unknown command\n" );
                   } );

  set_callback( "foo", lambda( Command c )
                       {
                         return c->data ? True : False;
                       } );

  set_callback( "gazonk", lambda( Command c )
                       {
                         return c->data->DISPLAY;
                       } );



  while( Stdio.File fd = p->accept() )
  {
    string data = fd->read( 8192, 1 );
    while( search( data, "\r\n\r\n" ) == -1 )
    {
      data += fd->read( 8192, 1 );
    }
    string method, prot;
    int fno;
    sscanf( data, "%s %d %s\r\n%s", method, fno, prot, data );

    if( fno != 1 )
    {
      werror("Wanted protocol version 1, got %d\n", fno );
      fd->write( "HTTP/1.0 200 OK\r\n"
                 "Content-Type: text/x-roxen-rpc\r\n"
                 "\r\n"+
                 Result( "error", "Bad protocol version!\n" )->encode() );
      continue;
    }

    if( method != "ROXEN_FE_RPC" )
    {
      werror("Wanted method ROXEN_FE_RPC, got %s\n", method );
      fd->write( "HTTP/1.0 200 OK\r\n"
                 "Content-Type: text/x-roxen-rpc\r\n"
                 "\r\n"+
                 Result( "error", "Bad method!\n" )->encode() );
      continue;
    }

    string headers;
    sscanf( data, "%s\r\n\r\n%s", headers, data );
    int clen;
    foreach( headers/"\r\n", string header )
    {
      string value;
      sscanf( header, "%s: %s", header, value );
      if( header == "Content-length" )
        clen = (int)value;
    }
    if( strlen( data ) < clen )
      data += fd->read( clen - strlen( data ) );
    fd->write( "HTTP/1.0 200 OK\r\n"
               "Content-Type: text/x-roxen-rpc\r\n"
               "\r\n"+
               handle_rpc_query_data( data ) );
    fd->close( "rw" );
    destruct( fd );
  }
}


void main()
{
  werror("Roxen FE RPC testsuite\n\n");

  set_key( rr->read( 4096 ) );

  float t;
  Command c = Command( "test", "Test command" );
  string d = c->encode();
  werror("Testing basic speed\n");
  
  void test_decodeok( Command f )
  {
    if( Command(f->encode()) != f )
      werror(" Oups: %O\n%O\n", f, Command(f->encode()) );
  };

  test_decodeok( Command( "test", 1 ) );
  test_decodeok( Command( "test", 0.5 ) );
  test_decodeok( Command( "test", "FOOBAR!" ) );
  test_decodeok( Command( "test", ({ "foo", "bar" }) ) );

  t = gauge 
  {
    for( int i = 1000; i>0; i-- )
      c->encode();
  };
  werror( "     encode: %.2fms/call\n", t );

  t = gauge 
  {
    for( int i = 1000; i>0; i-- )
      Command( d );
  };
  werror( "     decode: %.2fms/call\n", t );

  werror("Testing multi command   \n");
  werror("     push");
  c = Command("multi", ({}));
  for( int i = 0; i<2048; i++ )
  {
    if( (i % 290) == 0 )
      werror(".");
    c += Command( "foo", "bar" );
  }
  werror("ok [2048 commands in one]\n");
  werror("     encode...");
  string ec;
  t = gauge {
    ec = c->encode();
  };
  werror("...ok [%d bytes, %.2fms/cmd]\n", strlen(ec),
         t/2049*1000);

  werror("     decode...");
  Command tc;
  t = gauge {
    tc = Command( ec );
  };
  if(tc != c )
  {
    werror("FAILED!\n");
    werror( "%O\n<--->\n%O\n", Command(c->encode()));
    exit(1);
  }
  werror("...ok [%.2fms/cmd]\n",
         t/2049*1000);


  set_host( "localhost", 4712*3 );
  Stdio.Port p = Stdio.Port( 4712*3 );
  thread_create( da_server, p );

  werror("Testing client<->server connectivity\n");


  werror("     Simple command          .. ");
  int t = gethrtime();
  if( do_query( Command("foo", 1 ) ) != 1 )
    werror("FAILED\n");
  else if( do_query( Command("foo", "FOOBAR" ) ) != 1 )
    werror("FAILED\n");
  else if( do_query( Command("foo", 0 ) ) )
    werror("FAILED\n");
  else
    werror("ok [%.2fms/call]\n", ((gethrtime()-t)/1000.0/3.0));

  werror("     Multiple command        .. ");
  int t = gethrtime();
  if( !equal(do_query(
                      Command("foo", 1 ), 
                      Command("foo", "foo" ), 
                      Command("foo", (<>) ), 
                      Command("foo", ([]) ), 
                      Command("foo", ({}) ), 
                      Command("foo", 0 ), 
                      Command("gazonk", getenv() ) 
                      ), 
             ({ 1, 1, 1, 1, 1, 0, getenv("DISPLAY") }) ))
    werror("FAILED\n");
  else
    werror("ok [%.2fms/call]\n", (gethrtime()-t)/1000.0/7.0);

  werror("     Unknown command (error) .. ");
  int t = gethrtime();
  if( ! catch( do_query( Command( "unknown", 1 ) ) ) )
    werror("FAILED\n");
  else
    werror("ok [%.2fms/call]\n",(gethrtime()-t)/1000.0 );
}
