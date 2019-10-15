object mm=(object)"/master";
inherit "/master": master;

mixed sql_query( string q, mixed ... e )
{
  return connect_to_my_mysql( 0, "local" )->query( q, @e );
}

/*
 * Roxen's customized master.
 */

constant cvs_version = "$Id$";

// Disable the precompiled file is out of date warning.
constant out_of_date_warning = 0;

#if !constant(PIKE_MODULE_RELOC)
#define relocate_module(x) (x)
#define unrelocate_module(x) (x)
#endif

#define SECURITY_DEBUG 1

#include <security.h>


#ifdef SECURITY
#if constant(thread_local)
static object chroot_dir = thread_local();
#else
static string chroot_dir = "";
#endif

static void low_set_chroot_dir( string to )
{
#if constant(thread_local)
  chroot_dir->set( to );
#else
  chroot_dir = to;
#endif
}

static string low_get_chroot_dir( )
{
#if constant(thread_local)
  return chroot_dir->get( );
#else
  return chroot_dir;
#endif
}

class ChrootKey( string old_dir )
{
  void destroy( )
  {
    low_set_chroot_dir( old_dir );
  }
}

ChrootKey chroot( string to )
{
  CHECK_SECURITY_BIT( SECURITY );
  ChrootKey key = ChrootKey( low_get_chroot_dir() );
  low_set_chroot_dir( to );
  return key;
}
  

class UID
{
  inherit Creds;

  static string _name;
  static string _rname;
  static int _uid, _gid;
  static int _data_bits, _allow_bits;
  static int io_bits = BIT_IO_CHROOT | BIT_IO_CAN_READ | BIT_IO_CAN_WRITE | BIT_IO_CAN_CREATE;
  static string always_chroot;
  
  constant modetobits = (["read":2, "write":4,   ]);

  UID set_io_bits( int to )
  {
    CHECK_SECURITY_BIT( SECURITY );
    io_bits = to;
    return this_object();
  }

  string chroot( string dir )
  {
    always_chroot = dir;
    if( dir )
      io_bits |= BIT_IO_CHROOT; // enforced chroot
    else
      io_bits &= BIT_IO_CHROOT; // enforced not chroot
  }
  
  int gid()   { return _gid; }
  int uid()   { return _uid; }

  /* Callback functions */
  int valid_open( string dir,
		  object current_object,
		  string file,
		  string mode,
		  int access )
  {
    string chroot_dir;
    file = combine_path( getcwd(), file );
#ifdef SECURITY_DEBUG
    werror("Security: valid_open( %O, %O, %o ) from %O\n", file, mode, access, current_object );
#endif
    if( (io_bits & BIT_IO_CHROOT) &&
	((chroot_dir=always_chroot) || (chroot_dir=low_get_chroot_dir()))
	&& search( file, chroot_dir ) )
    {
#ifdef SECURITY_DEBUG
      werror("Security error: Chroot set, but this file is not in it\n");
#endif
      return 3;
    }
    
    if( !(io_bits & modetobits[ dir ] ) )
    {
#ifdef SECURITY_DEBUG
      werror("Security error: Lacks bit for %O\n", dir );
#endif
      return 3;
    }

    mixed stat;

    if( !(io_bits & BIT_IO_CAN_CREATE) && !(stat = file_stat( file ) ) )
    {
#ifdef SECURITY_DEBUG
      werror("Security error: File does not exist, and user lacks permisson for create\n");
#endif
      return 0; // No such file
    }
    else  if( !stat )
      stat = file_stat( file );
#ifndef __NT__
    if( stat )
    {
      if( (io_bits & BIT_IO_ONLY_OWNED) && (stat->uid != _uid) )
      {
#ifdef SECURITY_DEBUG
	werror("Security error: ONLY_OWNED but file not owned\n");
#endif
	return 3;
      }
      if( (io_bits & BIT_IO_OWNED_AND_GROUP) && (stat->uid != _uid) && (stat->gid != _gid) )
      {
#ifdef SECURITY_DEBUG
	werror("Security error: ONLY_GROUP_AND_OWNED but file not owned/nor group\n");
#endif
	return 3;
      }
    }
    if( !(io_bits & BIT_IO_USER_OK) )
    {
      if( !stat )
      {
	dir = "create";
	stat = file_stat( dirname( file ) );
      }
      if(!stat)
      {
#ifdef SECURITY_DEBUG
	werror("Security error: File and directory both missing.\n");
#endif 
	return 2; // Not possible...
      }
      // check permission for the operation here, using more or less
      // normal unix semantics.
    }
#endif
#ifdef SECURITY_DEBUG
    werror("Security: Open of %O ok\n", file );
#endif 
    return 2;
  }

  int valid_io( string operation, string dir, mixed ... args )
  {
#ifdef SECURITY_DEBUG
    werror("valid_io( "+operation+", "+dir+" )\n" );
#endif
    if( !(io_bits & modetobits[ dir ] ) )
    {
#ifdef SECURITY_DEBUG
      werror("Security error: Lacks bit for %O\n", dir );
#endif
      return 0;
    }
    
//     switch( operation )
//     {
//       // ...
//     }
#ifdef SECURITY_DEBUG
    werror("Security: IO ok\n" );
#endif 
    return 2;
  }


  Creds own( mixed what, int|void bits )
  {
    Creds creds;
    if( !zero_type(bits) && (bits != get_data_bits()) )
      creds = Creds( this_object(), get_allow_bits(), bits );
    else
      creds = this_object();
    creds->apply( what );
    return creds;
  }

  mixed call( function what, mixed  ... args )
  {
    return call_with_creds( this_object(), what, @args );
  }

  mixed call_with_bits( function what, int bits, mixed ... args )
  {
    return call_with_creds( Creds( this_object(), bits, get_data_bits() ), what, @args );
  }

  Creds get_new_creds( int allow_bits, int data_bits )
  {
    return Creds( this_object(), allow_bits, data_bits );
  }
  
  void create( string name, string rname,
	       int uid, int gid, 
	       int allow_bits,
	       int data_bits )
  {
    _name = name;
    _rname = rname;
    _uid = uid;
    _gid = gid;
    ::create( this_object(), allow_bits, data_bits );
  }

  static string _sprintf( )
  {
    return sprintf("UID( %s (%s) )",_name,_rname);
  }
}

void init_security()
{
  werror("Initializing security system...");
  add_constant( "chroot", chroot );
  root->own( this_object() );
//   root->call(   Stdio.File, "/tmp/foo", "wct");
  werror("Done\n");
}

// There are three bit groups.
//   may_always bits
//   data bits        (overridden by may_always of current user)
//   io bits          (used in valid_io and valid_open)


// The root user can do everything. But objects owned by it cannot be
// destructed by anyone but the root user.
UID root   = UID( "root", "Supersture",0,0, ~0, ~BIT_DESTRUCT );


// The nobody user cannot do anything, basically (it can read/stat files, though)
UID nobody = UID( "nobody", "Nobody", 65535,65535,  BIT_CONDITIONAL_IO, ~0 )
             ->set_io_bits( BIT_IO_CHROOT | BIT_IO_CAN_READ );

// Default roxen user. Basically the same as the root user, but the IO bits apply.
// More specifically, the chroot() function works.
UID roxen = UID( "roxen", "Roxen internal user", getuid(), getgid(),
		 ~BIT_SECURITY, ~BIT_DESTRUCT );

// Like nobody, but cannot read files either.
UID luser = UID( "luser", "total luser", 65535, 65535, 0, 0 );
#else


void init_security()
{
  add_constant( "chroot", lambda(string new){ return class{}(); } );
}
#endif

mapping dump_constants = ([]), dump_constants_rev = ([]);


mixed add_dump_constant( string f, mixed what )
{
  if(!what) return 0;
  dump_constants_rev[ dump_constants[ f ] = what ] = f;
  catch(dump_constants_rev[ (program)what ] = f);
  return what;
}

class MyCodec
{
  program p;
#ifdef DUMP_DEBUG
  mixed last_failed;
#endif
  string nameof(mixed x)
  {
    if(zero_type(x)) return ([])[0];
    if( x == 0 )     return 0;

    if(p!=x)
    {
      if( string n = dump_constants_rev[ x ] )
	return "defun:"+n;
      if(mixed tmp=search(all_constants(),x))
	return "efun:"+tmp;
      if ( programp (x) )
      {
	mixed tmp;
	if(tmp=search(programs,x))
	  return tmp;

	if((tmp=search(values(_static_modules), x))!=-1)
	  return "_static_modules."+(indices(_static_modules)[tmp]);

	if( (program)x != x )
	  return nameof( (program)x );
#ifdef DUMP_DEBUG
	last_failed = x;
#endif
	return ([])[ 0 ];
      }
    }

    if (objectp (x)) 
    {
      array(string) ids = ({});
      if(x->is_resolv_dirnode)
      {
        /* FIXME: this is a bit ad-hoc */
        string dirname=x->dirname;
        dirname-=".pmod";
        sscanf(dirname,"%*smodules/%s",dirname);
        dirname=replace(dirname,"/",".");
        if(resolv(dirname) == x)
          return "resolv:"+dirname;
      }
      while (1) 
      {
	if(mixed tmp=search(objects,x))
	{
	  if(tmp=search(programs,tmp))
	  {
	    if (sizeof (ids)) return tmp + "//" + ids * ".";
	    else return tmp;
	  }
	}
	object parent;
	if (!catch (parent = function_object (object_program (x))) && parent) {
	  array ind = indices (parent), val = values (parent);
	  int i = search (val, x);
	  if (i > -1) {
	    x = parent;
	    ids = ({ind[i]}) + ids;
	    continue;
	  }
	}
	break;
      }
      if( x == mm )
	return "/master";
    }
#ifdef DUMP_DEBUG
    last_failed = x;
#endif
    return ([])[0];
  }

  function functionof(string x)
  {
    if(!stringp(x))
      return lambda(){};
    if( sscanf(x,"defun:%s",x) )
      return dump_constants[x];
    if( sscanf(x,"efun:%s",x) )
      return all_constants()[x];
    if(sscanf(x,"resolv:%s",x)) 
      return resolv(x);
    error("Failed to decode function %s\n",x);
  }


  object objectof(string x)
  {
    if(!stringp(x))
      return class{}();
    if( sscanf(x,"defun:%s",x) )
      return dump_constants[x];
    if(sscanf(x,"efun:%s",x))
    {
#ifdef DUMP_DEBUG
      if( !objectp( all_constants()[x] ) )
        error("Failed to decode object efun:%s\n", x );
#endif
      return all_constants()[x];
    }
    if(sscanf(x,"resolv:%s",x)) 
      return resolv(x);
    sscanf (x, "%s//%s", x, string ids);
    object tmp;
    if(objectp(tmp=(object)x)) {
      if (ids)
	foreach (ids / ".", string id)
	  if (!objectp (tmp = tmp[id]))
	    error("Failed to decode object %s\n", x );
      return tmp;
    }
    return 0;
  }

  program programof(string x)
  {
    if( sscanf(x,"defun:%s",x) )
#ifdef DUMP_DEBUG
      if( !programp(dump_constants[x] ) )
	werror("%O is not a program, from dc:%O\n", dump_constants[x],x );
      else
#endif
	return dump_constants[x];
    if(sscanf(x,"efun:%s",x))
#ifdef DUMP_DEBUG
      if( !programp(all_constants()[x] ) )
	werror("%O is not a program, from efun:%O\n", all_constants()[x],x );
      else
#endif
	return (program)all_constants()[x];
    if(sscanf(x,"_static_modules.%s",x))
      return (program)_static_modules[x];
    if(sscanf(x,"resolv:%s",x))
#ifdef DUMP_DEBUG
      if( !programp(resolv(x) ) )
	werror("%O is not a program, from resolv:%O\n", resolv(x),x );
      else
#endif
	return resolv(x);
    if(program tmp=(program)x)
      return tmp;
    error("Failed to decode program %s\n", x );
  }

  mixed encode_object(object x)
  {
    if(x->_encode) return x->_encode();
    error("Cannot encode objects without _encode/_decode yet.\n");
  }

  mixed decode_object(object x, mixed data)
  {
    if( x->_decode )
      x->_decode(data);
    else
      error("Cannot decode objects yet.\n");
  }

  void create( program|void q )
  {
    p = q;
  }
}


#ifdef __NT__
string getcwd()
{
  return replace (::getcwd(), "\\", "/");
}
#endif

mapping handled = ([]);

mapping(program:string) program_names = set_weak_flag (([]), 1);

string make_ofilename( string from )
{
  return sprintf( "%s-%x",
                  ((from/"/")[-1]/".")[0],hash(from));
}

void dump_program( string pname, program what )
{
  string index = make_ofilename( pname );
  string data;
#ifdef DUMP_DEBUG
  MyCodec cd;
  if (!catch (data = encode_value( what, (cd = MyCodec( what )) ) ))
#else
  data = encode_value( what, MyCodec( what ) );
#endif
  {
    sql_query( "DELETE FROM precompiled_files WHERE id=%s",index );
    sql_query( "INSERT INTO precompiled_files values (%s,%s,%d)",
	       index, data, time(1) );
  }
#ifdef DUMP_DEBUG
  else
  {
    array parts = pname / "/";
    if (sizeof(parts) > 3) parts = parts[sizeof(parts)-3..];
    werror("Couldn't dump " + parts * "/" + "\n");
    werror("Last attempted: %O\n", cd->last_failed );
    mixed w = Describer()->describe( cd->last_failed,10000 );
    if( w == "program" ) w = _typeof( cd->last_failed );
    werror( "  Type: %O\n",w);
    mixed e = catch {
      object q = cd->last_failed();
      werror("%O\n", mkmapping( indices(q), values(q) ) );
    };
    if( e )
      werror( describe_error( e )+"\n");
    werror("\n");
  }
#endif
}

int loaded_at( program p )
{
  return load_time[ program_name (p) ];
}

// array(string) query_precompiled_names(string fname)
// {
//   return ({ make_ofilename(fname) }) + ::query_precompiled_names(fname);
// }

array master_file_stat(string x) 
{ 
  lambda(){}(); // avoid some optimizations
  mixed y = file_stat( x );
  return y?(array(int))y:0;
}

#if constant(_static_modules.Builtin.mutex)
#define THREADED
// NOTE: compilation_mutex is inherited from the original master.
#endif

mapping(string:function|int) has_set_on_load = ([]);
void set_on_load( string f, function cb )
{
  has_set_on_load[ f ] = cb;
}

program low_findprog(string pname, string ext, object|void handler)
{
  program ret;
  array s;
  string fname=pname+ext;

#ifdef THREADED
  object key;
  // FIXME: The catch is needed, since we might be called in
  // a context when threads are disabled.
  // (compile() disables threads).
  catch {
    key=compilation_mutex->lock(2);
  };
#endif

#if constant(PIKE_MODULE_RELOC)
  fname = unrelocate_module(fname);
#endif

  if( !handler ) handler = get_inhibit_compile_errors();

  if( (s=master_file_stat( relocate_module(fname) )) && s[1]>=0 )
  {
    if( load_time[ fname ] > s[ 3 ] )
      if( !zero_type (ret = programs[fname]) )
        return ret;

    switch(ext)
    {
    case "":
    case ".pike":
      // First check in mysql.
      array q;

#ifdef DUMP_DEBUG
#define DUMP_WARNING(fname,err)                                         \
          werror("Failed to decode dumped file for %s: %s",             \
                 trim_file_name (fname), describe_error(err));
#define DDEBUG( X, Y ) werror( X, Y )
#else
#define DUMP_WARNING(f,e)
#define DDEBUG( X, Y )
#endif
#define LOAD_DATA( DATA )                                                    \
      do {                                                                   \
        mixed err = catch                                                    \
        {                                                                    \
          load_time[ fname ] = time();                                       \
          programs[ fname ] = 0;                                             \
          ret = programs[ fname ] = decode_value( DATA, MyCodec() );         \
          program_names[ ret ] = fname;                                      \
          m_delete(has_set_on_load, fname );                                 \
          return ret;                                                        \
        }; DUMP_WARNING(fname,err)                                           \
      } while(0)
      if(sizeof(q=sql_query( "SELECT data,mtime FROM precompiled_files WHERE id=%s",
			     make_ofilename( fname ))))
        if( (int)q[0]->mtime > s[3] )
          LOAD_DATA( q[0]->data );

      foreach(query_precompiled_names(fname), string ofile )
        if(array s2=master_file_stat( ofile ))
          if(s2[1]>0 && s2[3]>=s[3])
            LOAD_DATA( Stdio.File( ofile,"r")->read() );

      DDEBUG( "Really compile: %O ", fname );
#ifdef DUMP_DEBUG
      int t = gethrtime();
#endif
      if ( mixed e=catch { ret=compile_file(fname); } )
      {
	// load_time[fname] = time(); not here, no.... reload breaks miserably
	//
	// Yes indeed here. How else avoid many many recompilations of
	// a module that's broken and referenced from a gazillion
	// places? This also avoids the dreaded infinite loop during
	// compilation that could occur with misspelled identifiers in
	// pike modules. /mast
	load_time[fname] = time();
	programs[fname]=0;
        if(arrayp(e) && sizeof(e) &&
	   (<"Compilation failed.\n", "Cpp() failed\n">)[e[0]])
          e[1]=({});
	DDEBUG( "FAILED\n",0 );
	throw(e);
      }
      DDEBUG( "%dms\n", (gethrtime()-t)/1000 );
      function f;
      if( functionp( f = has_set_on_load[ fname ] ) )
      {
        has_set_on_load[ fname ] = 1;
	call_out(f,0.1,fname, ret );
      }
      else
        has_set_on_load[ fname ] = 1;
      break;
#if constant(load_module)
    case ".so":
      ret=load_module(relocate_module(fname));
#endif
    }
    program_names[ret] = fname;
    if( ret )
      load_time[fname] = time();
    return programs[fname] = ret;
  }
  return 0;
}

void handle_error(array(mixed)|object trace)
{
  catch {
    if (arrayp (trace) && sizeof (trace) == 2 &&
	arrayp (trace[1]) && !sizeof (trace[1]))
      // Don't report the special compilation errors thrown above. Pike
      // calls this if resolv() or similar throws.
      return;
  };
  ::handle_error (trace);
}

void clear_compilation_failures()
{
  foreach (indices (programs), string fname)
    if (!programs[fname]) m_delete (programs, fname);
}

int refresh( program p, int|void force )
{
  string fname = program_name( p );
  if(!fname)
  {
    return 1; /*  Not loaded.. */
  }

  if( force )
  {
    m_delete( programs, fname );
    m_delete( load_time, fname );
    sql_query( "DELETE FROM precompiled_files WHERE id=%s",
	       make_ofilename(fname) );
    return 1;
  }

  array s=master_file_stat( fname );

  if( s && s[1]>=0 )
  {
    if( load_time[ fname ] > s[ 3 ] )
      return 0;
  }
  else
    return -1; /* No such file... */

  m_delete( programs, fname );
  m_delete( load_time, fname );
  sql_query( "DELETE FROM precompiled_files WHERE id=%s",
	     make_ofilename(fname));
  return 1;
}

int recursively_check_inherit_time(program root, array up, mapping done)
{
  catch
  {
    int res;
    if( done[ root ]++ )
      return 0;

    foreach( Program.inherit_list( root ), program p )
      res+=recursively_check_inherit_time( p, up+({root}), done );

    if( !res && (refresh( root )>0 ))
    {
      res++;
      map( up+({root}), refresh, 1 );
    }

    return res;
  };
}

int refresh_inherit( program what )
{
  int ret = recursively_check_inherit_time( what, ({}), ([]) );;
  return ret;
}


string program_name(program p)
{
  return program_names[p];
}

void name_program( program p, string name )
{
  programs[name] = p;
  load_time[ name ] = time();
}

class Describer
{
  inherit master::Describer;

  string describe_string (string m, int maxlen)
  {
    canclip++;
    if(sizeof(m) < 40)
      return  sprintf("%O", m);;
    clipped++;
    return sprintf("%O+[%d]+%O",m[..15],sizeof(m)-(32),m[sizeof(m)-16..]);
  }

  string describe_array (array m, int maxlen)
  {
    if(!sizeof(m)) return "({})";
    return "({" + describe_comma_list(m,maxlen-2) +"})";
  }
}

constant bt_max_string_len = 999999;
int long_file_names;

string describe_backtrace(mixed trace, void|int linewidth)
{
  linewidth = (linewidth ? min(linewidth, bt_max_string_len)
                         : bt_max_string_len);
  return predef::describe_backtrace(trace, linewidth);
}


void create()
{
  object o = this_object();
  /* Copy variables from the original master */
  foreach(indices(mm), string varname) {
    catch(o[varname] = mm[varname]);
    /* Ignore errors when copying functions */
  }

  init_security();
    
  foreach( indices(programs), string f )
    load_time[ f ] = time();

  programs["/master"] = object_program(o);
  program_names[object_program(o)] = "/master";
  objects[ object_program(o) ] = o;
  /* Move the old efuns to the new object. */

  add_constant("add_dump_constant", add_dump_constant);
  foreach(master_efuns, string e)
    add_constant(e, o[e]);
}
