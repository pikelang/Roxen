// This is a ChiliMoon module. Copyright © 2001, Roxen IS.

constant cvs_version =
  "$Id: userdb_system.pike,v 1.12 2004/05/23 02:35:25 _cvs_stephen Exp $";
#ifndef __NT__
inherit UserDB;
#endif
inherit "module";

constant name = "system";

#include <module.h>

constant module_name = "Authentication: System user database";
constant  module_doc = "The system user and group database";


#ifndef __NT__
Thread.Mutex mt = Thread.Mutex();

/* Unix version. Uses the get[gr,pw]ent interface */
static mapping cached_groups = ([]);
static array(SysGroup) full_group_list;

static array(string) get_cached_groups_for_user( int uid )
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
  static array pwent;

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
  
  static void create( UserDB p, array _pwent )
  {
    ::create( p );
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

  static void create( UserDB p, array _grent )
  {
    ::create( p );
    grent = _grent;
  }
}

User find_user( string s )
{
  mixed key = mt->lock();
  array a = getpwnam( s );
  if( a )  return SysUser( this_object(), a );
}

User find_user_from_uid( int id )
{
  mixed key = mt->lock();
  array a = getpwuid( id );
  if( a ) return SysUser( this_object(), a );
}

array(string) list_users( )
{
  return get_all_users()[*][0];
}

static mapping(string|int:Group) group_cache = ([]);

Group find_group( string group )
{
  if( group_cache[ group ] )
    return group_cache[ group ];
  
  mixed key = mt->lock();
  array a = getgrnam( group );
  if( a )
  {
    call_out( m_delete, 60, group_cache, group );
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
    call_out( m_delete, 60, cached_groups, id );
    return group_cache[ id ] = SysGroup( this_object(), a );
  }
}

array(string) list_groups( )
{
  if( full_group_list )
    return full_group_list->name();

  array res = ({});
  foreach( get_all_groups(), array a )
  {
    res += ({ SysGroup( this, a ) });
    group_cache[ res[-1]->name() ] = res[-1];
    group_cache[ res[-1]->gid() ] = res[-1];
  }
  full_group_list = res;
  call_out( lambda(){ full_group_list = 0; cached_groups=([]); }, 60 );
  return res->name();
}
#else
/* TBD: NT version */
#endif
