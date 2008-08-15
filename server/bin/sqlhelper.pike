// Made by Stewa

#if 1
#define SIM_TO()
#else
#define SIM_TO() { if(!random(50)) ___broken = 1; if(!random(2)) { werror("sqlhelper: faking stalled connection.\n");  sleep(99999); }  if(___broken) { werror("sqlhelper: faking oracle connection error.\n");  throw(({"foo ORA-3113: foo bar",backtrace() })); }  }
int ___broken;
#endif

#if 1
#define SIM_LC()
#else
#define SIM_LC() { if(!random(20)) { werror("sqlhelper: faking lost connection.\n");  db=0; } }
#endif

object pipe;

private void write(string s) {
  if(pipe->write(s) != sizeof(s))
    //FIXME: nicer?
     exit(0);
}

void write_msg(string s) {
  write(sprintf("@@%8x",sizeof(s)));
  write(s);
}


string get_msg() {
  string l=pipe->read(10);
  if(!l)
    exit(0);
  //FIXME

  int len;
  if(!sscanf(l,"@@%8x",len))
    return 0;
  return pipe->read(len);
}


void sigpipe() {
  exit(0);
}

void sigint() {
  catch {
    destruct(db);
  };
  exit(0);
}

void handle_err(mixed err) {
  if(arrayp(err) && sizeof(err) && stringp(err[0])) {
    string bt = "";
    if((sizeof(err) > 1) && arrayp(err[1]))
      catch {
	bt = "\n" + describe_backtrace(err[1]);
      };
    write_msg(encode_value( ({ "E",err[0] + bt }) ));
  }
  else
    write_msg(encode_value( ({ "E","Remote call failed." }) ));
}

void main() {
  signal(13, sigpipe  );
  signal(signum("INT"), sigint);
  pipe=Stdio.File(3);
  string s;
  for(;;) {
    s=get_msg();
    if(!s)
      write_msg(encode_value( ({ "E", "Corrupt message." }) ));
    //predef::write(sprintf("MSG: %O\n",s));
    mixed ret;
    mixed err;
    array cmd;
    if(!(err = catch(cmd = decode_value(s)))) {
      if(!db && cmd[0]!="connect") {
	werror("sqlhelper: The DB connection has been closed. Attempting to reconnect.\n");
	err = catch { 
	  if_connect(db_url);
	};
	if(err) {
	  handle_err(err);
	  continue;
	}
      }
      err = catch { 
	ret = this_object()["if_"+cmd[0]](@cmd[1..]);
      };
    }
    if(err)
      handle_err(err);
    else {
      write_msg(encode_value( ({ "OK", ret }) ));
      //predef::write(sprintf("$$ %O\n",ret));
    }
  }
}

// Interface functions

Sql.Sql db;
string db_url;

void if_connect(string connect_string) {
  db_url = connect_string;
  db = Sql.Sql(connect_string);
}

string if_ping(string s) {
  return "pong"+s;
}

mixed if_test() {
  return ({ "hej",12,([1:2])   });
}

/////////////////////////////

mapping fix_row(array fields, array row) {
  mapping m = ([ ]);
  
  for(int i=0; i < sizeof(fields); i++) {
#if constant(Oracle.NULL)
    string data =
      ( row[i] == Oracle.NULL ||
	row[i] == Oracle.NULLint ||
	row[i] == Oracle.NULLdate ||
	row[i] == Oracle.NULLstring ||
	row[i] == Oracle.NULLfloat )
      ? "" : (string)row[i];
#else
    string data = row[i];
#endif
    m[ fields[ i ]->name ] = data;
  }
  return m;
}

mixed if_query(mixed ... args) {
  SIM_TO();

  array res = ({ });
  mapping bindings;

  //res = db->query(@args);
  
  if(sizeof(args) > 1 && mappingp(args[1])) {
    mapping new_bindings = ([ ]);
    foreach(indices(args[1]),string ind) {
      if(ind[0..2] == "@@@")
	new_bindings[ind[3..]] = String.string2hex(args[1][ind]);
      else {
	new_bindings[ind] = args[1][ind];
      }
    }
    bindings = new_bindings;
  }  

  object q = bindings ? db->big_query(args[0], bindings) : db->big_query(args[0]);
  if(!q)
    return res;
  array f = q->fetch_fields();
  array r;
  while( r = q->fetch_row() ){
    res += ({ fix_row(f,r) });
  }
  
  /* 
  if(res && arrayp(res))
    foreach(res, mapping m)
      foreach(indices(m),string s)
	m[s] = m[s] ? (string)m[s] : "";
  */

  SIM_LC();
  return res;
}

mixed if_big_query(mixed ... args) {
  SIM_TO();
  //FIXME: this won't work, but is currently not used.
  SIM_LC();
  return db->big_query(@args);
}

mixed if_blobupdate(mixed ... args) {
  SIM_TO();
  SIM_LC();

  string table = args[0];
  string blob = args[1];
  string where = args[2];
  string contents = args[3];

  object o = db->master_sql->big_typed_query("select "+blob+" from "+table+" where "+where+" FOR UPDATE",([ ]),1);
  mixed res = o->fetch_row();
  res[0]->write(contents);
  db->master_sql->commit();
  o = 0;
  return 0;
}

mixed if_error(mixed ... args) {
  return db->error(@args);
}

mixed if_select_db(mixed ... args) {
  return db->select_db(@args);
}

mixed if_quote(mixed ... args) {
  return db->quote(@args);
}

mixed if_encode_time(mixed ... args) {
  return db->encode_time(@args);
}

mixed if_decode_time(mixed ... args) {
  return db->decode_time(@args);
}

mixed if_encode_date(mixed ... args) {
  return db->encode_date(@args);
}

mixed if_decode_date(mixed ... args) {
  return db->decode_date(@args);
}

mixed if_encode_datetime(mixed ... args) {
  return db->encode_datetime(@args);
}

mixed if_decode_datetime(mixed ... args) {
  return db->decode_datetime(@args);
}

mixed if_compile_query(mixed ... args) {
  return db->compile_query(@args);
}

mixed if_create_db(mixed ... args) {
  return db->create_db(@args);
}

mixed if_drop_db(mixed ... args) {
  return db->drop_db(@args);
}

mixed if_shutdown(mixed ... args) {
  return db->shutdown(@args);
}

mixed if_reload(mixed ... args) {
  return db->reload(@args);
}
mixed if_server_info(mixed ... args) {
  return db->server_info(@args);
}

mixed if_host_info(mixed ... args) {
  return db->host_info(@args);
}

mixed if_list_dbs(mixed ... args) {
  return db->list_dbs(@args);
}

mixed if_list_tables(mixed ... args) {
  return db->list_tables(@args);
}

mixed if_list_fields(mixed ... args) {
  return db->list_fields(@args);
}

mixed if_case_convert(mixed ... args) {
  return db->case_convert(@args);
}

mixed if_set_charset(mixed ... args) {
  return db->set_charset(@args);
}

mixed if_get_charset(mixed ... args) {
  return db->get_charset(@args);
}
