string module_global_page( RequestID id, Configuration conf )
{

}

string module_page( RequestID id, Configuration conf, object module )
{

}


string parse( RequestID id )
{
  array path = ((id->misc->path_info||"")/"/")-({""});
  
  if( !sizeof( path )  )
    return "Hm?";
  
  object conf = roxen->find_configuration( path[0] );

  if( sizeof( path ) == 1 )
  {
    /* Global information for the configuration */
  } else {
    switch( path[ 1 ] )
    {
     case "settings":
       return   
#"<formoutput quote=\"¤\">
<input type=hidden name=section value=\"¤section¤\">
<table>
  <configif-output source=config-variables configuration=\""+
path[ 0 ]+#"\" section=\"¤section:quote=dtag¤\">
    <tr><td width=20%><b>#name#</b></td><td>#form:quote=none#</td></tr>
    <tr><td colspan=2>#doc:quote=none#<p>#type_hint#</td></tr>
   </configif-output>
  </table>
  <input type=submit value=\" Apply \" name=action>
</formoutput>";
       break;

     case "modules":
       if( sizeof( path ) == 2 )
         return module_global_page( id, conf );
       else
         return module_page( id, conf, 
                             conf->find_module( replace(path[2],"!","#") ) );
    }
  }


  return sprintf( "Path info: %O\n", path );
}
