/*
 * Roxen master
 */
string cvs_version = "$Id: roxen_master.pike,v 1.90 2000/04/10 21:17:12 mast Exp $";

/*
 * name = "Roxen Master";
 * doc = "Roxen's customized master.";
 */

// Disable the precompiled file is out of date warning.
#ifndef OUT_OF_DATE_WARNING
constant out_of_date_warning = 0;
#endif /* !OUT_OF_DATE_WARNING */

class MyCodec
{
  program p;
  string nameof(mixed x)
  {
    if(zero_type(x)) return ([])[0];
    if( x == 0 )     return 0;

    if(p!=x)
      if(mixed tmp=search(all_constants(),x))
	return "efun:"+tmp;

    if (programp (x)) {
      if(p!=x)
      {
	mixed tmp;
	if(tmp=search(master()->programs,x))
	  return tmp;

	if((tmp=search(values(_static_modules), x))!=-1)
	  return "_static_modules."+(indices(_static_modules)[tmp]);
      }
    }
    else if (objectp (x)) {
      array(string) ids = ({});
      while (1) {
	if(mixed tmp=search(master()->objects,x))
	{
	  if(tmp=search(master()->programs,tmp))
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
    return ([])[0];
  }

  function functionof(string x)
  {
    if(!stringp(x))
      return lambda(){};

    if(sscanf(x,"efun:%s",x) && functionp(all_constants()[x]))
      return all_constants()[x];
    error("Failed to decode function %s\n",x);
  }


  object objectof(string x)
  {
    if(!stringp(x))
      return class{}();

    if(sscanf(x,"efun:%s",x))
    {
      if( !objectp( all_constants()[x] ) )
        error("Failed to decode object efun:%s\n", x );
      return all_constants()[x];
    }
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
    if(sscanf(x,"efun:%s",x))
      return (program)all_constants()[x];

    if(sscanf(x,"_static_modules.%s",x))
      return (program)_static_modules[x];

    if(program tmp=(program)x) {
      return tmp;
    }
    error("Failed to decode program %s\n", x );
  }

  mixed encode_object(object x)
  {
    error("Cannot encode objects yet.\n");
  }

  mixed decode_object(object x)
  {
    error("Cannot decode objects yet.\n");
  }

  void create( program|void q )
  {
    p = q;
  }
}


object mm=(object)"/master";
inherit "/master";


mapping handled = ([]);

mapping(program:string) program_names = set_weak_flag (([]), 1);

string dump_path = "../var/"+roxen_version()+"/precompiled/"+
  uname()->machine+"."+uname()->release + "/";

string make_ofilename( string from )
{
  return dump_path+sprintf( "%s-%d-%08x.o",
                            ((from/"/")[-1]/".")[0],getuid(),hash(from));
}

void dump_program( string pname, program what )
{
  string outfile = make_ofilename( pname );
  string data;
#ifdef DUMP_PROGRAM_BUG
  if (!catch (data = encode_value( what, MyCodec( what ) ) ))
#else
  data = encode_value( what, MyCodec( what ) );
#endif
  { mkdirhier( outfile );
#if constant( chmod )
    chmod( dirname( outfile ), 01777  );
#endif
    _static_modules.files()->Fd(outfile,"wct")->write(data);
#if constant( chmod )
    chmod( outfile, 0664  );
#endif
  }
#ifdef DUMP_PROGRAM_BUG
  else
  { array parts = pname / "/";
    if (sizeof(parts) > 3) parts = parts[sizeof(parts)-3..];
    werror("Couldn't dump " + parts * "/" + "\n");
  }
#endif
}

int loaded_at( program p )
{
  return load_time[ program_name (p) ];
}

// Make low_findprog() search in precompiled/ for precompiled files.
array(string) query_precompiled_names(string fname)
{
  return ({ make_ofilename(fname) }) + ::query_precompiled_names(fname);
}

array master_file_stat(string x) 
{ 
  return file_stat( x ); 
}

#define master_file_stat( x ) file_stat( x )


#if constant(_static_modules.Builtin.mutex)
#define THREADED
// NOTE: compilation_mutex is inherited from the original master.
#endif

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

  if( !handler ) handler = get_inhibit_compile_errors();

  if( (s=master_file_stat( fname )) && s[1]>=0 )
  {
    if( load_time[ fname ] > s[ 3 ] )
      if( !zero_type (ret = programs[fname]) )
        return ret;

    switch(ext)
    {
    case "":
    case ".pike":
      foreach(query_precompiled_names(fname), string ofile )
      {
        if(array s2=master_file_stat( ofile ))
        {
          if(s2[1]>0 && s2[3]>=s[3])
          {
            mixed err = catch
            {
              load_time[ fname ] = time();
              ret = programs[fname]=
                     decode_value(_static_modules.files()->
                                  Fd(ofile,"r")->read(),MyCodec());
	      program_names[ret] = fname;
	      return ret;
            };
	    string msg = sprintf("Failed to decode dumped file for %s: %s\n",
				 trim_file_name (fname), describe_error(err));
	    if (ofile[..sizeof (dump_path) - 1] == dump_path)
	      ofile = ofile[sizeof (dump_path)..];
	    if (handler) {
	      handler->compile_warning(ofile, 0, msg);
	    } else {
	      compile_warning(ofile, 0, msg);
	    }
	  }
        }
      }
      if ( mixed e=catch { ret=compile_file(fname); } )
      {
	// load_time[fname] = time(); not here, no.... reload breaks miserably
	programs[fname]=([])[0];
        if(arrayp(e) && sizeof(e) && e[0] == "Compilation failed.\n")
          e[1]=({});
	throw(e);
      }
//    dump_program( fname, ret );
      break;
#if constant(load_module)
    case ".so":
      ret=load_module(fname);
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
    rm( make_ofilename( fname ) );
    return 1;
  }

  array s=file_stat( fname );

  if( s && s[1]>=0 )
  {
    if( load_time[ fname ] > s[ 3 ] )
      return 0;
  }
  else
    return -1; /* No such file... */

  m_delete( programs, fname );
  m_delete( load_time, fname );
  rm( make_ofilename( fname ) );
  return 1;
}

int recursively_check_inherit_time(program root, array up, mapping done)
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

string stupid_describe(mixed m, int maxlen)
{
  string typ;
  if (catch (typ=sprintf("%t",m)))
    typ = "object";		// Object with a broken _sprintf(), probably.
  switch(typ)
  {
    case "int":
    case "float":
      return (string)m;

    case "string":
      canclip++;
      if(sizeof(m) < 40)
        return  sprintf("%O", m);;
      clipped++;
      return sprintf("%O+[%d]+%O",m[..15],sizeof(m)-(32),m[sizeof(m)-16..]);

    case "array":
      if(!sizeof(m)) return "({})";
      return "({" + stupid_describe_comma_list(m,maxlen-2) +"})";

    case "mapping":
      if(!sizeof(m)) return "([])";
      return "mapping["+sizeof(m)+"]";

    case "multiset":
      if(!sizeof(m)) return "(<>)";
      return "multiset["+sizeof(m)+"]";

    case "function":
      if(string tmp=describe_program(m)) return tmp;
      if(object o=function_object(m))
	return (describe_object(o)||"")+"->"+function_name(m);
      else {
	string tmp;
	if (catch (tmp = function_name(m)))
	  // The function object has probably been destructed.
	  return "function";
	return tmp || "function";
      }

    case "program":
      if(string tmp=describe_program(m)) return tmp;
      return typ;

    default:
      if (objectp(m))
	if(string tmp=describe_object(m)) return tmp;
      return typ;
  }
}


constant bt_max_string_len = 99999999;
int long_file_names;

string describe_backtrace(mixed trace, void|int linewidth)
{
  return ::describe_backtrace(trace, 999999);
}


void create()
{
  object o = this_object();
  /* Copy variables from the original master */
  foreach(indices(mm), string varname) {
    catch(o[varname] = mm[varname]);
    /* Ignore errors when copying functions */
  }

  foreach( indices(programs), string f )
    load_time[ f ] = time();

  programs["/master"] = object_program(o);
  program_names[object_program(o)] = "/master";
  objects[ object_program(o) ] = o;
  /* Move the old efuns to the new object. */

  foreach(master_efuns, string e)
    add_constant(e, o[e]);
}
