constant cvs_version =
  "$Id: userdb_system.pike,v 1.4 2001/01/29 22:39:56 per Exp $";
inherit UserDB;
inherit "module";

constant name = "system";

//<locale-token project="mod_userdb_system">_</locale-token>
#define _(X,Y)	_DEF_LOCALE("mod_userdb_system",X,Y)

#include <module.h>

LocaleString module_name =
  _(1,"System user database");

LocaleString module_doc =
  _(2,"The system user and group database");


#ifndef __NT__
Thread.Mutex mt = Thread.Mutex();

/* Unix version. Uses the get[gr,pw]ent interface */
static mapping pwuid_cache = ([]);
static mapping cached_groups = ([]);
static array get_cached_groups_for_user( int uid )
{
  mixed key = mt->lock();
  if(cached_groups[ uid ] && cached_groups[ uid ][1]+200>time(1))
    return cached_groups[ uid ][0];
  array grps = get_groups_for_user( uid );
  key = 0;
  return (cached_groups[uid] = ({ (map(grps,find_group_from_gid)-({0}))
				  ->name(), time(1) }))[0];
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
//  find_group_from_gid(gid())->name()
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
  array res = ({});
  array a;
  mixed key = mt->lock();
  endpwent();
  while( a = getpwent() ) res += ({ a[0] });
  endpwent();
  return res;
}

Group find_group( string group )
{
  mixed key = mt->lock();
  array a = getgrnam( group );
  if( a ) return SysGroup( this_object(), a );
}

Group find_group_from_gid( int id  )
{
  mixed key = mt->lock();
  array a = getgrgid( id );
  if( a ) return SysGroup( this_object(), a );
}

array(string) list_groups( )
{
  array res = ({});
  array a;
  mixed key = mt->lock();
  endgrent();
  while( a = getgrent() ) res += ({ a[0] });
  endgrent();
  return res;
}
#else
/* TBD: NT version */
#endif
