constant RUN_UNTHREADED = 0;
constant RUN_FIRST = 1;
constant RUN_THREADED = 2;
constant CAN_BLOCK_EMIT = 4;
constant ERROR_OK = 16;

constant DEBUG     = 8;
constant DO_NOT_CHAIN = 32;


local Thread.Farm farm = Thread.Farm( );

local string describe_flags( int f, int|void ff )
{
  string res = (int)f+" (";
  if( f | RUN_THREADED )
    res += "RUN_THREADED";
  else if(!ff)
    res += "RUN_UNTHREADED";

  if( f | RUN_FIRST )        res += " | RUN_FIRST";
  if( (f | CAN_BLOCK_EMIT) ) res += " | CAN_BLOCK_EMIT";
  if( f | RUN_FIRST )        res += " | RUN_FIRST";
  if( f | DEBUG )            res += " | DEBUG";
  if( f | ERROR_OK )         res += " | ERROR_OK";
  if( f | DO_NOT_CHAIN )     res += " | DO_NOT_CHAIN";
  string p;
  if( sscanf( res, "%s( | %s", p, res ) == 2 )
    res = p+" ("+res;
  return res+")";
}


local int umid;

class Message
//! The basic message class. All message classes must inherit this class.
{
  MessageType type;
  //! The type of this message.
  //! Normally not needed in user code.

  int id;
  //! Message id. Unique for this message.

  local array _args;
  local object _emitter;
  
  object emitter()
  //! Returns the object responsible for the message emission
  {
    return _emitter;
  }

  array args()
  //! Returns the arguments specified to the emit function
  {
    return _args;
  }
  
  static void create( MessageType _type, array __args, object __emitter,
                      int _id )
    //! Create a new message. Normally not done directly, instead
    //! this constructor is normally called by the
    //! MessageType->construct method, which in turn is called by
    //! Messenger->emit.
  {
    id = _id;
    type = _type;
    _args = __args;
    _emitter = __emitter;
  }

  static string _sprintf( int type, mapping opts )
  {
    if( type == 'O' )
      return sprintf("Message(%O,%O,%O)", type, args(), emitter() );
  }
}

class MessageType
//! The basic MessageType class. All other message types must inherit
//! this class.
//!
//! Methods in this class is not normally called by user code.
{
  constant name="base";
  //! Redefine this to a unique string in your MessageType classes

  constant my_message = Message;
  //! Optinally redefine this to be your Message class.

  int flags;
  //! ored to all messageemission and callback types of this class

  int mask_flags;
  //! removed from all messageemission and callback types of this class.
  //! A common usage is to set mask_flags to CAN_BLOCK_EMIT, thus
  //! disabling blocking of the emission of the message type.


  Message construct(object em, int id, mixed ... args)
  //! Construct a new Message of this type. 
  //! The first argument is the emitter, all other arguments are 
  //! passed as arguments to the Message. This method is normally not 
  //! called directly by user code.
  {
    return my_message( this_object(), args, em, id  );
  }

  static string _sprintf( int type, mapping opts )
  {
    if( type == 'O' )
      return sprintf("MessageType(%O,%s,~(%O))", 
                     name, describe_flags( flags, 1 ), 
                     describe_flags( mask_flags, 1 ));
  }
}

local class MessageCallback
//! A callback. Not used from user level code. 
{
  local int flags;
  local function(Message:int) real_cb;

  local Thread.Mutex mt;

  int run( Message m, int canblock )
  //! Run this callback. If canblock is true, check for blocking if ! 
  //! (flags & CAN_BLOCK_EMIT), otherwise just run it in the background.
  {
    object key;

    void handle_result( mixed res, int is_error )
    {
      if( objectp(key) ) destruct( key );
      if( is_error  && !(flags | ERROR_OK ) )
        werror(" While calling message callback %O with %O:\n%s",
               this_object(), m, describe_backtrace( res ) );
      else if( flags | DEBUG )
      {
        werror("%O(%O) -> %s\n", this_object(),m,
               (is_error?"ERROR":(string)res) );
      }
    };

    if( !(flags | RUN_THREADED ) )
      key = mt->lock();

    if( canblock && (flags | CAN_BLOCK_EMIT ) )
    {
      mixed res;
      mixed e = catch( res = real_cb( m ) );
      handle_result( e?e:res, !!e );
      return res;
    }
    else
      farm->run( real_cb, m )->set_done_cb( handle_result );
    return 0;
  }


  static string _sprintf( )
  {
    return sprintf("CallBack(%O,%s)", real_cb, describe_flags( flags ) );
  }

  static void create( function _cb, int _flags )
  {
    real_cb = _cb;
    flags = _flags;

    if( !(flags | RUN_THREADED ))
      mt = Thread.Mutex();
  }
}

class MessengerChain
//! The Messenger, RemoteMessenger and UDPMessenger classes inherits
//! this class.
{
  local array(MessengerChain) chained = ({});

  void emit_message( string t, object emitter, int f, mixed ... args )
  //! See Messenger->emit_message for documentation
  {
    low_emit_message( ({}), umid++, emitter, t, f, args );
  }

  void low_emit_message( array(MessengerChain) visited,
                         int mid,
                         object emitter,
                         string type,
                         int flags, 
                         array args )
  //! See Messenger->low_emit_message for documentation
  {
    if( flags & DO_NOT_CHAIN )
      return;
    visited |= ({ this_object() });
    foreach( chained-visited, object ch )
      farm->run_async( ch->low_emit_message, 
                       visited, mid, emitter, 
                       type, flags, args );
  }
  
  void low_connect( MessengerChain m )
    //! Do a one-way connection between this Messenger and m.
    //! All messages emitted in this Messenger will be emitted in m.
  {
    chained |= ({ m });
  }

  void low_disconnect( MessengerChain m )
    //! Remove the connection between this Messenger and m, but do not
    //! remove the connection between m and this Messenger.
  {
    chained -= ({ m });
  }

  void connect( MessengerChain m )
    //! Connect the Messenger 'm' and this Messenger to each other.
    //! All messages emitted in 'm' will be emitted in this Messenger, and 
    //! all messages emitted in this Messenger will also be emitted in m.
  {
    low_connect( m );
    m->low_connect( this_object() );
  }

  void disconnect( MessengerChain m )
    //! Remove the connection between m and this Messenger, and
    //! between this messenger and m.
  {
    low_disconnect( m );
    m->low_disconnect( this_object() );
  }
}

class Messenger
//! Manages a tree of message types, and message emmission in it.
{
  inherit MessengerChain;

  string name;
  //! The name of the collection. Used for debug purposes only.
  int flags;
  //! Global flags. The only currently used flag is Messenger.DEBUG


  local mapping(string:array(MessageCallback)) cached_callbacks;

  local mapping(string:MessageType) registered_types = ([]);

  local mapping(string:MessageCallback) registered_callbacks = ([]);
  
  local array(MessageCallback) get_callbacks( string name, MessageType t )
  {
    string key = name+"\0"+t->name;
    if( cached_callbacks[ key ] )
      return cached_callbacks[ key ];

    array res = ({});
    foreach( registered_callbacks[ name ] || ({}), 
             MessageCallback c )
      if( ((c->flags|t->flags)&~(t->mask_flags)) | RUN_FIRST )
        res = ({ c }) + res;
      else
        res = res + ({ c });
    if( flags | DEBUG )
      werror("%s: Cached callbacks for %O is %O\n", 
             name, key, res );
    return cached_callbacks[ key ] = res;
  }

  local void add_callback( string key, MessageCallback cb )
  {
    cached_callbacks = set_weak_flag( ([]), 1 );
    registered_callbacks[ key ] += ({ cb });
    if( flags | DEBUG )
      werror("%s: add_callback( %O, %O )\n", key, cb );
  }

  local void remove_callback( string key, MessageCallback cb )
  {
    cached_callbacks = set_weak_flag( ([]), 1 );
    registered_callbacks[ key ] -= ({ cb });
    if( flags | DEBUG )
      werror("%s: remove_callback( %O, %O )\n", key, cb );
  }

  local void rec_emit( string path, Message m, int flags )
  {
    string name;
    path = reverse( path );
    sscanf( path, "%[^/]/%s", name, path );
    path = reverse( path );

    if( flags | DEBUG )
      werror("%s: rec_emit( %O, %O, %O )\n", path, m, flags );

    foreach( get_callbacks( name, m->type ), MessageCallback cb )
      cb->run( m, (flags | CAN_BLOCK_EMIT ) );
    if( strlen( path ) && search( path, "/" ) != -1 )
      rec_emit( path, m, flags );
  }

  local string rec_find_message_path( MessageType t )
  {
    string res = "/"+t->name;
    MessageType parent;
    foreach( Program.inherit_list( object_program( t ) ), program tt )
      if( Program.inherits( tt, MessageType ) )
      {
        parent = message_type( tt->name );
        break;
      }
    return parent ? rec_find_message_path( parent ) + res : res;
  }

  local string find_message_path( MessageType t )
  {
    string res = rec_find_message_path( t );
    if( flags | DEBUG )
      werror("%s: find_message_path( %O ) -> %s\n", t, res );
    return res;
  } 

  static void create( string id )
  {
    name = id;
  }

  static string _sprintf( )
  {
    return "Messenger( "+name+" )";
  }

  local string type_name( string|MessageType what  )
  {
    if( objectp( what ) )
      return what->name;
    return what;
  }

  MessageType message_type( string t )
 //! Returns the MessageType object associated with the type 't'
  {
    if( !registered_types[ t ] )
      error("Unknown message type: %O\n", t );
    return registered_types[ t ];
  } 

  void register_callback( string|MessageType type, function cb, int flags )
    //! Register a new callback for the specified message type.
    //! type is either a string or a MessageType object.
    //! Flags is a bitwise or of zero or more options from the following list:
    //! <dl>
    //!   <dt>RUN_UNTHREADED
    //!   <dd> The callback is newer run in more than one thread at once.
    //!        This is the default
    //!   <dt>RUN_THREADED
    //!   <dd>The callback may be run in any number of threads at once.
    //!   <dt>RUN_FIRST
    //!   <dd>The callback should be run before other callbacks of it's type.
    //!       The order between several RUN_FIRST callbacks is undefined.
    //!   <dt>CAN_BLOCK_EMIT
    //!   <dd>This callback may want to block the emisson of the message.
    //!       Not all messages can be blocked.
    //!   <dt>DEBUG
    //!   <dd>Print debug output when the callback is called.
    //!   <dt>ERROR_OK
    //!   <dd>Ignore errors that occurs while this callback is called
    //! </dl>
  {
    if( objectp( type ) )
      type = type_name( type );
    add_callback( type, MessageCallback( cb, flags ) );
  }

  void unregister_callback( string|MessageType type, function cb )
    //! Remove the callback cb from type type type. Type can be a
    //! MessageType object or a string.
  {
    if( objectp( type ) )
      type = type_name( type );
    foreach( registered_callbacks[type]||({}), MessageCallback c )
      if( c->cb == cb )
        remove_callback( type, c );
  }

  void register_type( MessageType t )
  //! Register a new MessageType.
  {
    if( registered_types[t->name] )
      error("Message type %s already registered (%O)\n", t->name, t );
    registered_types[t->name] = t;
  }

  void unregister_type( MessageType t )
  //! Unregister a previously registered MessageType
  {
    m_delete( registered_types, t->name );
  }


  int last;
  void low_emit_message( array(MessengerChain) visited, 
                         int mid,
                         object emitter,
                         string type, 
                         int flags, 
                         array args )
  //! Not normally called from user level code.
  //! Does a signal emission in this Messenger, and all chained
  //! messengers except the ones that have already had the message
  //! transmitted to them.
  {
    ::low_emit_message( visited, mid, emitter, type, flags, args );

    if( umid < mid )
      umid = mid+1;
    if( last == mid ) 
      return;

    if(MessageType t = message_type( type ))
      rec_emit( find_message_path( message_type( type ) ), 
                t->construct( emitter, mid, args ), flags );
  }

  void emit_message( string|MessageType type, object emitter,
                     int flags, mixed ... args )
  //! Emit a message of the specified type, with the specified flags
  //! and arguments.
  //! 
  //! All flags that are valid for message callback registration are
  //! valid, but specifying some of them (such as RUN_THREADED) might
  //! break the message callbacks quite miserably (since they might not
  //! expect to be run in threaded mode) while some others (such as

  //! CAN_BLOCK_EMIT and DO_NOT_CHAIN) can be used to override the 
  //! default behaviour of the message type.
  //! 
  //! If this Messenger is connected to other Messengers (see
  //! connect() and disconnect()) the emission will be done in them as
  //! well, if they have the message type specified as the first
  //! argument, otherwise there will be no emission in them, nor any
  //! error.
  //!
  //! Chained Messenger objects will reemit this signal in
  //! their chained Messenger objects.
  {
    MessageType t;
    if( !stringp( type ) )  
    {
      type = type->name;
      t = type;
    } else {
      t = message_type ( type );
    }
    flags = (flags | t->flags) & ~t->mask_flags;
    ::emit_message( type, emitter, flags, @args );
  }
}

local int mnp;
Messenger `()( string id )
//! Create a new messenger, using the specified string as an identifier.
//! The identifier is used for debug purposes only.
{
  mnp+=8;
  farm->set_max_num_threads( mnp );
  return Messenger( id );
}
