#include <module.h>
mapping variables = ([ ]);
mapping locs = ([]);

void deflocaledoc( string locale, string variable,
                   string name, string doc, mapping|void translate)
{
  if(!locs[locale] )
    locs[locale] = master()->resolv("Locale")["Roxen"][locale]
                 ->register_module_doc;
  if(!locs[locale])
    report_debug("Invalid locale: "+locale+". Ignoring.\n");
  else
    locs[locale]( this_object(), variable, name, doc, translate );
}

void set( string what, mixed to  )
{
  variables[ what ][ VAR_VALUE ] = to;
  remove_call_out( save );
  call_out( save, 0.1 );
}

void defvar( string v, mixed val, int type,
             string|mapping q, string|mapping d,
             array|void misc, mapping|void translate )
{
  if( stringp( q ) )
    q = ([ "standard":q ]);
  if( stringp( d ) )
    d = ([ "standard":d ]);

  if( !variables[v] )
  {
    variables[v]                     = allocate( VAR_SIZE );
    variables[v][ VAR_VALUE ]        = val;
  }
  variables[v][ VAR_TYPE ]         = type & VAR_TYPE_MASK;
  variables[v][ VAR_DOC_STR ]      = d->english;
  variables[v][ VAR_NAME ]         = q->english;
  variables[v][ VAR_MISC ]         = misc;
  type &= (VAR_EXPERT | VAR_MORE);
  variables[v][ VAR_CONFIGURABLE ] = type?type:1;
  foreach( indices( q ), string l )
    deflocaledoc( l, v, q[l], d[l], (translate?translate[l]:0));
}

mixed query( string what )
{
  if( variables[ what ] )
    return variables[what][VAR_VALUE];
}

void save();
