// This file is part of Roxen Webserver.
// Copyright © 2000, Roxen IS.
// $Id: basic_defvar.pike,v 1.17 2000/08/17 16:49:32 lange Exp $
// (string:Variable.Variable) 
mapping(string:Variable.Variable)  variables=([]);
//! Please do not modify this list directly, instead use 
//! defvar, killvar, getvar, query and set

#include <module.h>

Variable.Variable getvar( string name )
//! Return the variable object associated with the specified variable
{
  return variables[name];
}

int deflocaledoc( string locale, string variable,
		   string name, string doc, mapping|void translate )
//! Equivalent to variables[variable]->deflocaledoc( loc,name, doc, translate )
//! This is a compatibility function, and as such is deprecated.
//! But it will be supported for the forseeable function.
{
  report_error("Warning: [%O:%O:%O] deflocaledoc is deprecated. Ignored.\n",
	       this_object(), locale, variable );
}


void set(string var, mixed value)
//! Set the variable 'var' to the specified value.
{
  if(!variables[var]) 
    report_error( "Setting undefined variable: "+var+".\n" );
  else
    variables[var]->set( value );
}

int killvar(string var)
//! Undefine the variable 'var'.
{
  if(!variables[var]) report_error("Killing undefined variable: "+var+".\n");
  m_delete(variables, var);
  return 1;
}


void setvars( mapping (string:mixed) vars )
//! Set the variables from the mapping, which should be on the form
//! ([ "variable name":value, ... ]). 
//! Used by roxen internals, not all that useful for the module
//! programmer.
{
//   werror("setvars: %O\n", vars );
  string v;
  foreach( indices( vars ), v )
    if(variables[v])
      set( v, vars[v] );
}

/*

Variable.Variable defvar( string sname, Variable.Variable variable )
//! Define 'sname' to be 'variable',

Variable.Variable defvar( string sname, mixed value, string name,
                          int type, string doc, array|void misc,
                          int|function not_in_config  )
//! Define a new variable named sname, with the options specified in the list.
//! This is a compatibility version of the function, and as such is deprecated.
//! But it will be supported for the forseeable function.

*/


// Define a variable, with more than a little error checking...
Variable.Variable defvar(string var, mixed value, 

// rest is compat, and thus optional...
                         mapping|string|void|object name,
                         int|void type, 
                         mapping|string|void|object doc_str, 
                         mixed|void misc,
                         int|function|void not_in_config,
                         mapping|void option_translations)
{
  mapping ln;
  if( objectp( value ) && value->is_variable )
    return (variables[var] = value);

  if( mappingp( name ) )
  {
    report_error("Warning: [%O:%O] name/doc as mapping is deprecated. Ignored.\n",
		 this_object(), var );
    ln = name;
    name = name->standard || name->english;
  }

  if( mappingp( doc_str ) )
  {
    if( !ln )
      report_error("Warning: [%O:%O] doc as mapping is deprecated. Ignored.\n",
		   this_object(), var );
    doc_str = doc_str->standard || doc_str->english;
  }

  Variable.Variable vv;

  switch( type & VAR_TYPE_MASK )
  {
   case TYPE_STRING:
     vv = Variable.String( value, 
                           type&~VAR_TYPE_MASK,
                           name,
                           doc_str );
     break;
   case TYPE_FILE:
     vv = Variable.File( value, 
                         type&~VAR_TYPE_MASK,
                         name,
                         doc_str );
     break;
   case TYPE_INT:
     vv = Variable.Int( value, 
                        type&~VAR_TYPE_MASK,
                        name,
                        doc_str );
     break;
   case TYPE_DIR:
     vv = Variable.Directory( value, 
                              type&~VAR_TYPE_MASK,
                              name,
                              doc_str );
     break;
   case TYPE_STRING_LIST:
     if( arrayp( misc ) || mappingp( misc) )
       vv = Variable.StringChoice( value,
                                   misc, 
                                   type&~VAR_TYPE_MASK,
                                   name,
                                   doc_str);
      else
       vv = Variable.StringList( value, 
                                 type&~VAR_TYPE_MASK,
                                 name,
                                 doc_str );
     break;
   case TYPE_INT_LIST:
     if( arrayp( misc ) )
       vv = Variable.IntChoice( value, 
                                misc,
                                type&~VAR_TYPE_MASK,
                                name,
                                doc_str  );
      else
       vv = Variable.IntList( value, 
                              type&~VAR_TYPE_MASK,
                              name,
                              doc_str );
     break;

   case TYPE_FLAG:
     vv = Variable.Flag( value, 
                         type&~VAR_TYPE_MASK,
                         name,
                         doc_str );
     break;
   case TYPE_DIR_LIST:
     if( arrayp( misc ) )
error("Variable type "+(type&VAR_TYPE_MASK)+" with misc no longer supported.\n"
      "Define a custom variable type (see etc/modules/Variable.pmod)\n");
     else
       vv = Variable.DirectoryList( value, 
                                    type&~VAR_TYPE_MASK,
                                    name,
                                    doc_str );
     break;
   case TYPE_FILE_LIST:
     if( arrayp( misc ) )
     {
error("Variable type "+(type&VAR_TYPE_MASK)+" with misc no longer supported.\n"
      "Define a custom variable type (see etc/modules/Variable.pmod)\n");
     }
      else
       vv = Variable.FileList( value, 
                               type&~VAR_TYPE_MASK,
                               name,
                               doc_str );
     break;
   case TYPE_LOCATION:
     vv = Variable.Location( value, 
                             type&~VAR_TYPE_MASK,
                             name,
                             doc_str );
     break;
   case TYPE_TEXT:
     vv = Variable.Text( value, 
                         type&~VAR_TYPE_MASK,
                         name,
                         doc_str );
     break;
   case TYPE_PASSWORD:
     vv = Variable.Password( value, 
                             type&~VAR_TYPE_MASK,
                             name,
                             doc_str );
     break;
   case TYPE_FLOAT:
     vv = Variable.Float( value, 
                          type&~VAR_TYPE_MASK,
                          name,
                          doc_str );
     break;
   case TYPE_FONT:
     vv = Variable.FontChoice( value,
                               type&~VAR_TYPE_MASK,
                               name,
                               doc_str );
     break;
   case TYPE_URL:
     vv = Variable.URL( value, 
                         type&~VAR_TYPE_MASK,
                         name,
                         doc_str );
     break;
   case TYPE_URL_LIST:
     vv = Variable.URLList( value, 
                            type&~VAR_TYPE_MASK,
                            name,
                            doc_str );
     break;
   default:
     error("Variable type "+(type&VAR_TYPE_MASK)+" no longer supported.\n"
           "Define a custom variable type (see etc/modules/Variable.pmod)\n");
     
  }

  if (functionp(not_in_config)) 
    vv->set_invisibility_check_callback( not_in_config );
  else if( not_in_config )
    vv->set_invisibility_check_callback( lambda(object id,
                                                Variable.Variable i )
                                         { return 1; } );
    
//   if( ln && ld )
//   {
//     foreach( indices( ln ), string locale )
//     {
//       if( ln[locale] && ld[locale] )
//       {
//         if( option_translations && option_translations[ locale ] )
//           vv->deflocaledoc( locale, ln[locale], ld[locale], 
//                             option_translations[locale] );
//         else
//           vv->deflocaledoc( locale, ln[locale], ld[locale] );
//       }
//     }
//   }

  return (variables[var] = vv);
}

mixed query(string|void var, int|void ok)
//! Query the variable 'var'. If 'ok' is true, it is not an error if the 
//! specified variable does not exist.
{
  if(var) 
  {
    if(variables[var])
      return variables[var]->query();
    else if(!ok && var[0] != '_')
      report_error("Querying undefined variable: "+var+"\n");
    return ([])[0];
  }
  return variables;
}

void definvisvar(string name, int value, int type, array|void misc)
//! Convenience function, define an invisible variable, this variable
//! will be saved, but it won't be visible in the administration interface.
{
  defvar(name, value, "", type, "", misc, lambda(){return 1;} );
}

void save();
