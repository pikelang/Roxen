string parse( RequestID id )
{
  return (array(string))((array(int))id->variables->name)*",";
}
