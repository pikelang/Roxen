inherit "module";

class LeftTree
{
  string path, name;
  int selected, active;

  mapping sub = ([]);
  array(LeftTree) children = ({});
  LeftTree parent;

  void add(string where, LeftTree what )
  {
    string fp;
    if(sscanf(where, "%s/%s", fp, where) == 2)
    {
      if(sub[ fp ])
	sub[ fp ]->add( where, what );
      else
	error("Unkown subnode addressed: "+ path + " / " + fp);
    } else {
      if(active>0) what->active=active-1;
      children += ({ what });
      what->parent = this_object();
      sub[where] = what;
    }
  }

//   int active()
//   {
//     return active;
//   }

  object selected_node()
  {
    if(selected) return this_object();
    LeftTree q;
    foreach(children, LeftTree c)
      if(q = c->selected_node())
	return q;
  }

  void set_visible()
  {
    LeftTree s = selected_node();
    LeftTree i;
    if(s)
    {
      s->active = 1;
      i = s->parent;
      while(i)
      {
	i->active = 1;
	foreach(i->children, object c)
	  c->active = 1;
	i = i->parent;
      }
      foreach(s->children, object s)
      {
	s->active = 1;
	foreach(s->children, object s)
	  s->active = 1;
      }
    }
    foreach(children, object c)
      c->active = 1;
    active=1;
  }

  string low_get_items()
  {
    if(!active) return "";
    if(!path) return children->low_get_items()*"";
    return ("<item title='"+name+"' href='"+path+"'"+(selected?" selected":"")+">"
	    
	    + (children->low_get_items()*"")+"</item>");
  }

  string get_items()
  {
    set_visible();
    return low_get_items();
  }

  string create( string|void p, string|void n )
  {
    path = p;
    name = n;
  }
}

class ConfigurationModule 
{
  string config_topname();
  LeftTree config_leftmenu( string subnode, RequestID id );
  string config_page( string subnode, RequestID id );

  int `<(ConfigurationModule what)
  {
    return what->config_topname() < config_topname();
  }

  mapping handle( string subnode, RequestID id )
  {
  }
};

LeftTree config_litem( LeftTree state, string current_node, 
		       string path, string title )
{
  LeftTree this = LeftTree( path, title );
  if(!state) state = LeftTree();
  state->add( path, this );
  sscanf( current_node, "%s:%*s", current_node );
  this->selected = (current_node == path);
  return state;
}


Configuration conf;
void create( Configuration c )
{
  if(c) conf = c;
}

array (ConfigurationModule) configuration_modules(RequestID id)
{
  array res = ({ });
  foreach(values(conf->modules), mapping m)
  {
    if(m->master && m->master->config_topname)
    {
      mixed ccs;
      if(ccs = conf->check_security( m->master->config_topname, id,
			       id->misc->seclevel ))
      {
	werror("%O\n", ccs);
	continue;
      }
      res |= ({ m->master });
    }
  }
  return res;
}
