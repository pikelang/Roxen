void parse( RequestID id )
{
  if( id->misc->orig )
    parse( id->misc->orig );
  if( !id->variables->fixedname++ )
    id->variables->name = map( (array(int))id->variables->name, 
                               lambda( int i ) {
                                 return ((string)i)+",";
                               } ) * "";
}
