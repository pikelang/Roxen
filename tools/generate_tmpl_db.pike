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
      args -= ([ variable:1 ]);
    }
    
    array query_result = db->query(query);
    if(!sizeof(query_result)||!sizeof(indices(query_result[0]))) {
      write("  *** query ["+query+"] returns zero rows\n");
      return "";
    }
    args[oa->insertvariable] = query_result[0][indices(query_result[0])[0]];
  }
  //werror("%O", args);
  if(oa->removevariables2&&
     oa->insertvariable2&&
     oa->query2&&args[(oa->removevariables2/",")[0]])
    {
    string query = oa->query2;
    foreach(oa->removevariables2/",", string variable) {
      query = replace(query, "#"+variable+"#", args[variable]);
      args -= ([ variable:1 ]);
    }
    
    array query_result = db->query(query);
    if(!sizeof(query_result)||!sizeof(indices(query_result[0]))) {
      write("  *** query ["+query+"] returns zero rows\n");
      return "";
    }
    args[oa->insertvariable2] = query_result[0][indices(query_result[0])[0]];
  }
  
  foreach(indices(args), string arg) {
    cols += (i?",":"")+arg;
    values += (i?",":"")+"'"+db->quote(args[arg])+"'";
    i++;
  }
  string q = "insert into " +
	     oa->table + " ("+cols+") values ("+values+")";
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

string tag_update(string tag, mapping args, mapping oa)
{
  string quote = oa->quote;
  while(sscanf(args->expression, "%*s"+quote+"%s"+quote+"%*s", string from)>=2) {
    string query = replace(oa->query, quote+quote, from);
    array query_result = db->query(query);
    if(!sizeof(query_result)||!sizeof(indices(query_result[0]))) {
      write("  *** query ["+query+"] returns zero rows\n");
      return "";
    }
    args->expression = replace(args->expression, quote+from+quote,
			       query_result[0][indices(query_result[0])[0]]);
  }
  string q = ("UPDATE "+oa->table+" SET "+
	      args->column+"='"+args->expression+"' WHERE "+
	      args->where);
  db->query(q);
  //  write(q+"\n");
}

string container_sql_insert(string tag, mapping args, string contents)
{
  write(args->table+"\n");
  parse_html(contents,
	     ([ "insert":tag_insert, "delete":tag_delete, "update":tag_update ]),
	     ([ ]),
	     args);
}

int main(int argc, array(string) argv)
{
  if(!(db=Sql.sql(DB_URL))) {
    write("Can not connect to sql server\n");
    return 0;
  }

  if(argc<2) {
    write("USAGE: generate.pike inputfile\n");
    return 0;
  }
  
  string s = Stdio.read_bytes(argv[1]);
  if(!s) {
    write("File not found\n");
  }
  
  spider;
  parse_html(s, ([ ]), ([ "sql-insert":container_sql_insert ]) );
  return 1;
}
