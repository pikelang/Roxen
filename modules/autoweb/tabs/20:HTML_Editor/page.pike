inherit "roxenlib";

object wa;

array wanted_buttons = ({ ({ "Remove File"}) });

array get_buttons(object id)
{
  return wanted_buttons;
}

void create (object webadm)
{
  wa = webadm;
}

string fix_fn(object id, string fn)
{
  return wa->query("sites_location")+id->misc->customer_id+"/"+fn;
}

mapping dl(object id, string fn)
{
  object f=Stdio.File(fix_fn(id,fn),"r");
  if(f)
    return ([ "type" : "application/octet-stream",
	      "data" : f->read() ]);
  else
    return 0;
}

string|mapping navigate(object id, string f, string base_url)
{
  string res="";
  if(f[-1]!='/') // it's a file
  {
    array br = ({ });
    int t;
    object file = Stdio.File(fix_fn(id,f));

    if (!objectp(file))
      return "File not found or permission denied.\n";

    mapping md=wa->get_md(id,f);
    br += ({ ({ "View", wa->query("location")+
		f[1..]+" target=_autosite_show_real"}) });
    if ((md->content_type=="text/html") ||
	(md->content_type=="text/html"))
      br += ({ ({ "Edit", (["filename":f]) }) });
    br += ({ ({ "Edit Metadata", ([ "path":f ]) }),
	     ({ "Download", base_url+"dl"+f}),
	     ({ "Upload", ([ "path":f ]) }),
	     ({ "Remove File", ([ "path":f ]) }) });
    wanted_buttons=br;

    // Show info about the file;
    res+="foo";
  }
  else  // it's a directory
  {
    wanted_buttons=
      ({ ({ "Create File", ([ "path": f ]) }),
	 ({ "Upload File", ([ "path": f ]) }) });

    // Show the directory
    return get_dir(wa->query("sites_location")+"/"+id->misc->customer_id)*"<br>";
    
    res+="bar";
  }

  
  return res;
}

string|mapping handle(string sub, object id)
{
  wanted_buttons=({ });
  if(!id->misc->state)
    id->misc->state=([]);
  string resource="/";
  string base_url = id->not_query[..sizeof(id->not_query)-sizeof(sub)-1];

  if(2==sscanf(sub, "%s/%s", sub, resource))
    resource = "/"+resource;
  switch(sub) {
  case "":
    break;
  case "go":
    break;
   case "dl":
    return dl(id, resource);
  default:
    return "What?";
  }
  return navigate(id, resource, base_url);
}
