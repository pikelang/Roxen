#!/usr/local/bin/pike

#define DB_URL "mysql://auto:site@kopparorm.idonex.se/autosite"

object db;

string tag_insert(string tag, mapping args, string table )
{
  string cols = "", values = ""; 
  int i = 0;
  foreach(indices(args), string arg) {
    cols += (i?",":"")+arg;
    values += (i?",":"")+"'"+db->quote(args[arg])+"'";
    i++;
  }
  string q = sprintf("insert into " + table + " ("+cols+") values ("+values+")");
  db->query(q);
  write("  "+q+"\n");
}

string tag_delete(string tag, mapping args, string table )
{
  if(args->all) {
    string q = "delete from "+table;
    db->query(q);
    write("  "+q+"\n");
  }
}

string container_sql_insert(string tag, mapping args, string contents)
{
  write(args->table+"\n");
  parse_html(contents,
	     ([ "insert" : tag_insert, "delete" : tag_delete ]),
	     ([ ]),
	     args->table );
}

int main(int argc, array(string) argv)
{
  if(!(db=Sql.sql(DB_URL))) {
    write("Can not connect to sql server");
    return 0;
  }

  if(argc<2) {
    write("USAGE: generate.pike inputfile");
    return 0;
  }
  
  string s = Stdio.read_bytes(argv[1]);
  if(!s) {
    write("File not found or is empty");
  }
  
  spider;
  parse_html(s, ([ ]), ([ "sql-insert" : container_sql_insert ]) );
  return 1;
}
