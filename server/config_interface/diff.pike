
string parse( RequestID id )
{
  Variable.Variable v =
    Variable.get_variables(id->variables->variable);

  if(!v)
    return " Error in URL ";
  
  return sprintf( "<use file='/template' />\n"
                  "<tmpl title=' %s '>"
                  "<content>Difference</content></tmpl>",
		  (v->diff(2)||"") );
}
