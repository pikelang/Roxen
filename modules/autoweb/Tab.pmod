class tab
{
  inherit "wizard";
   
  string dir;   // setup by create()
  string tab;   // | 
  object|string o;     // |
  object parent;// |
  string title; // |
  int space;
  
  string err; // temporary

  string button(array button, object id) {
    string s = "";
    if(sizeof(button)) {
      if(stringp(button[1])) {
	s += ("<toolbarbuttonlayout name='"+button[0]+
	      "' href="+(sizeof(button)>2?"'"+button[1]:button[1]));
	
	if(sizeof(button)>2) {
	  button[2]=(["cancel_url":id->not_query])+button[2]||([]);
	  s+="?";
	  foreach(indices(button[2]), string input_hidden)
	    s+=input_hidden+"="+button[2][input_hidden]+"&";
	  s=s[..sizeof(s)-2]+"'";
	}
	s+=">";
      } else
	s+="internal server error<br>"+
	   "<tt>"+sprintf("%O",button)+"</tt><br>"
	   __FILE__":"+__LINE__+"";
    }
    return s;
  }
  
  string buttonrow_toolbar(array brow, array all_buttons, object id)
  {
    string s="<toolbarlayout>";
    if(all_buttons) {
      foreach(all_buttons, mapping item) {
	foreach(brow, array button) {
	  if(item->button==button[0])
	    item->args=button;
	}
      }
      // werror("%O", all_buttons);
      foreach(all_buttons, mapping item) {
	if(item->header)
	  s += "<toolbarheadinglayout>"+item->header+"</toolbarheadinglayout>";
	if(item->button) {
	  if(item->args)
	    s += button(item->args, id);
	  else s += "<toolbarbuttonlayout shade name='"+item->button+"'>";
	}
      }
    } else
      if(sizeof(brow))
	s += button(brow[0], id);
    s += "</toolbarlayout>";
    return s;
  }
  
  function buttonrow=buttonrow_toolbar;
  // function buttonrow=buttonrow_gtext;
  
  array fixbuttons(mapping wiz, array wanted)
  {
    array a=({ });
    if(wanted==0)
      return values(wiz);

    foreach(wanted, array button)
      if(sizeof(button)&&wiz[button[0]])
      {
	a+=({ wiz[button[0]] });
	if(sizeof(button)>1)
	  a[-1][2]+=button[1];
      }
      else
	if(sizeof(button)>1)
	  a+=({ button });
	else
	  a+=({ ({ }) });

    //werror("fixedbuttons: %O\n",a);
    return a;
  }

  object|string compile()
  {
    mixed err;
    if (o && objectp(o)) destruct(o);

    master()->set_inhibit_compile_errors("");
    err = catch 
    {
      o = compile_file(dir+"/page.pike")( parent, tab );
    };
    err = master()->errors;
    master()->set_inhibit_compile_errors(0);
    if (err && err != "")
      o = "Errors while compiling " + dir + "/page.pike\n" + err
		       + "\n";
  }

  string|mapping show(string sub, object id, string f)
  {
    string res="";
    string|mapping|array tmp;
    array wanted_buttons;
    mapping all_buttons;
    
    // recompile upon "reload"      
    if(!o)
      compile();
    else
      if(id->pragma["no-cache"])
	compile();

    if(stringp(o))
      tmp = "Compilation of \""+dir+"/page.pike"+"\" failed:\n <pre>"
	+ o + "</pre>\n";
    else
    {
      master()->set_inhibit_compile_errors("");
      mixed e = catch
      {
	tmp = o->handle( sub, id );
	wanted_buttons = o->get_buttons ? o->get_buttons( id ) : ({ });
	all_buttons = o->get_all_buttons ? o->get_all_buttons( id ) : 0;
      };
      master()->set_inhibit_compile_errors(0);
      if (e)
      {
	werror("show compile buttons error:\n"+
	       master()->describe_backtrace(e));
	tmp = "<pre>"+master()->describe_backtrace(e)+"</pre>";
      }
    }
    if(mappingp(tmp)) return tmp;
    string page=tmp;
    // Ugly hack to make <wizard> work on one page..
    if(f[0..1]=="10")
      return "<content>"+res+page+"</content>";

    tmp=0;
    if(file_stat(dir+"/wizards/"))
    {
      master()->set_inhibit_compile_errors("");
      mixed err=
      catch
      {
	id->misc->raw_wizard_actions=1;
	tmp = wizard_menu(id, 
			   dir+"/wizards/",
			   parent->query_location()+tab+"/wizard/");
	//werror("%O",tmp);
	if(arrayp(tmp))
	  return "<toolbar>"+
	    buttonrow(fixbuttons(tmp[0],wanted_buttons),all_buttons,id)+
	    "</toolbar>"
	    "<content>"+res+page+"</content>";

      };
      if(err)
      {
	werror("wizard compilation failure...\n"
	       + master()->errors + "\n");
	tmp="<font color=red><pre>"+master()->errors+
	  "\n"+master()->describe_backtrace(err)
	  +"</pre></font>";
      }
      master()->set_inhibit_compile_errors(0);
      if(arrayp(tmp)) return res;
      if(mappingp(tmp)) return tmp;
      if(tmp)
	return "<content>"+res+tmp+"</content>";
    }
    return "<content>"+res+page+"</content>";
  }

  int visible(object id)
  {
    if(!o) compile();
    if(!o) return 0;
    if(stringp(o))
    {
      werror(o);
      return 0;
    }
    return !o->visible || o->visible(id);
  }
  
  void create(string _dir,string _tab,object _par)
  {
    dir=_dir;
    tab=_tab;
    parent=_par;

    title=String.capitalize(tab[3..]);
    if (tab[3..]=="space") space=1;
  }
}
