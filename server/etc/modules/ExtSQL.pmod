// Made by Stewa

class sqlproxy {
  
  constant is_remote = 1;

  private object proc,pipe;

  private string connect_string;

  int lastuse, usage_count;

  
  int get_last_use() {
    return lastuse;
  }

  void touch() {
    lastuse = time();
  }
  
  private void write(string s) {
    pipe->write(s);
  }
  
  void write_msg(string s) {
    write(sprintf("@@%8x",sizeof(s)));
    write(s);
  }

  string get_msg() {
    string l=pipe->read(10);
    int len;
    if(!sscanf(l,"@@%8x",len))
      return 0;
    return pipe->read(len);
  }

  mixed remote_call(string cmd,mixed ... args) {
    if((!proc || proc->status()) && cmd!="connect")
      connect();
    write_msg(encode_value( ({ cmd })+args ));
    string s = get_msg();
    if(!s || !stringp(s)) 
      throw( ({sprintf("Remote call failed. Got: %O\n",s),backtrace() }) );
    mixed ret =  decode_value(s);
    if(ret[0]=="OK") {
      //predef::write(sprintf("will return %O\n",ret[1]));
      return ret[1];
    }
    else {
      //predef::write(sprintf("will throw %O\n",ret[1]));
      throw( ({ ret[1], backtrace() }) );
    }
  }

  private void connect() {
    pipe = Stdio.File();
    object pipe_other = pipe->pipe();
    mapping opts = ([ "fds": ({ pipe_other }) ]);

    proc = Process.Process( ({ "bin/roxen","bin/sqlhelper.pike" })
			    , opts );
    remote_call("connect",connect_string);
  }
  
  void create(string _connect_string) {
    connect_string = _connect_string;
    connect();
  }

  void restart() {
    if(proc)
      proc->kill(9);
  }


  string _sprintf() {
    return "Sql.Sql( /* remote */ )";
  }

  /////////////////////////////
  // The Sql.Sql API
  /////////////////////////////

  mixed query(mixed ... args) {
    return remote_call("query",@args);
  }

  mixed big_query(mixed ... args) {
    mixed result = remote_call("query",@args);
    if(result && sizeof(result))
      return Sql.sql_result(result);
    return 0;
  }

  mixed blobupdate(mixed ... args) {
    return remote_call("blobupdate",@args);
  }

  mixed error(mixed ... args) {
    return remote_call("error",@args);
  }

  mixed select_db(mixed ... args) {
    return remote_call("select_db",@args);
  }

  mixed quote(mixed ... args) {
    return remote_call("quote",@args);
  }

  mixed encode_time(mixed ... args) {
    return remote_call("encode_time",@args);
  }

  mixed decode_time(mixed ... args) {
    return remote_call("decode_time",@args);
  }

  mixed encode_date(mixed ... args) {
    return remote_call("encode_date",@args);
  }

  mixed decode_date(mixed ... args) {
    return remote_call("decode_date",@args);
  }

  mixed encode_datetime(mixed ... args) {
    return remote_call("encode_datetime",@args);
  }

  mixed decode_datetime(mixed ... args) {
    return remote_call("decode_datetime",@args);
  }

  mixed compile_query(mixed ... args) {
    return remote_call("compile_query",@args);
  }
  mixed create_db(mixed ... args) {
    return remote_call("create_db",@args);
  }

  mixed drop_db(mixed ... args) {
    return remote_call("drop_db",@args);
  }

  mixed shutdown(mixed ... args) {
    return remote_call("shutdown",@args);
  }

  mixed reload(mixed ... args) {
    return remote_call("reload",@args);
  }

  mixed server_info(mixed ... args) {
    return remote_call("server_info",@args);
  }

  mixed host_info(mixed ... args) {
    return remote_call("host_info",@args);
  }

  mixed list_dbs(mixed ... args) {
    return remote_call("list_dbs",@args);
  }

  mixed list_tables(mixed ... args) {
    return remote_call("list_tables",@args);
  }

  mixed list_fields(mixed ... args) {
    return remote_call("list_fields",@args);
  }

  mixed case_convert(mixed ... args) {
    return remote_call("case_convert",@args);
  }

  mixed set_charset(mixed ... args) {
    return remote_call("set_charset",@args);
  }

  mixed get_charset(mixed ... args) {
    return remote_call("get_charset",@args);
  }


  /////////////////////////////


}


object sql(string connect_url) {
  //return Sql.Sql(connect_url);
  return sqlproxy(connect_url);
}
