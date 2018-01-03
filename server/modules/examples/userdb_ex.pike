// This is a roxen module. Copyright © 2001 - 2009, Roxen IS.
#include <module.h>

// Some defines for the translation system
// 
//<locale-token project="mod_auth">LOCALE</locale-token>
#define LOCALE(X,Y)	_DEF_LOCALE("mod_auth",X,Y)
// end of the locale related stuff



inherit UserDB;
inherit "module";
//! A user database module should inherit @[UserDB]. 
//!
//! Which those are will be indicated in the documentation for those
//! functions below. Also, please note that a userdb module has to
//! have the thread_safe flag set to 1.


constant name = "example";
//! The name of the userdatbase, used to identify it from modules or
//! htaccess files or similar that wants to authenticate against a
//! specific database instead of against any of them.
//!
//! The name should be reasonably short and should be unique, however,
//! nothing will break if more than one database has the same name, it
//! will be impossible to know which of them will be used when
//! authentication is done, however..

constant cvs_version="$Id$";

LocaleString module_name = LOCALE(1,"RefDoc for MODULE_USERDB");

LocaleString module_doc =
  LOCALE(2,"This module does nothing special, it implements a simple "
	 "user database with the passwords and usernames in a string list, "
	 "but its inlined documentation gets imported into the Roxen "
	 "programmer manual.\n"
	 "You definetely don't want to use this module in your virtual "
	 "servers, since anybody with access to your admin interface or "
	 "server configuration file automatically gains access to all "
	 "your passwords. For a budding roxen programmer, the module "
	 "however does show the basics of making a user database module.");


protected void create()
// Define a variable that will hold all the users. Only the user id
// (the short name) and the password are defined in this list, but it
// could easily be extended to include more information.
{
  defvar("users", Variable.StringList(({}), VAR_INITIAL,
				      LOCALE(3,"Users and Passwords"),
				      LOCALE(4,"A list of username:password "
					     "pairs.")));
}



class ExUser
//! Each user in the new userdatabase system is represented by a user
//! object.
{
  protected string id;
  protected string pw;
  // Passed when this object is created. This is not really enough to
  // implement all functions below, but it's enough to fulfill the
  // minimum implementation.
  
  inherit User;
  //! This inherit includes prototypes and some implementations of
  //! functions this object has to implement. The default
  //! implementations, if any, are noted below.


  protected void create( string _id, string _pw )
  // Set the variables from the constructor arguments and call the
  // create method in the parent class.
  {
    id = _id;
    pw = _pw;
    ::create( this_module() );
  }
  
  string name()
  //! The name of the user. This is the short name that is used to log
  //! in.
  {
    return id;
  }

  string real_name()
  //! Return the real name of the user.
  // Since we do not have a real name in this module, the short name
  // is returned instead.
  {
    return id;
  }
  
  string homedir()
  //! The home directory of the user. Used as an examply by the user
  //! filesystem.
  // Since we do not have one here, simply return /.
  {
    return "/";
  }

  string crypted_password()
  //! Used by compat_userinfo(). The default implementation returns
  //! "x". You do not really have to implement this function.
  {
    return "x";
  }

  int uid()
  //! A numerical UID, or -1 if not applicable
  {
    return -1;
  }

  int gid()
  //! A numerical GID, or -1 if not applicable
  {
    return -1;
  }

  string shell()
  //! The shell, or 0 if not applicable
  {
    return 0;
  }
   
  string gecos()
  //! The gecos field, the default implementation returns the real
  //! name.
  {
    return real_name();
  }
  
  int password_authenticate(string password)
  //! Return 1 if the password is correct, 0 otherwise. The default
  //! implementation uses the crypted_password() method.
  // Since our password is in clear text, simply compare it with the
  // specified one.
  {
    return password == pw;
  }

  array(string) groups()
  //! Return all groups this user is a member in. The default
  //! implementation returns ({})
  {
    // We return a single group, this is the group that all users are
    // placed in by this module.
    return ({ "example" });
  }
}


class ExGroup
//! ExGroup.
{
  inherit Group;
  //! All groups should inherit the group class.
  
  protected void create()
  // Call the constructor in the parent class.
  {
    ::create( this_module() );
  }
    
  
  string name()
  //! The group name
  {
    // Our one and only group is named example.
    return "example";
  }
  
  int gid()
  //! A numerical GID, or -1 if not applicable
  {
    return -1;
  }
  
  array(string) members()
  //! All users that are members of this group. The default
  //! implementation loops over all users handled by the user database
  //! and looks for users with the same gid as this group.
  {
    // All our users are members of this group, the default
    // implementation would work, bit it would be rather inefficient.
    return list_users(0);
  }
}

protected ExGroup the_one_and_only_group = ExGroup();
// There can be only one.

array(string) list_users( RequestID dummy )
//! Return a list of all users handled by this database module.
{
  return column( map( query( "users" ), `/, ":" ), 0 );
}

array(string) list_groups( RequestID id )
//! Return a list of all groups handled by this database module.
//! The default implementation returns the empty array.
{
  return ({ "example" });
}

User find_user( string s, RequestID id )
//! Find a user from her name.
{
  foreach( query( "users" ), string user_line )
    // This is not the most optimal implementation, but it will do for
    // this module. For a real module a cache would be useful.
    if( has_prefix( user_line, s+":" ) )
      return ExUser( @user_line/":" );
  return 0;
}
  
User find_user_from_uid( int id )
//! Find a user given a UID. The default implementation loops over
//! list_users() and checks the uid() of each one.
{
  // Since we do not have any uid:s, simply return 0.
  return 0;
}

Group find_group( string group )
//! Find a group object given a group name.
//! The default implementation returns 0.
{
  // This is easy in this module, since we only have one group. :-)
  if( group == "example" )
    return the_one_and_only_group;
}

Group find_group_from_gid( int id )
//! Find a group given a GID. The default implementation loops over
//! list_groups() and checks the gid() of each one.
{
  // Again, we do not have gid:s either.
  return 0;
}
