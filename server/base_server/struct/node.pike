int folded=1, type;
mixed data;
function describer;
object prev, next, current, up, down;

mapping below=([]);

array (string) _path = ({ });
string path(int i)
{
  if(i) return replace("/"+_path*"/", ({ " ", "\t", "\n", "\r", 
					   "?", "&", "%" }), 
		       ({ "%20", "%07", "%0A", "%0D", 
			    "%3f", "%26", "%25" }) );
  return "/"+_path*"/";
}

string name() { return _path[-1]; }

string describe(int i)
{
  string res="";
  mixed tmp;

  if(describer) tmp = describer(this_object());

  if(stringp(tmp))
    res += tmp + "\n";

  if(!folded)
  {
    object node = down;
    while(node)
    {
      res += "  " + (node->describe()/"\n") * "\n  ";
      node = node->next;
    }
  }
  return res;
}

object descend(string what, int nook)
{
  object o;

  if(objectp(below[what]))
    return below[what];
  if(nook) return 0;

  o=object_program(this_object())();

  if(!down)  // The new node is the first node below this one in the tree.
    down=o;
  
  o->up = this_object(); 

  if(current)
  {
    o->prev = current;
    current->next = o;
  }

  current = o; // The last node to be added..
  o->_path = _path + ({ what });
  return below[what]=o;
}

void map(function fun)
{
  object node;

  fun(this_object());
  node=down;
  while(node)
  {
    node->map(fun);
    node=node->next; 
  }
}

void clear()
{
  object node;
  object tmp;
  current=0;
  node=down;
  while(node)
  {
    tmp=node->next; 
    node->dest();
    node=tmp;
  }
  down=0;
}

void dest()
{
  object node;
  object tmp;

  node=down;

  below=([]);

  while(node)
  {
    tmp=node->next; 
    node->dest();
    node=tmp;
  }

  if(prev)  prev->next = next;
  if(next)  next->prev = prev;
  next=prev=0;

  if(up)
  {
    if(up->down == this_object())     up->down = prev||next;
    if(up->current == this_object())  up->current = prev||next;
  }
  up=down=0;
  destruct();
}


