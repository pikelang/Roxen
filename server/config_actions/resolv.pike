/*
 * $Id: resolv.pike,v 1.1 1998/02/20 00:58:14 per Exp $
 */

inherit "wizard";
constant name= "Maintenance//Resolv path...";
constant doc = ("Check which module handles the path you enter in the form");

string module_name(function|object m)
{
  if(functionp(m)) m = function_object(m);
  return "<font color=darkgreen>"+
    (strlen(m->query("_name")) ? m->query("_name") :
     (m->query_name&&m->query_name()&&strlen(m->query_name()))?
     m->query_name():m->register_module()[1])+"</font>";
}


string page_0(object id)
{
  string res = ("Virtual server <var type=select name=config options='"+
		roxen->configurations->query_name()*","+"'>")+"\n";
  res += "<br>Path: <var name=path type=string>\n";

  if(id->variables->config)
  {
    object c;
    foreach(roxen->configurations, c)
      if(c->query_name() == id->variables->config)
	break;
    

    string resolv = "Resolving "+id->variables->path+" in "+c->query_name()+"<hr noshade size=1 width=100%><p><ol>";
    object nid = id->clone_me();

    nid->not_query = id->variables->path;
    nid->conf = c;

    int again = 0;
    function funp;

    mixed file;
    do
    {
      again=0;
      foreach(c->first_modules(), funp)
      {
	resolv += "<br><b><font size=+1><p><li></font></b> Filter module  "+module_name(funp);
	if(file = funp( nid ))
	{
	  resolv += " <br><b>Returns data</b>";
	  break;
	}
	if(nid->conf != c)
	{
	  c = nid->conf;
	  resolv += ("<br><b>Request transfered to the virtual server "+
		     c->query_name()+"</b>");
	  again=1;
	  break;
	}
      }
    } while(again);

    if(!file) 
      do
      {
	again=0;
	foreach(c->url_modules(nid), funp)
	{
	  resolv += "<br><b><font size=+1><p><li></font></b> URL module  "+module_name(funp);
	  if(file = funp( nid, file ))
	  {
	    if(mappingp(file))
	      resolv += " <br><b>Returns data</b>";
	    else
	    {
	      resolv += " <br><b>Rewrote request to "+nid->not_query+"</b>";
	      again = 1;
	      file = 0;
	    }
	    break;
	  }
	}
      } while(again);

    
    string loc;
    object fid;
    int slevel;
    if(!file) foreach(c->extension_modules(loc=extension(nid->not_query),nid), funp)
    {
      resolv+= "<br><b><font size=+1><p><li></font></b> Extension module "+module_name(funp);
      file=funp(loc, id);
      if(file)
      {
	if(!objectp(file))
	{
	  resolv += "<br><b>Returns data</b>";
	  break;
	}
	fid = file;
	file =0;
	slevel = function_object(funp)->query("_seclvl");
	resolv += " <br><b>Returns open file [security level = "+slevel+"]</b>";
	id->misc->seclevel = slevel;
	break;
      }
    }

    if(!fid && !file) foreach(c->location_modules(nid), mixed tmp)
    {
      loc = tmp[0];
      if(!search(nid->not_query, loc)) 
      {
	resolv += "<br><b><font size=+1><p><li></font></b> Location module "+module_name(tmp[1]);
#ifdef MODULE_LEVEL_SECURITY
	if(tmp2 = c->check_security(tmp[1], nid, slevel))
	  if(intp(tmp2))
	  {
	    resolv += " <br><b>Module access denied by security rule</b>";
	    continue;
	  } else {
	    resolv += " <br><b>Request denied by security rule</b>";
	    file = tmp2;
	    break;
	  }
#endif
	fid=tmp[1]( nid->not_query[ strlen(loc) ..] + id->extra_extension, nid);
	if(fid)
	{
	  if(mappingp(fid))
	  {
	    file = fid;
	    resolv += " <br><b>Returns data</b>";
	    break;
	  }
	  else
	  {
#ifdef MODULE_LEVEL_SECURITY
	    slevel = c->misc_cache[tmp[1]][1];// misc_cache from check_security
	    nid->misc->seclevel = slevel;
#endif
	    if(objectp(fid))
	      resolv += " <br><b>Returns open file [security level = "+slevel+"]</b>";
	    else
	      resolv += " <br><b>Returns pointer to directory [security level = "+slevel+"]</b>";
	      
	    break;
	  }
	}
      } else if(strlen(loc)-1==strlen(nid->not_query)) {
	// This one is here to allow accesses to /local, even if 
	// the mountpoint is /local/. It will slow things down, but...
	if(nid->not_query+"/" == loc)
	{
	  resolv += " <br><b>Automatic redirect (search path same as mountpoint for module)</b>";
	  file=1;
	  break;
	}
      }
    }

    if(fid == -1)
    {
      if(c->dir_module)
      {
	resolv += "<br><b><font size=+1><p><li></font></b> Directory module "+module_name(c->dir_module)+" <br><b>Returns data</b>";
	file=([]);
      } else
	resolv += "<br><b><font size=+1><p><li></font></b> No directory module available to parse directory.";
    }
    mixed tmp;
    if(!file && objectp(fid) &&
       (tmp=c->file_extension_modules(loc=extension(nid->not_query), id)))
      foreach(tmp, funp)
      {
	resolv += "<br><b><font size=+1><p><li></font></b> Extension module "+module_name(funp);
	if(tmp=c->check_security(funp, id, slevel))
	  if(intp(tmp))
	  {
	    resolv += " <br><b>Module access denied</b>";
	    continue;
	  }
	  else
	  {
	    resolv += " <br><b>Access denied</b>";
	    file = ([]);
	    break;
	  }
	tmp=funp(fid, loc, nid);
	if(tmp)
	{
	  if(!objectp(tmp))
	  {
	    resolv += " <br><b>Returns data</b>";
	    file = tmp;
	    break;
	  }
	  if(fid)
	  {
	    resolv += " <br><b>Returns new file object</b>";
	    destruct(fid);
	    fid = tmp;
	    break;
	  }
	}
      }
  
    if(!file && fid) 
    {
      if(stringp(nid->extension))
	nid->not_query += id->extension;
    
      tmp=c->type_from_filename(nid->not_query, 1);
      if(tmp)
      {
	file=([ "file":fid, "type":tmp[0], "encoding":tmp[1] ]);
	resolv += " <br><b><font size=+1><p><li></font></b> Content type module <br><b>Sets type to "+file->type+"</b>";
      }else{
	resolv += " <br><b><font size=+1><p><li></font></b> No content type module. Unknown type";
	if(fid)
	  file = ([ "file":fid ]);
      }
    }

    mixed res2;
    foreach(c->filter_modules(nid), tmp)
      if(res2=tmp(file,nid))
      {
	resolv  += "<br><b><font size=+1><p><li></font></b> Filter module "+module_name(tmp);
	if(file && file->file && (res2->file != file->file))
	{
	  destruct(file->file);
	  file=res2;
	}
      }
    
    if(!file)
      resolv += "<br><b><font size=+1><p><li></font></b> No data returned, using 'no such file' error message";

    res += "<p><blockquote>"+html_border(resolv,0,10)+"</blockquote>";
  }
  
  return res;
}

int wizard_done(object id)
{
  return -1;
}

mixed handle(object id, object mc)
{
  return wizard_for( id, 0 );
}
