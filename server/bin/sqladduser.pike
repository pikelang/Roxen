#!/usr/local/bin/pike
#!NO_MODULE

/* $Id$
 *
 * name = "SQL Add user";
 * doc = "Add a user to an SQL user-database.";
 */

/*
 * This program is (C) 1997 Francesco Chemolli <kinkie@kame.usr.dsi.unimi.it>
 * See COPYING in the server directory for license information.
 * This program comes on an AS-IS basis, WITHOUT ANY WARRANTY of any kind,
 * either implicit or esplicit.
 * By using it you implicitly state that you are aware of the risks, and
 * that take upon yourself all the responsabilities for any damage,
 * direct or indirect including loss of profict from the use of this software.
 * Don tell me I hadn't warned you..
 */

#include <sql.h>

string readline_until_got (string query) {
	string retval;
	while (!retval || !sizeof(retval))
		retval=readline("(mandatory) "+query);
	return retval;
}

int main()
{
  mapping data=([]);
  Sql.Sql sql=Sql.Sql("localhost","passwd");
  mixed tmp,err;
  string query;
  data->username=readline_until_got("username: ");
  data->passwd=crypt(readline_until_got("password: "));
  data->uid=readline("(deprecated) user ID: ");
  data->gid=readline("(deprecated) group ID: ");
  data->homedir=readline("home directory: ");
  data->shell=readline("login shell: ");

  foreach(indices(data),tmp) {
    if (!sizeof(data[tmp]))
      data-=([tmp:0]);
  }

  if(data->uid)
    data->uid=(int)data->uid;
  if(data->gid)
    data->gid=(int)data->gid;

  query="insert into passwd (" + (indices(data)*",") +
		") values (";
  foreach (values(data),tmp) {
    if (stringp(tmp))
      query += sprintf ("'%s',",sql->quote(tmp));
    else
      query += tmp+",";
  }
	
  query=query[..sizeof(query)-2];
  query += ")";

  tmp=sql->query("select * from passwd where username = '"+data->username+"'");
  if (sizeof(tmp))
    sql->query("delete from passwd where username = '"+data->username+"'");

  err= catch {
    sql->query(query);
  };
  if (err) {
    write("SQL query error: "+sql->error()+"\n");
    write("query was: "+query+"\n");
    return 1;
  }
}

