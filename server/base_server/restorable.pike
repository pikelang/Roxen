/* $Id: restorable.pike,v 1.4 1997/05/31 22:01:16 grubba Exp $ */

static private array __vars=({});

static private array save_variables()
{
  mixed b, a;
  array res = ({ }), variable;
  if(!sizeof(__vars)) // First time, not initialized.
    foreach(indices(this_object()), a)
    {
      b=this_object()[a];
      if(!catch { this_object()[a]=b; } ) // It can be assigned. Its a variable!
      {
	__vars+=({});
	res += ({ ({ a, b }) });
      }
    }
  else
    foreach(__vars, a)
      res += ({ ({ a, this_object()[a] }) });
  return res;
}


static private void restore_variables(array var)
{
  if(var)
    foreach(var, var)
      catch { this_object()[var[0]] = var[1]; };
}

string cast(string to)
{
  if(to!="string") error("Cannot cast to "+to+".\n");
  return encode_value(save_variables());
}

void create(string from)
{
  array f;
  catch {
    restore_variables(decode_value(from));
  };
}
