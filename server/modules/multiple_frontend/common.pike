#!NO MODULE

class Command
{
  constant is_command = 1;

  string cmd;
  mixed data;

  static int `==( mixed what )
  {
    if( objectp( what )  && what->is_command )
      return (what->cmd == cmd) && equal( what->data, data );

    if( what == cmd )
      return 1;
  }

  static Command `+( Command what )
  {
    if( cmd != "multi" )
      return error("cmd != multi\n");
    data += ({ what });
    return this_object(); // always destructive..
  }

  static Command `-( Command what )
  {
    if( cmd != "multi" )
      return error("cmd != multi\n");
    data -= ({ what });
    return this_object(); // always destructive..
  }
  
  static void create( string _cdc, mixed|void _data )
  {
    if( query_num_arg() == 1 )
    {
      _cdc = decrypt( _cdc );
      if( _cdc[0] )
      {
        _cdc = _cdc[_cdc[0]..];
        cmd = _cdc[ 1.._cdc[0] ];
        _cdc = _cdc[_cdc[0]+1+_cdc[_cdc[0]+1]..];
        data = decode_data( _cdc );
      } else {
        cmd = _cdc[ 2.._cdc[1]+1 ];
        _cdc = _cdc[_cdc[1]+2..];
        data = decode_data( _cdc );
      }        
    } else {
      cmd = _cdc;
      data = _data;
    }
  }

  static string mkpad(  )
  {
    int i = random(100)+50;
    return sprintf("%c%s", i, rr->read( i-1 ) );
  }

  static mixed decode_data( string fd )
  {
    int l;
    sscanf( fd[1..4], "%4c", l );
    switch( fd[0] )
    {
     case 'I': return Gmp.mpz( fd[5..4+l], 256 );
     case 'S': return fd[5..4+l];
     default:  
       mixed tmp = decode_value( fd );
       if( cmd == "multi" )
         tmp = map( tmp, Command );
       return tmp;
    }
  }

  static string encode_data()
  {
    if( stringp( data ) )
      return sprintf("S%4c%s",strlen(data),data);
    if( intp( data ) )
    {
      string d = data->digits(256);
      return sprintf("I%4c%s",strlen(d),d);
    }
    mixed tmp = data;
    if( cmd == "multi" )
      tmp = tmp->encode(1);
    return encode_value( tmp );
  }

  static string _sprintf( int f )
  {
    if( f == 'O' )
      return sprintf("Command( %s, %O )", cmd, data);
    return 0;
  }

  string encode(int|void spad)
  {
    if( spad )
      return encrypt( sprintf( "\0%c%s%s", 
                               strlen(cmd), cmd,
                               encode_data() ) );

    return encrypt( sprintf( "%s%c%s%s%s%s", 
                             mkpad(), 
                             strlen(cmd), cmd,
                             mkpad(),
                             encode_data(),
                             mkpad() ) );
  }
}

class Result
{
  inherit Command;

  static string _sprintf( int f )
  {
    if( f == 'O' )
      return sprintf("Result( %s, %O )", cmd, data);
    return 0;
  }
}

Result Void = Result( "void", "" );
Result True = Result( "bool", 1 );
Result False =Result( "bool", 0 );

static mapping(string:function(Command:Result)) _callbacks = ([]);

static string host;
static int port;

static array(Result) handle_multi_cmd( Command cmd )
{
  array(Result) res = ({});
  foreach( cmd->data, Command cmd )
    res += handle_cmd( cmd );
  return res;
}

static array(Result) handle_cmd( Command cmd )
{
  array(Result) res = ({});
  if( cmd == "multi" )
    res += handle_multi_cmd( cmd );
  else
  {
    mixed tmp;
    mixed err;
    if( _callbacks[ cmd->cmd ] )
      err = catch(tmp = _callbacks[ cmd->cmd ]( cmd ));
    else if( _callbacks[ 0 ] )
      err = catch(tmp = _callbacks[ 0 ]( cmd ));

    if( err )
      tmp = Result("error", describe_backtrace(err)+"\n\n" );

    if(!tmp)
      tmp = Void;
    else if( !objectp( tmp ) || !tmp->is_command )
      tmp = Result("value", tmp );

    res += ({ tmp });
  }
  return res;
}

string handle_rpc_query_data( string data )
{
  Command c = Command( data );
  array(Result)|object(Result) res;

  if( c == "multi" )
    res = handle_multi_cmd( c );
  else
    res = handle_cmd( c )[0];

  if( arrayp( res ) )
    res = Result( "multi", res );

  return res->encode();
}

void set_callback( string cmd, 
                   function(Command:mixed) cb )
{
  _callbacks[ cmd ] = cb;
}

Result|array(Result) do_query( Command ... _command )
{
  Stdio.File f = Stdio.File();
  mixed command;
  if( sizeof( _command ) == 1 )
    command = _command[0];
  else
    command = _command;
  while(!f->connect( host, port ))
  {
    werror("Failed to connect to "+host+" : "+port+". Sleeping(10).\n");
    sleep( 10 );
  }

  string data = (objectp(command)?
                 command->encode():
                 Command( "multi", command )->encode());

  f->write( "ROXEN_FE_RPC 1 HTTP/1.0\r\n"
            "Content-type: RoxenFERPC\r\n"
            "User-Agent: Roxen\r\n"
            "Content-length: "+strlen(data)+"\r\n"
            "\r\n"+ data );
  Result res;
  res = Result( f->read() );
  
  mixed decode_result( Result r )
  {
    switch( r->cmd )
    {
     case "value":
     case "bool":
       return r->data;
     case "error":
       error( r->data );
     case "void":
       return ([])[0];
     default:
       werror("Got result of type '%O'\n", r->cmd );
       return r;
    }
  };

  if( res == "multi" )
    return map( res->data, decode_result );
  return decode_result( res );
}








object rr = Crypto.randomness.reasonably_random();
object crypto = Crypto.arcfour();
string key;

void set_key( string to )
{
  key = to;
  crypto->set_encrypt_key( to );
}

void set_host( string to, int pto )
{
  host = to;
  port = pto;
}

string encrypt( string what )
{
  crypto->set_encrypt_key( key );
  return crypto->crypt( what );
}

string decrypt( string what )
{
  crypto->set_encrypt_key( key );
  return crypto->crypt( what );
}
