/*
 * Roxen master
 */
string cvs_version = "$Id: roxen_master.pike,v 1.67 1999/12/29 18:31:24 mast Exp $";

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
    if(p!=x)
      if(mixed tmp=search(all_constants(),x))
	return "efun:"+tmp;

    switch(sprintf("%t",x))
    {
      case "program":
	if(p!=x)
	{
          mixed tmp;
	  if(tmp=search(master()->programs,x))
	    return tmp;

	  if((tmp=search(values(_static_modules), x))!=-1)
	    return "_static_modules."+(indices(_static_modules)[tmp]);
	}
	break;

      case "object":
	if(mixed tmp=search(master()->objects,x))
	{
	  if(tmp=search(master()->programs,tmp))
	  {
	    return tmp;
	  }
	}
	break;
    }

    return ([])[0];
  }

  function functionof(string x)
  {
    if(sscanf(x,"efun:%s",x))
      return all_constants()[x];

    werror("Failed to decode %s\n",x);
    return 0;
  }


  object objectof(string x)
  {
    if(sscanf(x,"efun:%s",x))
      return all_constants()[x];

    if(object tmp=(object)x) return tmp;
    werror("Failed to decode %s\n",x);
    return 0;
    
  }

  program programof(string x)
  {
    if(sscanf(x,"efun:%s",x))
      return all_constants()[x];

    if(sscanf(x,"_static_modules.%s",x))
    {
      return (program)_static_modules[x];
    }

    if(program tmp=(program)x) return tmp;
    werror("Failed to decode %s\n",x);
    return 0;
  }

  mixed encode_object(object x)
  {
    error("Cannot encode objects yet.\n");
  }

  mixed decode_object(object x)
  {
    error("Cannot encode objects yet.\n");
  }

  void create( program q )
  {
    p = q;
  }
}


object mm=(object)"/master";
inherit "/master";


mapping handled = ([]);

mapping(program:string) program_names = set_weak_flag (([]), 1);

string make_ofilename( string from )
{
  return "precompiled/"+
         (hash(from)+""+
          hash(reverse(from))+""+
          hash(from[strlen(from)/2..]))
         +".o";
}

void dump_program( string pname, program what )
{
  string outfile = make_ofilename( pname );
  string data = encode_value( what, MyCodec( what ) );
  if (catch {
    _static_modules.files()->Fd(outfile,"wct")->write(data);
  }) {
    mkdir("precompiled");
    _static_modules.files()->Fd(outfile,"wct")->write(data);
  }
} 

int loaded_at( program p )
{
  return load_time[ program_name (p) ];
} 

// Make low_find_prog() search in precompiled/ for precompiled files.
array(string) query_precompiled_names(string fname)
{
  return ({ make_ofilename(fname) }) + ::query_precompiled_names(fname);
}

program low_findprog(string pname, string ext, object|void handler)
{
  program ret;
  array s;
  string fname=pname+ext;

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
                                  Fd(ofile,"r")->read(),Codec());
	      program_names[ret] = fname;
	      return ret;
            };
	    if (handler) {
	      handler->compile_warning(ofile, 0,
				       sprintf("Decode failed:\n"
					       "\t%s", err[0]));
	    } else {
	      compile_warning(ofile, 0,
			      sprintf("Decode failed:\n"
				      "\t%s", err[0]));
	    }
	  }
        }
      }

      if ( mixed e=catch { ret=compile_file(fname); } )
      {
	if(arrayp(e) && sizeof(e) && stringp (e[0]))
	  if (handler) handler->compile_error(fname, 0, e[0]);
	  else compile_error(fname, 0, e[0]);
      }
      break;
#if constant(load_module)
    case ".so":
      ret=load_module(fname);
#endif
    }
    program_names[ret] = fname;
    load_time[fname] = time();
    return programs[fname] = ret;
  }
  return 0;
}

int refresh( program p, int|void force )
{
  string fname = program_name( p );
  if(!fname) return 0; /*  Already rather fresh. :) */

  if( force )
  {
    m_delete( programs, fname );
    rm( make_ofilename( fname ) );
    return 1;
  }

  /*
   * No need to do anything right now, low_findprog handles 
   * refresh automatically. 
   *
   * simply return 1 if a refresh will take place.
   *
   */
  array s=file_stat( fname );

  if( s && s[1]>=0 )
  {
    if( load_time[ fname ] > s[ 3 ] )
    {
      return 0;
    }
  } else {
    return -1; /* No such file... */
  }

//   werror("****** refreshing "+fname+"\n");
  m_delete( programs, fname );
  rm( fname+".o" );
  rm( make_ofilename( fname ) );
  low_findprog( fname, "", 0 );
  return 1;
}

int recursively_check_inherit_time(program root, array up, mapping done)
{
  int res;
  if( done[ root ]++ )
    return 0;
  
//   if(!sizeof(up)) werror("\n\n");
//   werror("**"+("-"*sizeof(up))+" checking "+program_name( root )+"\n");

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
  switch(string typ=sprintf("%t",m))
  {
    case "int":
    case "float":
      return (string)m;
      
    case "string":
      canclip++;
      if(sizeof(m) < 40)
        return  sprintf("%O", m);;
      clipped++;
      return sprintf("%O+[%d]",m[..34],sizeof(m)-(35));
      
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
      else
	return function_name(m) || "function";
      
    case "program":
      if(string tmp=describe_program(m)) return tmp;
      return typ;

    case "object":
      if(string tmp=describe_object(m)) return tmp;
      return typ;

    default:
      return typ;
  }
}


constant bt_max_string_len = 99999999;
int long_file_names;

string describe_backtrace(mixed trace, void|int linewidth)
{
  return ::describe_backtrace(trace, 999999);

  int e;
  string ret;
  linewidth=999999;

  if((arrayp(trace) && sizeof(trace)==2 && stringp(trace[0])) ||
     (objectp(trace) && trace->is_generic_error))
  {
    if (catch {
      ret = trace[0];
      trace = trace[1];
    }) {
      return "Error indexing backtrace!\n";
    }
  }else{
    ret="";
  }

  if(!arrayp(trace))
  {
    ret+="No backtrace.\n";
  }else{
    for(e = sizeof(trace)-1; e>=0; e--)
    {
      mixed tmp;
      string row;

      if (mixed err=catch 
      {
	tmp = trace[e];
	if(stringp(tmp))
	{
	  row=tmp;
	}
	else if(arrayp(tmp))
	{
	  string pos;
	  if(sizeof(tmp)>=2 && stringp(tmp[0]) && intp(tmp[1]))
	  {
            if( !long_file_names )
              pos=trim_file_name(tmp[0])+":"+tmp[1];
            else
              pos=tmp[0]+":"+tmp[1];
	  }else{
	    mixed desc="Unknown program";
	    if(sizeof(tmp)>=3 && functionp(tmp[2]))
	    {
	      catch {
		if(mixed tmp=function_object(tmp[2]))
		  if(tmp=object_program(tmp))
		    if(tmp=describe_program(tmp))
		      desc=tmp;
	      };
	    }
	    pos=desc;
	  }
	  
	  string data;
	  
	  if(sizeof(tmp)>=3)
	  {
	    if(functionp(tmp[2]))
	      data = function_name(tmp[2]);
	    else if (stringp(tmp[2])) {
	      data= tmp[2];
	    } else
	      data ="unknown function";
	    
	    data+="("+
	      stupid_describe_comma_list(tmp[3..], 99999999)+
	    ")";

	    if(sizeof(pos)+sizeof(data) < linewidth-4)
	    {
	      row=sprintf("%s: %s",pos,data);
	    }else{
	      row=sprintf("%s:\n%s",pos,sprintf("    %*-/s",linewidth-6,data));
	    }
	  }
	}
	else
	{
	  row="Destructed object";
	}
      }) {
	row += sprintf("Error indexing backtrace line %d (%O)!", e, err[1]);
      }
      ret += row + "\n";
    }
  }

  return ret;
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
