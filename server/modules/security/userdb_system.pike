// This is a roxen module. Copyright © 2001 - 2009, Roxen IS.

constant cvs_version =
  "$Id$";
#ifndef __NT__
inherit UserDB;
#endif
inherit "module";

constant name = "system";

//<locale-token project="mod_userdb_system">_</locale-token>
#define _(X,Y)	_DEF_LOCALE("mod_userdb_system",X,Y)

#include <module.h>

LocaleString module_name =
  _(1,"Authentication: System user database");

LocaleString module_doc =
  _(2,"The system user and group database");


#ifndef __NT__
Thread.Mutex mt = Thread.Mutex();

/* Unix version. Uses the get[gr,pw]ent interface */
protected mapping cached_groups = ([]);
protected array(SysGroup) full_group_list;

/* Time to cache stuff in seconds. */
#define MAX_CACHE_TIME	60

protected array(string) get_cached_groups_for_user( int uid )
{
  if(cached_groups[ uid ] )
    return cached_groups[ uid ];

  if( sizeof( cached_groups ) )
    return ({});

  array res = ({});
  if( !full_group_list )
    list_groups();

  cached_groups=([]);

  foreach( full_group_list, Group g )
  {
    foreach( g->members(), string user )
    {
      User u = find_user( user );
      if( u )
      {
	int uid = u->uid();
	if( !cached_groups[ uid ] )
	  cached_groups[ uid ] = ({});
	cached_groups[ uid ] += ({ g->name() });
      }
    }
  }

  foreach( list_users(), string un )
  {
    int uid;
    if( User uu = find_user( un ) )
    {
      uid = uu->uid();
      if( Group g = find_group_from_gid( uu->gid() ) )
	cached_groups[ uid ] = ({ g->name() })|(cached_groups[ uid ]||({}));
    }
  }

  return cached_groups[uid] || ({});
}

class SysUser
{
  inherit User;
  protected array pwent;

  int expiry_time = time(1) + MAX_CACHE_TIME;

  string name()             { return pwent[0]; }
  string crypted_password() { return pwent[1]; }
  int uid()                 { return pwent[2]; }
  int gid()                 { return pwent[3]; }
  string gecos()            { return pwent[4]; }
  string real_name()        { return(pwent[4]/",")[0]; }
  string homedir()          { return pwent[5]; }
  string shell()            { return pwent[6]; }
  array compat_userinfo()   { return pwent;    }

  array(string) groups()
  {
    return /*({  })|*/ get_cached_groups_for_user( uid() );
  }
  
  protected void create( UserDB p, array _pwent )
  {
    ::create( p );
    foreach(({ 0, 4 }), int fieldno) {
      catch {
	pwent[fieldno] = utf8_to_string(pwent[fieldno]);
      };
    }
    pwent = _pwent;
  }
}

class SysGroup
{
  inherit Group;
  array grent;
  int gid()                { return grent[2]; }
  string name()            { return grent[0]; }
  array(string) members()  { return grent[3]; }

  protected void create( UserDB p, array _grent )
  {
    ::create( p );
    catch {
      grent[0] = utf8_to_string(grent[0]);
    };
    foreach(grent[3]; int fieldno; string user) {
      catch {
	grent[3][fieldno] = utf8_to_string(user);
      };
    }
    grent = _grent;
  }
}

protected mapping(string|int:SysUser|int) cached_users =
  set_weak_flag(([]), Pike.WEAK);

User find_user( string s )
{
  int|User res = cached_users[s];
  if (!zero_type(res)) {
    if (intp(res) && (res > time(1))) return 0;
    if (objectp(res) && (res->expiry_time > time(1))) return res;
    // NB: Can't invalidate cached_users here due to races.
  }
  mixed key = mt->lock();
  res = cached_users[s];
  if (!zero_type(res)) {
    if (intp(res) && (res > time(1))) return 0;
    if (objectp(res)) {
      if (res->expiry_time > time(1)) return res;
      int id = res->uid();
      if (id) m_delete(cached_users, id);
    }
  }
  object p = Privs("getpwnam");
  array a = getpwnam( string_to_utf8(s) );
  p = UNDEFINED;
  res = 0;
  if( a ) {
    res = SysUser( this_object(), a );
    int id = res->uid();
    if (id) {
      cached_users[id] = res;
    }
    cached_users[s] = res;
  } else {
    cached_users[s] = time(1) + MAX_CACHE_TIME;
  }
  return res;
}

User find_user_from_uid( int id )
{
  int|User res = cached_users[id];
  if (!zero_type(res)) {
    if (intp(res) && (res > time(1))) return 0;
    if (objectp(res) && (res->expiry_time > time(1))) return res;
    // NB: Can't invalidate cached_users here due to races.
  }
  mixed key = mt->lock();
  res = cached_users[id];
  if (!zero_type(res)) {
    if (intp(res) && (res > time(1))) return 0;
    if (objectp(res) && (res->expiry_time > time(1))) return res;
    string name = res->name();
    if (sizeof(name||"")) m_delete(cached_users, name);
  }
  object p = Privs("getpwuid");
  array a = getpwuid( id );
  p = UNDEFINED;
  res = 0;
  if( a ) {
    res = SysUser( this_object(), a );
    string name = res->name();
    if (sizeof(name||"")) {
      cached_users[name] = res;
    }
    cached_users[id] = res;
  } else {
    cached_users[id] = time(1) + MAX_CACHE_TIME;
  }
  return res;
}

array(string) list_users( )
{
  array res = ({});
  array a;
  mixed key = mt->lock();
  object p = Privs("getpwent");
  System.setpwent();
  while( a = System.getpwent() )
    res += ({ a[0] });
//   endpwent();
  p = UNDEFINED;
  return res;
}

protected mapping(string|int:Group) group_cache = ([]);

Group find_group( string group )
{
  if( group_cache[ group ] )
    return group_cache[ group ];
  
  mixed key = mt->lock();
  array a = getgrnam( string_to_utf8(group) );
  if( a )
  {
    call_out( m_delete, MAX_CACHE_TIME, group_cache, group );
    return group_cache[ group ] = SysGroup( this_object(), a );
  }
}

Group find_group_from_gid( int id  )
{
  if( group_cache[ id ] )
    return group_cache[ id ];

  mixed key = mt->lock();
  array a = getgrgid( id );
  if( a )
  {
    call_out( m_delete, MAX_CACHE_TIME, cached_groups, id );
    return group_cache[ id ] = SysGroup( this_object(), a );
  }
}

array(string) list_groups( )
{
  if( full_group_list )
    return full_group_list->name();

  array res = ({});
  array a;
  mixed key = mt->lock();
  System.endgrent();
  while( a = System.getgrent() )
  {
    res += ({ SysGroup( this_object(), a ) });
    group_cache[ res[-1]->name() ] = res[-1];
    group_cache[ res[-1]->gid() ] = res[-1];
  }
  System.endgrent();
  full_group_list = res;
  call_out( lambda(){ full_group_list = 0; cached_groups=([]); },
	    MAX_CACHE_TIME );
  return res->name();
}
#else
/* TBD: NT version */
#endif
