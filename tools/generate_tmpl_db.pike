#!/usr/local/bin/pike

#define DB_URL "mysql://root@localhost/autosite"

object db;

string tag_insert(string tag, mapping args, mapping oa)
{
  string cols = "", values = ""; 
  int i = 0;
  if(oa->removevariables&&
     oa->insertvariable&&
     oa->query)
  {
    string query = oa->query;
    foreach(oa->removevariables/",", string variable) {
      query = replace(query, "#"+variable+"#", args[variable]);
    }
    
    array query_result = db->query(query);
    if(!sizeof(query_result)) {
      write("  *** query ["+query+"] returns zero rows\n");
      return "";
    }
    args[oa->insertvariable] = query_result[0]->id;
    
    foreach(oa->removevariables/",", string variable) {
      args -= ([ variable:1 ]);
    }
  }
  
  foreach(indices(args), string arg) {
    cols += (i?",":"")+arg;
    values += (i?",":"")+"'"+db->quote(args[arg])+"'";
    i++;
  }
  string q = sprintf("insert into " +
		     oa->table + " ("+cols+") values ("+values+")");
  db->query(q);
  //write("  "+q+"\n");
  return "";
}

string tag_delete(string tag, mapping args, mapping oa)
{
  if(args->all) {
    string q = "delete from "+oa->table;
    db->query(q);
    //write("  "+q+"\n");
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
    write("File not found");
  }
  
  spider;
  parse_html(s, ([ ]), ([ "sql-insert" : container_sql_insert ]) );
  return 1;
}
