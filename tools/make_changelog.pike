mapping (string:string) users = ([ "law":"Mirar <mirar@idonex.se>" ]);

int html;

void find_user(string u)
{
  users[u] = getpwnam(u)[4]+" <"+u+"@idonex.se>";
}

string mymktime(string from)
{
  mapping m = ([]);
  array t = (array(int))(replace(from, ({"/",":"}),({" "," "}))/" ");
  m->year = t[0]-1900;
  m->mon  = t[1]-1;
  m->mday = t[2];
  m->hour = t[3];
  m->min = t[4];
  m->sec = t[5];
  return ctime(mktime(m))-"\n"+" ";
}

void output_changelog_entry_header(array from)
{
  if(!users[from[1]]) find_user(from[1]);
  write("\n"+mymktime(from[0])+" "+users[from[1]]+"\n");
  ofiles = ({});
}


array ofiles = ({});
string translate(string c)
{
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
    write(trim(sprintf("              %-=65s\n", message)));
  else
  {
//     write("%O != %O", files, ofiles);
    string fh="";
    foreach(files, string f)
      fh += f+", ";
    fh = fh[..sizeof(fh)-3]+":";
    if(strlen(message+fh)<70)
      write("\t* "+fh+" "+message+"\n");
    else
      write(trim(replace(sprintf("\t* %-=69s\n", fh),"\n   ","\n\t  ")+
		 sprintf("            %-=65s\n", message)));
    ofiles = files;
  }
}

void main()
{
  string data = Process.popen("cvs log");
  array entries = ({});
  foreach(data/"=============================================================================\n", string file)
  {
    array foo = file/"----------------------------\nrevision ";
    string fname;
    sscanf(foo[0], "%*sWorking file: %s\n", fname);
    foreach(foo[1..], string entry)
    {
      string date, author, lines, comment, revision;
      sscanf(entry, 
	     "%s\ndate: %[^;];%*sauthor: %[^;];%*slines: %[^\n]\n%s",
	     revision,date,author,lines,comment);
      if(comment)
      {
	sscanf(comment, "branches:%*s\n%s", comment);
	comment = translate(comment);
	entries += ({ ({date,author,revision,fname,lines,comment}) });
      }
    }
  }
  array order = Array.map(entries, lambda(array e) { return e[0]+e[5]; });
  sort(order,entries);
  entries = reverse(entries);
  string od, ou, oc, cc="";
  array collected_files = ({}), old_collected_files;
  foreach(entries, array e)
  {
    string date = (e[0]/" ")[0];
    string time = (e[0]/" ")[1];
    if(date != od || e[1] != ou)
    {
      if(oc && sizeof(collected_files))
	output_entry( collected_files, oc );
      collected_files = ({});
      oc = e[5];
      output_changelog_entry_header( e );
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
    collected_files += ({ e[3] });
  }
  if(oc && sizeof(collected_files))
    output_entry( collected_files, oc);
}
