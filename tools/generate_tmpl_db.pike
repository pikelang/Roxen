#!/usr/local/bin/pike

#define DB_URL "mysql://auto:site@kopparorm.idonex.se/autosite"

object db;

string tag_insert(string tag, mapping args, mapping oa)
{
  string cols = "", values = ""; 
  int i = 0;
  if(oa->switchvariable) {
    string query = "select * from template_wizards where name='"+
		    args->wizard_name+"' and category='"+args->category+"'";
    string result = db->query(query);
    if(sizeof(result)>0) 
      args->wizard_id = db->query(query)[0]->id;
    else {
      write("  *** Wizard ["+args->wizard_name+"] does not exist\n");
      return "";
    }
    args -= ([ "wizard_name":"" ]);
  }
  foreach(indices(args), string arg) {
    cols += (i?",":"")+arg;
    values += (i?",":"")+"'"+db->quote(args[arg])+"'";
    i++;
  }
  string q = sprintf("insert into " +
		     oa->table + " ("+cols+") values ("+values+")");
  db->query(q);
  write("  "+q+"\n");
}

string tag_delete(string tag, mapping args, mapping oa)
{
  if(args->all) {
    string q = "delete from "+oa->table;
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
	     args);
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
