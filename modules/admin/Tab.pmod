class tab
{
  inherit "wizard";
   
  string dir;   // setup by create()
  string tab;   // | 
  object o;     // |
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
     
    return a;
  }

  object compile()
  {
    mixed err;
    if (o) destruct(o);

    master()->set_inhibit_compile_errors("");
    err = catch 
    {
      o = compile_file(dir+"/page.pike")( parent, tab );
    };
    err = master()->errors;
    master()->set_inhibit_compile_errors(0);
    if (err && err != "")
      parent->sbdebug( "Errors while compiling " + dir + "/page.pike\n" + err
		       + "\n" );
    return o;
  }

  string|mapping show(string sub, object id, string f)
  {
    string res;
    string|mapping|array tmp;
    array wanted_buttons;

    if(!search(sub,"wizard")&&(f[0..1]!="25"))
    {
      master()->set_inhibit_compile_errors("");
      mixed e = catch
      {
	    tmp=wizard_menu(id,dir+"/wizards/",
			    parent->query_location()+tab+"/");
      };
      if(e)
      {
	parent->sbdebug("show compile wizard failed:\n"+master()->errors+
			master()->describe_backtrace(e));
	tmp = "<pre>" + master()->errors + "\n"
	  + master()->describe_backtrace(e)+"</pre>";
      }
      master()->set_inhibit_compile_errors(0);
      return tmp;
    }
    
    // recompile upon "reload"      
    if(!o)
      compile();
    else
      if(id->pragma["no-cache"])
	compile();

    if(!o) 
      tmp = "Compilation of \""+dir+"/page.pike"+"\" failed:\n <pre>"
	+ err + "</pre>\n";
    else
    {
      master()->set_inhibit_compile_errors("");
      mixed e = catch
      {
	tmp = o->handle( sub, id );
	wanted_buttons = o->get_buttons ? o->get_buttons( id ) : ({ });
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
    res="<!-- Result of tab object handle() -->\n"+tmp;
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
	if(arrayp(tmp))
	  return res+buttonrow(fixbuttons(tmp[0],wanted_buttons));
      };
      if(err)
      {
	werror("wizard compilation failure...\n"
	       + master()->errors + "\n" );
	tmp="<font color=red><pre>"+master()->errors+
	  "\n"+master()->describe_backtrace(err)
	  +"</pre></font>";
      }
      master()->set_inhibit_compile_errors(0);
      if(arrayp(tmp)) return res;
      if(mappingp(tmp)) return tmp;
      res+="<p><!-- Wizard menu -->\n"+tmp;
    }
    return res;
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
