#include <module_constants.h>
mapping variables = ([ ]);
local mapping locs = ([]);

void deflocaledoc( string locale, string variable,
                   string name, string doc, mapping|void translate)
{
  if(!locs[locale] )
    locs[locale] = RoxenLocale[locale]->register_module_doc;
  if(!locs[locale])
    report_debug("Invalid locale: "+locale+". Ignoring.\n");
  else
    locs[locale]( this_object(), variable, name, doc, translate );
}

void set( string what, mixed to  )
{
  if( variables[ what ] )
    variables[ what ][ VAR_VALUE ] = to;
  else
    report_error("set("+what+"): Unknown variable, only have %s.\n",
                 String.implode_nicely( sort(indices( variables ) ) ));
}

void killvar(string name)
{
  m_delete(variables, name);
}

int setvars( mapping (string:mixed) vars )
{
  string v;
  foreach( indices( vars ), v )
    if(variables[v])
      variables[v][ VAR_VALUE ] = vars[ v ];
  return 1;
}

void defvar( string v, mixed val,
             string|mapping q, int type, string|mapping d,
             array|void misc, mapping|void translate )
{
  if( stringp( q ) )   q = ([ "standard":q ]);
  if( stringp( d ) )   d = ([ "standard":d ]);

  if( translate && !mappingp( translate ) )
    translate = 0;

  if( !variables[v] )
  {
    variables[v]                     = allocate( VAR_SIZE );
    variables[v][ VAR_VALUE ]        = val;
    variables[v][ VAR_SHORTNAME ]    = v;
  }
  variables[v][ VAR_TYPE ]         = type & VAR_TYPE_MASK;
  variables[v][ VAR_DOC_STR ]      = d->english;
  variables[v][ VAR_NAME ]         = q->english;
  variables[v][ VAR_MISC ]         = misc;
  type &= (VAR_EXPERT | VAR_MORE | VAR_INITIAL | VAR_DEVELOPER);
  variables[v][ VAR_CONFIGURABLE ] = type?type:1;
  foreach( indices( q ), string l )
    deflocaledoc( l, v, q[l], d[l], (translate?translate[l]:0));
}

mixed query( string what )
{
  if( variables[ what ] )
    return variables[what][VAR_VALUE];
  return ([])[0];
}

void save();
