#include <module.h>
#include <roxen.h>

inherit "roxenlib";
inherit "modules/filesystems/filesystem.pike" : filesystem;
import .AutoWeb;

#define DB_ALIAS "autosite"

#define TRACE_ENTER(A,B) do{if(id->misc->trace_enter)id->misc->trace_enter((A),(B));}while(0)
#define TRACE_LEAVE(A) do{if(id->misc->trace_leave)id->misc->trace_leave((A));}while(0)

constant cvs_version="$Id: autositefs.pike,v 1.35 2003/09/03 11:20:58 grubba Exp $";

mapping host_to_id;
multiset(int) hidden_sites;
array register_module()
{
  return ({ MODULE_LOCATION|MODULE_PARSER|MODULE_AUTH,
	    "AutoSite IP-less hosting Filesystem",
	    "", 0, 1 });
}

string create(object configuration)
{
  filesystem::create();
  defvar("defaulttext",
	 "Not yet the $$COMPANY$$ home page.<br>\n"
	 "This web page is not here yet.\n",
	 "Default text for /index.html",
	 TYPE_TEXT_FIELD,
	 "");
}


string get_host(object id)
{
  if(id->misc->host)
    return lower_case((id->misc->host / ":")[0]);
  else
    return 0;
}
  
void update_host_cache(object id)
{
  object db=id->conf->sql_connect(DB_ALIAS);
  array a=
    db->query("select rr_owner,customer_id,domain from dns where rr_type='A'");
  mapping new_host_to_id=([]);
  if(!catch {
    Array.map(a,lambda(mapping entry, mapping m)
		{
		  if(sizeof(entry->rr_owner))
		    m[entry->rr_owner+"."+entry->domain]=entry->customer_id;
		  else
		    m[entry->domain]=entry->customer_id;
		},new_host_to_id);
  })
    host_to_id=new_host_to_id;
}

void update_hidden_sites(object id)
{
  object db=id->conf->sql_connect(DB_ALIAS);
  array a=db->query("select customer_id from features where feature='Hidden Site'");
  hidden_sites=(< @a->customer_id >);
}

string file_from_host(object id, string file)
{
  if(!id->misc->customer_id)
    id->misc->customer_id = host_to_id[get_host(id)];
  if(id->misc->customer_id)
    return "/"+id->misc->customer_id+"/"+file;
  
  string host, rest;
  sscanf(file,"%s/%s", host, rest);
  id->misc->customer_id = host_to_id[host];
  if(id->misc->customer_id)
    return "/"+id->misc->customer_id+"/"+(rest?rest:"");
}

int hiddenp(object id)
{
  return hidden_sites[id->misc->customer_id];
}

int validate_user(object id)
{
  array a=id->conf->sql_connect(DB_ALIAS)->
    query("select user_id,password from customers where id='"+
	  id->misc->customer_id+"'");
  if(!sizeof(a))
    return 0;
  else
    return equal( ({ a[0]->user_id, a[0]->password }),
		  ((id->realauth||"*:*")/":") );
}

void done_with_put( array (object|string) id )
{
  save_file(id[2], id[0], id[3]);
  id[1]->write("HTTP/1.0 200 Transfer Complete.\r\nContent-Length: 0\r\n\r\n");
  id[1]->close();
  m_delete(putting, id[1]);
  destruct(id[0]);
  destruct(id[1]);
}

void got_put_data( array (object|string)id, string data )
{
// perror(strlen(data)+" .. ");
  id[2] += data;
  putting[id[1]] -= strlen(data);
  if(putting[id[1]] <= 0)
    done_with_put( id );
}

void save_file(string contents, object auto_file, object id)
{
  object mdo = MetaData(id, auto_file->get_name());
  mdo->set(mdo->get() + mdo->get_from_html(contents));
  auto_file->save(AutoFilter()->
		  filter_body(contents,
			      MetaData(id, auto_file->get_name())->get()));
  
}

mixed find_file(string f, object id)
{
  //werror("%O\n", id->prot);
  if(!host_to_id)   update_host_cache(id);
  if(!hidden_sites) update_hidden_sites(id);
  string file = file_from_host(id,f);
  id->variables->customer_id = id->misc->customer_id;
  //werror("m->customer_id: %O\n", id->misc->customer_id);
  id->misc->wa = this_object();
  string real_file = .AutoWeb.AutoFile(id, f)->real_path(f);
  if(!file&& (f=="" || host_to_id[(array_sscanf(f,"%s/")+({""}))[0]]))
  {
    string s="";
    s+=
      "<h1>Error!</h1>"
      "You seem to be using a browser that doesn't send host header. "
      "Please upgrade your browser.<br><br>"
      "The following sites are hosted here:<p><ul>";
    foreach(indices(host_to_id), string host)
      if(host[0..3]=="www.")
	s+="<li><a href='http://"+host+"/'>"+host+"</a>";
    return http_string_answer(parse_rxml(s,id),"text/html");
  }
  if(!file)
    return 0;
  
  if((hiddenp(id) || get_protocol(id) == "ftp") && (!id->auth || !id->auth[0]))
    return http_auth_required(get_host(id));
  
  switch(id->method) {
  case "CHMOD":
  case "MOVE":
    return 0;


   case "MV":
    // This little kluge is used by ftp2 to move files. 
    
    if(!QUERY(put))
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("MV disallowed (since PUT is disallowed)");
      return 0;
    }    

    if(!QUERY(delete) && Stdio.file_size(real_file) != -1)
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("MV disallowed (DELE disabled, can't overwrite file)");
      return 0;
    }

    if(Stdio.file_size(real_file) < -1)
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("MV: Cannot overwrite directory");
      return 0;
    }

    if(QUERY(check_auth) && (!id->auth || !id->auth[0])) {
      TRACE_LEAVE("MV: Permission denied");
      return http_auth_required("foo",
				"<h1>Permission to 'MV' files denied</h1>");
    }
    string movefrom;
    if(!(movefrom=id->misc->move_from)) {
      id->misc->error_code = 405;
      errors++;
      TRACE_LEAVE("MV: No source file");
      return 0;
    }
    moves++;
    
    object privs;
    
// #ifndef THREADS // Ouch. This is is _needed_. Well well...
    if (((int)id->misc->uid) && ((int)id->misc->gid)) {
      // NB: Root-access is prevented.
      privs=Privs("Moving file", (int)id->misc->uid, (int)id->misc->gid );
    }
// #endif
    
    if (QUERY(no_symlinks) &&
	((contains_symlinks(path, real_file)) ||
	 (contains_symlinks(path, .AutoWeb.AutoFile(id,movefrom)->real_path(movefrom))))) {
      privs = 0;
      errors++;
      TRACE_LEAVE("MV: Contains symlinks. Permission denied");
      return http_low_answer(403, "<h2>Permission denied.</h2>");
    }

    TRACE_ENTER("MV: Accepted", 0);

    /* Clear the stat-cache for this file */
    if (stat_cache) {
      cache_set("stat_cache",
		.AutoWeb.AutoFile(id, f)->real_path(f, "file-cache"), 0);
      cache_set("stat_cache",
		.AutoWeb.AutoFile(id, movefrom)->real_path(movefrom, "file-cache"), 0);
    }
#ifdef DEBUG
    report_notice("Moving file "+movefrom+" to "+ f+"\n");
#endif /* DEBUG */

    int code = .AutoWeb.AutoFile(id,movefrom)->move(f);
    privs = 0;

    if(!code)
    {
      id->misc->error_code = 403;
      TRACE_LEAVE("MV: Move failed");
      TRACE_LEAVE("Failure");
      return 0;
    }
    TRACE_LEAVE("MV: Success");
    TRACE_LEAVE("Success");
    return http_string_answer("Ok");



  case "DELETE":
    if(!QUERY(delete) || Stdio.file_size(real_file)==-1)
    {
      id->misc->error_code = 405;
      TRACE_LEAVE("DELETE: Disabled");
      return 0;
    }
    if(QUERY(check_auth) && (!id->auth || !id->auth[0])) {
      TRACE_LEAVE("DELETE: Permission denied");
      return http_low_answer(403, "<h1>Permission to DELETE file denied</h1>");
    }

    if (QUERY(no_symlinks) && (contains_symlinks(path, real_file))) {
      errors++;
      report_error("Deletion of " + f + " failed. Permission denied.\n");
      TRACE_LEAVE("DELETE: Contains symlinks");
      return http_low_answer(403, "<h2>Permission denied.</h2>");
    }

    report_notice("DELETING the file "+f+"\n");
    accesses++;

    if (((int)id->misc->uid) && ((int)id->misc->gid) &&
      (QUERY(access_as_user))) {
      // NB: Root-access is prevented.
      privs=Privs("Deleting file", id->misc->uid, id->misc->gid );
    }

    /* Clear the stat-cache for this file */
    if (stat_cache) {
      cache_set("stat_cache",
		.AutoWeb.AutoFile(id, f)->real_path(f, "file-cache"), 0);
    }

    if(!.AutoWeb.AutoFile(id,f)->rm())
    {
      privs = 0;
      id->misc->error_code = 405;
      TRACE_LEAVE("DELETE: Failed");
      return 0;
    }
    .AutoWeb.AutoFile(id,f+".md")->rm();
    privs = 0;
    deletes++;
    TRACE_LEAVE("DELETE: Success");
    return http_low_answer(200,(f+" DELETED from the server"));




  case "PUT":
    string oldf = real_file;
    //werror("f: %O, file: %O, real_path: %O\n", f, file, real_file);
    if(!QUERY(put)) {
      id->misc->error_code = 405;
      TRACE_LEAVE("PUT disallowed");
      return 0;
    }    

    if(QUERY(check_auth) && (!id->auth || !id->auth[0])) {
      TRACE_LEAVE("PUT: Permission denied");
      return http_auth_required("foo",
				"<h1>Permission to 'PUT' files denied</h1>");
    }
    if(!AutoFile(id, f)->visiblep()) {
      id->misc->error_code = 403;
      TRACE_LEAVE("PUT: forbidden characters in filename");
      TRACE_LEAVE("Failure");
      return 0;
    }
    puts++;
    
// #ifndef THREADS // Ouch. This is is _needed_. Well well...
    if (((int)id->misc->uid) && ((int)id->misc->gid) &&
      (QUERY(access_as_user))) {
      // NB: Root-access is prevented.
      privs=Privs("Saving file", (int)id->misc->uid, (int)id->misc->gid );
    }
// #endif

    if (QUERY(no_symlinks) && (contains_symlinks(path, oldf))) {
      privs = 0;
      errors++;
      report_error("Creation of "+real_file+" failed. Permission denied.\n");
      TRACE_LEAVE("PUT: Contains symlinks. Permission denied");
      return http_low_answer(403, "<h2>Permission denied.</h2>");
    }

    TRACE_ENTER("PUT: Accepted", 0);

    rm( real_file );
    mkdirhier( real_file );

    /* Clear the stat-cache for this file */
    if (stat_cache) {
      cache_set("stat_cache",
		.AutoWeb.AutoFile(id, f)->real_path(f, "file-cache"), 0);
    }

    object to = .AutoWeb.AutoFile(id, f);
    
    privs = 0;

    if(!to->writable())
    {
      id->misc->error_code = 403;
      TRACE_LEAVE("PUT: Open failed");
      TRACE_LEAVE("Failure");
      return 0;
    }
    chmod(real_file, 0666 & ~(id->misc->umask || 022));
    putting[id->my_fd]=id->misc->len;
    string contents = "";
    if(id->data && strlen(id->data))
    {
      putting[id->my_fd] -= strlen(id->data);
      contents += id->data;
    }
    if(!putting[id->my_fd]) {
      TRACE_LEAVE("PUT: Just a string");
      TRACE_LEAVE("Put: Success");
      save_file(contents, to, id);
      return http_string_answer("Ok");
    }

    if(id->clientprot == "HTTP/1.1") {
      id->my_fd->write("HTTP/1.1 100 Continue\r\n");
    }
    id->my_fd->set_id( ({ to, id->my_fd, contents, id }) );
    id->my_fd->set_nonblocking(got_put_data, 0, done_with_put);
    TRACE_LEAVE("PUT: Pipe in progress");
    TRACE_LEAVE("PUT: Success so far");
    return http_pipe_in_progress();
    break;
  }
  
  mixed res = filesystem::find_file(file, id);
  if(objectp(res)) {
    mapping md = .AutoWeb.MetaData(id, "/"+f)->get();
    id->misc->md = md;
    if(md->content_type=="text/html") {
      string d = res->read();
      if((md->template) && (md->template!="No") && (get_protocol(id) != "ftp"))
	d = "<template><content>"+d+"</content></template>";
      int t=gethrtime();
      id->misc->seclevel=1;
      if(get_protocol(id) != "ftp")
	d = parse_rxml(d, id);
      res = http_string_answer(d, "text/html");
      //werror("parse_rxml: %f (f: %O)\n",(gethrtime()-t)/1000.0,f);
    }
  }
  return res;
}


string real_file(string f, mixed id)
{
  if(!sizeof(f) || f=="/")
    return 0;
  if(!host_to_id)
    update_host_cache(id);
  string file=file_from_host(id,f);
  if(!file)
    return 0; // FIXME, return a helpful page
  array(int) fs;

  // Use the inherited stat_file
  fs = filesystem::stat_file( file,id );

  if (fs && ((fs[1] >= 0) || (fs[1] == -2)))
    return f;
  return 0;
}

array find_dir(string f, object id)
{
  if(!host_to_id)
    update_host_cache(id);
  string file=file_from_host(id,f);
  if(!file)
    return 0; // FIXME, return got->conf->userlist(id);
  array files = filesystem::find_dir(file, id);
  return (files?Array.filter(files,
			     lambda(string file, object id) {
			       return .AutoWeb.AutoFile(id, file)->visiblep();
			     }, id):0);
}

mixed stat_file(mixed f, mixed id)
{
  if(!host_to_id)
    update_host_cache(id);
  string file=file_from_host(id,f);
  if(!file)
    return 0;
  else
    return filesystem::stat_file( file,id );
}

string tag_update(string tag_name, mapping args, object id)
{
  update_host_cache(id);
  update_hidden_sites(id);
  return "Filesystem configuration reloaded.";
}

string tag_init_home_dir(string tag_name, mapping args, object id)
{
  if(!args->id)
    return "error";
  string dir=combine_path(query("searchpath"),(string)(int)args->id);
  // I don't know why, but this feels dangerous...
  Process.popen("rm -rf "+dir);
  mkdir(dir);
  mkdir(dir+"/templates/");
  Stdio.write_file(dir+"/index.html",
		   replace(query("defaulttext"),"$$COMPANY$$",args->company||""));
  Stdio.write_file(dir+"/templates/default.tmpl","<tmplinsertall>");
  Process.popen("cp "+combine_path(__FILE__,"../../../default_site")+"/* "+dir+"/");
  return "Customer initialized";
}

mapping query_tag_callers()
{
  return ([ "autosite-fs-update" : tag_update,
	    "autosite-fs-init-home-dir" : tag_init_home_dir  ]);
}


// Auth stuff.
string get_protocol(object id)
{
  if(id->prot == "FTP")
    return "ftp";
  if(id->prot[..3] == "HTTP")
    return "http";
  return "unknown";
}

array auth(array auth, object id)
{
  if(!host_to_id) update_host_cache(id);
  string protocol = get_protocol(id);
  string username, password, host;
  [username, password] = auth[1]/":";
  
  if(protocol == "ftp") {
    array info = username/"*";
    if(sizeof(info) < 2)
      info = username/"@";
    if(sizeof(info) < 2) {
      //werror("User not ok (no host info).\n");
      return ({ 0, username, password });;
    }
    [username, host] = info;
  }
  if(protocol == "http") {
    host = (id->misc->host?lower_case((id->misc->host/":")[0]):0);
  }
  id->misc->customer_id = host_to_id[host];
  //werror("User: %O, Pass: %O, Host: %O, Customer %O\n",
  //	 username, password, host, id->misc->customer_id);
  
  array a = id->conf->sql_connect(DB_ALIAS)->
    query("select user_id,password from customers where id='"+
	  id->misc->customer_id+"'");
  
  if(!sizeof(a)) {
    //werror("User unknown\n");
    return ({ 0, username, password });
  }
  
  if(a[0]->user_id == username && a[0]->password == password) {
    //werror("User ok\n");
    return ({ 1, username, 0 });
  }
  //werror("User not ok\n");
  return ({ 0, username, password });;
}

array userinfo(string user_name)
{
  //werror("Userinfo: %O\n", user_name);
  return user_from_uid(1);
}

array user_from_uid(int uid)
{
  //werror("User_from_uid: %O\n", uid);
  //({ user_name, password, uid, gid, real_name, home_directory, login_shell })
  return ({ "foo", "*", uid, "", "", "", "" });
}

array userlist()
{
  //werror("Userlist\n");
  return ({ });
}
