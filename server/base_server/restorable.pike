PRIVATE string save_variables()
{
  mixed b, a;
  array res = ({ }), variable;
  if(!sizeof(__vars)) // First time, not initialized.
    foreach(indices(this), a)
    {
      b=this[a];
      if(!catch { this[a]=b; } ) // It can be assigned. Its a variable!
      {
	__vars[a] = 1;
	res += ({ ({ a, b }) });
      }
    }
  else
    foreach(indices(__vars), a)
      res += ({ ({ a, this[a] }) });
  return res;
}


PRIVATE void restore_variables(array var)
{
  if(var)
    foreach(var, var)
      catch { this[var[0]] = var[1]; };
}

PRIVATE int max(int a,int b) /* Not macro becasue this is faster.. */
{
  return a<b?b:a;
}

PRIVATE void restore_call_out_list(array var)
{
  array ci;

  /* Clear call_outs iff any are restored.  This is quite important,
   * since quite a lot of people start a call_out in create(). That
   * could kill a server very quickly, since there will be a new callout
   * each time the object is restored.
   */
  if(var)
  {
    foreach(call_out_info(), ci)
      remove_call_out( ci[2] );
    
    foreach(var, var)
      catch {
	call_out(var[0], max(var[1]-(time(1)-var[2]),0), @var[3]); 
      };
  }
}

PRIVATE int save_call_out_list()
{
  array ci;
  array res = ({});

  foreach(call_out_info(), ci)
    res += ({ ({ ci[2], ci[0], time(1), ci[3..] }) });

  return res;
}



string cast(string to)
{
  if(to!="string") error("Cannot cast to "+to+".\n");
  return encode_value(({save_variables(),save_call_out_list()}));
}

void create(string from)
{
  array f;
  catch {
    f = decode_value(from);
  };
  if(arrayp(f))
  {
    restore_variables(f[0]);
    restore_call_out_list(f[1]);
  }
}
