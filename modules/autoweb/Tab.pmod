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

  
  
  string buttonrow_gtext(array brow)
  {
    string s="<p>";
    foreach(brow, array a)
    {
      s += " <gtext alink=yellow xspacing=4 notrans magic='"+a[0]+
	"' spacing=3 fg=#ffffff bg=#5a3270 nfont=lucida scale=0.5 href='"+
	a[1];

      if(a[2])
      {
	s+="?";
	foreach(indices(a[2]), string input_hidden)
	  s+=input_hidden+"="+a[2][input_hidden]+"&";
	s=s[..sizeof(s)-2];
      }
      s+="'>"+a[0]+"</gtext>";
    }
    return s;
  }

  string buttonrow_submitbuttons(array brow)
  {
    //werror("brow: %O\n",brow);
    string s="";

    s+="<table><tr>";
    foreach(brow, array a)
      if(sizeof(a))
	if (stringp(a[1]))
	{
	  s+="<td><form method=get action="+a[1]+
	    "><input type=submit name=\""+a[0]+"\" value=\""+a[0]+"\">";
	  if(sizeof(a)>2&&mappingp(a[2]))
	    foreach(indices(a[2]), string input_hidden)
	      s+="<input type=hidden name=\""+input_hidden+
		"\" value=\""+a[2][input_hidden]+"\">";
	  s+="</form></td>";
	}
	else
	{
	  s+="<td>internal server error<br>"+
	    "<tt>"+sprintf("%O",a)+"</tt><br>"
	    __FILE__":"+__LINE__+"</td>";
	}
      else
	s+="</tr></table><table><tr>";
    s+="</tr></table>";
    return s;
  }

  function buttonrow=buttonrow_submitbuttons;
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
      _master->set_inhibit_compile_errors("");
      mixed e = catch
      {
	tmp = o->handle( sub, id );
	wanted_buttons = o->get_buttons ? o->get_buttons( id ) : ({ });
      };
      _master->set_inhibit_compile_errors(0);
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
      return res+page;

    tmp=0;
    if(file_stat(dir+"/wizards/"))
    {
      _master->set_inhibit_compile_errors("");
      mixed err=
      catch
      {
	id->misc->raw_wizard_actions=1;
	tmp = wizard_menu(id, 
			   dir+"/wizards/",
			   parent->query_location()+tab+"/wizard/");
	//werror("%O",tmp);
	if(arrayp(tmp))
	  return res+page+buttonrow(fixbuttons(tmp[0],wanted_buttons));
      };
      if(err)
      {
	werror("wizard compilation failure...\n"
	       + _master->errors + "\n" );
	tmp="<font color=red><pre>"+_master->errors+
	  "\n"+master()->describe_backtrace(err)
	  +"</pre></font>";
      }
      _master->set_inhibit_compile_errors(0);
      if(arrayp(tmp)) return res;
      if(mappingp(tmp)) return tmp;
      if(tmp)
	return res+tmp;
    }
    return res+page;
  }

  int visible(object id)
  {
    if (!o) compile();
    if (!o) return 0;
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
