/*
 * $Id: flush.pike,v 1.7 1998/11/18 04:54:02 per Exp $
 */

inherit "wizard";
inherit "configlocale";
constant name_standard= "Cache//Flush caches...";
constant name_svenska= "Cache//Töm cachear...";

constant doc_standard = ("Flush a cache or two");
constant doc_svenska = ("Töm en cache eller två");

mixed page_0(object id, object mc)
{
  return LOCALE()->flush_page_0();
}

#define CHECKED(x) (id->variables->x != "0")

mixed page_1(object id, object mc)
{
  string ret = "";
  if(CHECKED(user_cache))   
    ret += String.capitalize(LOCALE()->flush_userdbcache())+"<br>";
  if(CHECKED(memory_cache)) 
    ret += String.capitalize(LOCALE()->flush_memorycache())+"<br>";
  if(CHECKED(dir_cache))    
    ret += String.capitalize(LOCALE()->flush_directorycache())+"<br>";
  if(CHECKED(module_cache)) 
    ret += String.capitalize(LOCALE()->flush_modulecache())+"<br>";
  if(CHECKED(gtext_cache)) 
    ret += String.capitalize(LOCALE()->flush_gtextcache())+"<br>";
  if(!strlen(ret))
    ret = LOCALE()->flush_nothing();

  return  LOCALE()->flush_toflush()+ ret;
}

string text_andify( array(string) info )
{
  int i=0;
  int l=sizeof(info);
  string ret;

  foreach( info, string item )
  {
    i++;
    if(i==1) ret = item;
    else
      if(i==l) ret += " "+locale()->and+" "+ item;
      else ret += ", "+ item;
  }
  return ret;
}

mixed wizard_done(object id, object mc)
{
  gc();

  array(string) info= ({ });
  
  /* Flush the userdb. */ 
  if(CHECKED(user_cache))
  {
    info += ({ LOCALE()->flush_userdbcache() });
    foreach(roxen->configurations, object c)
      if(c->modules["userdb"] && c->modules["userdb"]->master)
	c->modules["userdb"]->master->read_data();
  }
  
  /* Flush the memory cache. */ 
  if(CHECKED(memory_cache))
  {
    info += ({ LOCALE()->flush_memorycache() });
    function_object(cache_set)->cache = ([]);
  }

  /* Flush the gtext cache. */ 
  if(CHECKED(gtext_cache))
  {
    info += ({ LOCALE()->flush_gtextcache() });
    foreach(roxen->configurations, object c)
    {
      if(c->modules["graphic_text"] && 
	 (c=c->modules["graphic_text"]->enabled))
      {
	catch{
	  foreach(get_dir(c->query("cache_dir")), string d)
	    rm(c->query("cache_dir")+d);
	};
      }
    }
  }

  /* Flush the dir cache. */ 
  if(CHECKED(dir_cache))
  {
    info += ({ LOCALE()->flush_directorycache() });
  foreach(roxen->configurations, object c)
    if(c->modules["directories"] && (c=c->modules["directories"]->enabled))
    {
      catch{
	c->_root->dest();
	c->_root = 0;
      };
    }
  }
  
  /* Flush the module cache. */ 
  if(CHECKED(module_cache))
  {
    info += ({ LOCALE()->flush_modulecache()  });
    roxen->allmodules=0;
    roxen->module_stat_cache=([]);
  }

  if(info)
    report_notice(LOCALE()->flush_flushed() + " " + text_andify(info) + ".\n");

  gc();
}

mixed handle(object id) { return wizard_for(id,0); }
