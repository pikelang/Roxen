mapping (string:string) users = ([ ]);

int rxml;
string domain;

void find_user(string u)
{
  array userinfo;
  if( userinfo = getpwnam(u) )
    users[u] = userinfo[4]+" <"+u+"@"+domain+">";
  else
    users[u] = " <"+u+"@"+domain+">";    
}

string mymktime(string from)
{
  // NOTE: Doesn't adjust for DST.
  mapping m = ([]);
  array t = replace(from, ({"/",":"}),({" "," "}))/" ";
  t = Array.map(t,
		lambda(string s) {
		  int i;
		  sscanf(s, "%d", i);
		  return i;
		});
  m->year = t[0]-1900;
  m->mon  = t[1]-1;
  m->mday = t[2];
  m->hour = t[3];
  m->min = t[4];
  m->sec = t[5];
//werror("%O\n", m);
  if(rxml) return "<date unix_time="+mktime(m)+"> ";
  return (ctime(mktime(m))-"\n"+" ");
}

array ofiles = ({});
void output_changelog_entry_header(array from)
{
  string u = (from[1] == "law"?"mirar":from[1]);
  if(rxml)
    write("</ul></if>\n<if or prestate="+u+" variable=all><h3>"+
	  mymktime(from[0])+" <user name="+u+"></h3>\n<ul>\n");
  else
  {
    if(!users[u]) find_user(u);
    write("\n"+mymktime(from[0])+" "+users[u]+"\n");
  }
  ofiles = ({});
}

string qte(string what)
{
  what = replace(what, ({"\n","<",">","&" }),
		 ({"<br>","&lt;","&gt;","&amp;" }));
  string a, b, c;
  while(sscanf(what, "%s*%s*%s", a, b, c)==3)
    what = a+"<b><font color=darkred>"+b+"</font></b>"+c;
  while(sscanf(what, "%s#%s#%s", a, b, c)==3)
    what = a+"<b><font color=darkgreen>"+b+"</font></b>"+c;
  return what;
}

string translate(string c)
{
  if( domain != "idonex.se" ) return c;

  // specials, for roxen log....
  c = replace(c, " för ", " for ");
  c = replace(c, "A little faster", "Somewhat faster");
  c = replace(c, "Little bug", "Small bug");
  if(sscanf(c,"%*sversion... HATA%*s"))
    return "Initial revision, imported from old Spinner tree";
  if(c=="Hej hopp\n")
    return "Bugfixes";
  if(c=="ett par småfixar\n")
    return "Some minor tweaks";
  c = replace(c, "Ungefär detta har ändrats:\n", "");
  return c;
}

string trim(string what)
{
  string res="";
  foreach(what/"\n", string l)
  {
    l = reverse(l);
    sscanf(l, "%*[ \t]%s", l);
    l = reverse(l);
    res += l+"\n";
  }
  return res[..sizeof(res)-2];
}

void output_entry(array files, string message)
{
  sscanf(message, "%*[ \n\r]%s", message);
  message = reverse(message);
  sscanf(message, "%*[ \n\r]%s", message);
  message = reverse(message);
  if(equal(sort(files),sort(ofiles)))
  {
    if(rxml) write("<blockquote>"+qte(message)+"</blockquote>\n\n");
    else write(trim(sprintf("              %-=65s\n", message)));
  }
  else
  {
//     write("%O != %O", files, ofiles);
    string fh="";
    foreach(files, string f)
      fh += f+", ";
    fh = fh[..sizeof(fh)-3]+":";
    if(rxml)
    {
      write("<li><b><font color=darkblue>"+qte(fh)+"</font></b>"
	    "<blockquote>"+qte(message)+"</blockquote>\n\n");
    } else {
      if(strlen(message+fh)<70)
	write("\t* "+fh+" "+message+"\n");
      else
	write(trim(replace(sprintf("\t* %-=69s\n", fh),"\n   ","\n\t  ")+
		   sprintf("            %-=65s\n", message)));
    }
    ofiles = files;
  }
}

void twiddle()
{
  while(1) 
  {
    werror("\\"); sleep(0.1);
    werror("|"); sleep(0.1);
    werror("/"); sleep(0.1);
    werror("-"); sleep(0.1);
    if(!random(3)) werror(".");
  }
}

void main(int argc, array (string) argv)
{
#if efun(thread_create)
  thread_create(twiddle);
#endif
  werror("Running CVS log ");
  string data = Process.popen("cvs log");
  werror("Done ["+strlen(data)/1024+" Kb]\n");
  array entries = ({});
  rxml = argv[-1]=="--rxml";
  if(argc>1 && argv[1] != "--rxml")
    domain = argv[1];
  else
  {
    users->law = "Mirar <mirar@idonex.se>";
    domain = "idonex.se";
  }
  werror("Parsing data ... ");
  if(rxml)
    write("<body bgcolor=white text=black link=darkred><ul>");
  foreach(data/"=============================================================================\n", string file)
  {
    array foo = file/"----------------------------\nrevision ";
    string fname;
    if(!sizeof(foo)) continue;
    sscanf(foo[0], "%*sWorking file: %s\n", fname);
    foreach(foo[1..], string entry)
    {
      string date, author, lines, comment, revision;
      sscanf(entry, 
	     "%s\ndate: %[^;];%*sauthor: %[^;];%*s\n%s",
	     revision,date,author,/*lines,*/comment);
      if(comment)
      {
	sscanf(comment, "branches:%*s\n%s", comment);
	comment = translate(comment);
	if(sscanf(entry, "%*sstate: dead;%*s")==2)
	  comment = "*Deleted*: "+comment;
	else if(sscanf(entry, "%*slines:%*s")!=2)
	  comment = "#Added#: "+comment;
	entries += ({ ({date,author,revision,fname,lines,comment}) });
      }
    }
  }
  array order = Array.map(entries,lambda(array e) {
    return e[0][..sizeof(e[0])-4]+e[5];
  });
  sort(order,entries);
  entries = reverse(entries);
  werror("Done. "+sizeof(entries)+" entries\n");
  werror("Writing ChangeLog ... ");
//   werror("%O", column(entries,0));
  string od, ou, oc, cc="";
  array collected_files = ({}), old_collected_files;
  foreach(entries, array e)
  {
    string date = (e[0]/" ")[0];
    string time = (e[0]/" ")[1];
//    werror(">>> %s\n", e[0]);
    if((date != od) || (e[1] != ou))
    {
      if(oc && sizeof(collected_files))
	output_entry( collected_files, oc );
      collected_files = ({});
      oc = e[5];
      output_changelog_entry_header( copy_value(e) );
      od = date;
      ou = e[1];
    }
    if(oc && e[5] != oc)
    {
      output_entry( collected_files, oc );
      old_collected_files = ({});
      collected_files = ({});
      oc = e[5];
    } 
    if(!oc) oc = e[5];
    collected_files |= ({ e[3] });
  }
  if(oc && sizeof(collected_files))
    output_entry( collected_files, oc);
  werror("Done!\n");
}
