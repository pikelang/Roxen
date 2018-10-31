// Necessary for stuff in testsuite.h to work...
inherit "etc/test/tests/pike_test_common.pike" : Parent;

#include <testsuite.h>

#charset utf-8

protected constant STATUS_OK = 200;
protected constant STATUS_CREATED = 201;
protected constant STATUS_NO_CONTENT = 204;
protected constant STATUS_MULTI_STATUS = 207;
protected constant STATUS_BAD_REQUEST = 400;
protected constant STATUS_FORBIDDEN = 403;
protected constant STATUS_NOT_FOUND = 404;
protected constant STATUS_METHOD_NOT_ALLOWED = 405;
protected constant STATUS_CONFLICT = 409;
protected constant STATUS_PRECONDITION_FAILED = 412;
protected constant STATUS_UNSUPPORTED_MEDIA_TYPE = 415;
protected constant STATUS_LOCKED = 423;

#ifdef DAV_DEBUG
#define DAV_WERROR(X...)	werror(X)
#else /* !DAV_DEBUG */
#define DAV_WERROR(X...)
#endif /* DAV_DEBUG */

protected string webdav_mount_point;

private string testdir;
protected string testcase_dir;
private mapping(string:string) all_locks = ([]);

// Current Base URL to run the test suite for.
// Note that the hostname is an ip-number.
private Standards.URI base_uri;

// Current http client connection.
private Protocols.HTTP.Query con;

// Common HTTP headers to send for all HTTP requests.
private mapping(string:string) base_headers;

/* Some globals to avoid having to pass this stuff around explicitly. */
protected mapping(string:string) current_locks;

protected void create(string webdav_mount_point,
                      Standards.URI base_uri,
                      mapping(string:string) base_headers,
                      string testdir)
{
  this::webdav_mount_point = webdav_mount_point;
  this::base_uri = base_uri;
  this::base_headers = base_headers;
  this::testdir = Stdio.append_path("/", testdir, "/");
}

protected array(string) filesystem_get_dir(string path);

protected int filesystem_is_dir(string path);

protected int filesystem_is_file(string path);

protected int filesystem_check_exists(string path);

protected string filesystem_read_file(string path);

protected int(0..1) filesystem_mkdir_recursive(string(8bit) path);

//! Writes a file to @[path], which is used verbatim without any normalization.
protected int(0..) filesystem_direct_write(string(8bit) path, string(8bit) data);

// protected int filesystem_recursive_rm(string path);

protected int filesystem_check_content(string path, string expected_data)
{
  string actual_data = filesystem_read_file(path);
  TEST_EQUAL(actual_data, expected_data); // Needed for the old style test code.
  return actual_data == expected_data;
}

protected int filesystem_compare_files(string first_path, string other_path)
{
  return filesystem_check_content(other_path, filesystem_read_file(first_path));
}

protected class WebDAVResponse(int status,
                               mapping(string:string) headers,
                               string data)
{
  mixed `[](mixed index) {
    if (intp(index)) {
      if (index == 0) {
        return status;
      }
      if (index == 1) {
        return headers;
      }
      if (index == 2) {
        return data;
      }
    }
    return ::`[](index);
  }

  protected string _sprintf(int c)
  {
    return sprintf("%O(%O, %O, %O)", this_program, status, headers, data);
  }
}

protected WebDAVResponse webdav_request(string method,
                                        string path,
                                        mapping(string:string)|void extra_headers,
                                        string|void data)
{
  mapping(string:string) headers = base_headers + ([]);

  if (extra_headers) {
    headers += extra_headers;
  }

  array(string) lock_paths = ({ path });

  // Convert the fake header "new-uri" into a proper "destination" header.
  string new_uri = m_delete(headers, "new-uri");
  if (new_uri) {
    if (lower_case(method) == "copy") {
      // NB: No need to lock the source for a copy operation.
      lock_paths = ({ new_uri });
    } else {
      lock_paths += ({ new_uri });
    }

    if (has_prefix(new_uri, "/")) {
      new_uri = new_uri[1..];
    }
    new_uri = map((new_uri/"/"), Protocols.HTTP.percent_encode) * "/";
    Standards.URI dest_uri = Standards.URI(new_uri, base_uri);
    dest_uri->password = dest_uri->password = "";
    headers["destination"] = (string)dest_uri;
  }

  string if_header = "";
  multiset(string) locks = (<>);
  if (current_locks) {
    foreach(lock_paths, string dir) {
      while(1) {
        string lock_token = current_locks[dir];
        if (lock_token && !locks[lock_token]) {
      	  string path = map((dir/"/"), Protocols.HTTP.percent_encode) * "/";
      	  if (has_prefix(path, "/")) {
      	    path = path[1..];
      	  }
      	  path = Standards.URI(path, base_uri)->path;
      	  if_header += sprintf("<%s>(<%s>)", path, lock_token);
          locks[lock_token] = 1;
        }
        if (dir == "/") {
          break;
        }
        dir = dirname(dir);
      }
    }
    if ((lower_case(method) == "move") ||
        (lower_case(method) == "copy") ||
        (lower_case(method) == "delete")) {
      foreach(indices(current_locks), string path) {
      	foreach(lock_paths, string dir) {
      	  string lock_token = current_locks[path];
      	  if (has_prefix(path, dir + "/") && !locks[lock_token]) {
      	    if (has_prefix(path, "/")) {
      	      path = path[1..];
      	    }
      	    path = map((path/"/"), Protocols.HTTP.percent_encode) * "/";
      	    path = Standards.URI(path, base_uri)->path;
      	    if_header += sprintf("<%s>(<%s>)", path, lock_token);
      	    locks[lock_token] = 1;
      	  }
      	}
      }
    }
    if (sizeof(if_header)) {
      headers->if = if_header;
    }
  }
  if (has_prefix(path, "/")) {
    path = path[1..];
  }

  path = map((path/"/"), Protocols.HTTP.percent_encode) * "/";
  Standards.URI url = Standards.URI(path, base_uri);
  con = Protocols.HTTP.do_method(method, url, UNDEFINED, headers, con, data);

  DAV_WERROR("Webdav: %s %O (url: %O) ==> code: %d\n",
           method, path, url, con?con->status:600);

  if (!con) {
    return WebDAVResponse(600, ([]), "" );
  }

  return WebDAVResponse(con->status, con->headers, con->data());
}

private mapping(string:string) make_lock_header(mapping(string:string) locks)
{
  string if_header = "";
  foreach(locks; string path; string lock_token) {
    if (has_prefix(path, "/")) {
      path = path[1..];
    }
    path = map((path / "/"), Protocols.HTTP.percent_encode) * "/";
    path = Standards.URI(path, base_uri)->path;
    if_header += sprintf("<%s>(<%s>)", path, lock_token);
  }
  return (["if" : if_header]);
}

private WebDAVResponse do_webdav_get(string method,
                                     string path,
                                     int expected_status_code)
{
  ASSERT_TRUE(method == "GET" || method == "HEAD");
  WebDAVResponse res =
    webdav_request(method, path);
  ASSERT_EQUAL(res->status, expected_status_code);
  return res;
}


protected WebDAVResponse webdav_get(string path, int expected_status_code)
{
  return do_webdav_get("GET", path, expected_status_code);
}

protected WebDAVResponse webdav_head(string path, int expected_status_code)
{
  return do_webdav_get("HEAD", path, expected_status_code);
}

protected WebDAVResponse webdav_put(string path,
                                    string data,
                                    int expected_status_code,
                                    mapping(string:string)|void headers)
{
  WebDAVResponse res =
    webdav_request("PUT", path, headers, data);
  ASSERT_EQUAL(res->status, expected_status_code);
  if ( (res->status >= 200) && (res->status < 300) ) {
    ASSERT_CALL_TRUE(filesystem_check_content, path, data);
  }
  return res;
}

protected WebDAVResponse webdav_lock(string path,
                                     mapping(string:string) locks,
                                     int expected_status_code)
{
  string lock_info = #"
<?xml version='1.0' encoding='utf-8'?>
<DAV:lockinfo xmlns:DAV='DAV:'>
  <DAV:locktype><DAV:write/></DAV:locktype>
  <DAV:lockscope><DAV:exclusive/></DAV:lockscope>
</DAV:lockinfo>
";
  WebDAVResponse res =
    webdav_request("LOCK", path, UNDEFINED, lock_info);
  if (res[0] == 200 && res[1]["lock-token"]) {
    locks[path] = res[1]["lock-token"];
    all_locks[path] = res[1]["lock-token"];
  }
  ASSERT_EQUAL(res->status, expected_status_code);
  return res;
}

protected void low_unlock(string path, mapping(string:string) locks)
{
  m_delete(locks, path);
  m_delete(all_locks, path);
}

protected void low_recursive_unlock(string path, mapping(string:string) locks)
{
  foreach(indices(locks), string lock_path) {
    if (has_prefix(lock_path, path)) {
      low_unlock(lock_path, locks);
    }
  }
  foreach(indices(all_locks), string lock_path) {
    if (has_prefix(lock_path, path)) {
      low_unlock(lock_path, locks);
    }
  }
}

protected void webdav_unlock_all()
{
  foreach (all_locks; string path; string lock) {
    webdav_request("UNLOCK", path, ([ "lock-token": lock ]));
  }
}

protected WebDAVResponse webdav_unlock(string path,
                                       mapping(string:string) locks,
                                       int expected_status_code)
{
  WebDAVResponse res =
    webdav_request("UNLOCK", path, ([
         "lock-token": locks[path],
       ]));
  ASSERT_EQUAL(res->status, expected_status_code);
  if ((res[0] >= 200) && (res[0] < 300)) {
    low_unlock(path, locks);
  }
  return res;
}

protected WebDAVResponse webdav_delete(string path,
                                       mapping(string:string) locks,
                                       int expected_status_code,
                                       mapping(string:string)|void headers)
{
  WebDAVResponse res =
    webdav_request("DELETE", path, headers);
  ASSERT_EQUAL(res->status, expected_status_code);
  if ((res[0] >= 200) && (res[0] < 300) && (res[0] != STATUS_MULTI_STATUS) ){
    low_recursive_unlock(path, locks);
    ASSERT_CALL_FALSE(filesystem_check_exists, path);
  }
  return res;
}

protected WebDAVResponse webdav_copy(string src_path,
                                     string dst_path,
                                     int expected_status_code)
{
  WebDAVResponse res =
    webdav_request("COPY", src_path, ([
         "new-uri": dst_path,
       ]));
  ASSERT_EQUAL(res->status, expected_status_code);
  if ( (res->status >= 200) && (res->status < 300) ) {
    if (filesystem_is_file(src_path)) {
      ASSERT_TRUE(filesystem_compare_files(src_path, dst_path));
    } else if (filesystem_is_dir(src_path)) {
      // TODO: Verify content of copied files.
    } else {
      error("Probably a bug in the test code.");

    }
  }
  return res;
}

protected WebDAVResponse webdav_move(string src_path,
                                     string dst_path,
                                     mapping(string:string) locks,
                                     int expected_status_code)
{
  bool src_equals_dst = false;
  if (case_sensitive_filesystem()) {
    src_equals_dst = Unicode.normalize(utf8_to_string(src_path), "NFC") ==
                    Unicode.normalize(utf8_to_string(dst_path), "NFC");
  } else {
    src_equals_dst = lower_case(Unicode.normalize(utf8_to_string(src_path), "NFC")) ==
                    lower_case(Unicode.normalize(utf8_to_string(dst_path), "NFC"));
  }
  string expected_content;
  bool is_regular_file = filesystem_is_file(src_path);
  if (is_regular_file) {
     expected_content = filesystem_read_file(src_path);
  }
  WebDAVResponse res =
    webdav_request("MOVE", src_path, ([
         "new-uri": dst_path,
       ]));
  if (locks) {
    low_recursive_unlock(src_path, locks);
  }
  ASSERT_EQUAL(res->status, expected_status_code);
  if ( (res->status >= 200) && (res->status < 300) && res->status != 207) {
    // If positive result
    ASSERT_CALL_TRUE(filesystem_check_exists, dst_path);
    if (is_regular_file) {
      ASSERT_CALL_TRUE(filesystem_check_content, dst_path, expected_content);
    }
    ASSERT_CALL_EQUAL(src_equals_dst, filesystem_check_exists, src_path);
  }
  return res;
}

protected WebDAVResponse webdav_mkcol(string path,
                                      int|void expected_status_code)
{
  expected_status_code = expected_status_code ? expected_status_code :
                                                STATUS_CREATED;
  WebDAVResponse res =
    webdav_request("MKCOL", path);
  ASSERT_EQUAL(res->status, expected_status_code);
  return res;
}

// So far only "DAV:response" and "DAV:href" is supported...
protected array(Parser.XML.Tree.AbstractNode) get_nodes_from_response(
  string element, string data)
{
  ASSERT_TRUE("DAV:href" == element || "DAV:response" == element);
  Parser.XML.Tree.SimpleRootNode root_node =
    Parser.XML.Tree.simple_parse_input(data);
  array(Parser.XML.Tree.AbstractNode) multistatus_nodes =
    root_node->get_elements("DAV:multistatus", true);
  TEST_TRUE(sizeof(multistatus_nodes) > 0);
  array(Parser.XML.Tree.AbstractNode) response_nodes =
    Array.flatten(multistatus_nodes->get_elements("DAV:response", true));
  if (element == "DAV:response") {
    return response_nodes;
  }
  TEST_TRUE(sizeof(response_nodes) > 0);
  array(Parser.XML.Tree.AbstractNode) href_nodes =
    Array.flatten(response_nodes->get_elements("DAV:href", true));
  TEST_TRUE(sizeof(href_nodes) > 0);
  return href_nodes;
}

// So far only "DAV:href" is supported...
protected array(string) get_values_from_response(string element, string data)
{
  ASSERT_EQUAL("DAV:href", element);
  array(Parser.XML.Tree.AbstractNode) href_nodes =
    get_nodes_from_response(element, data);
  array(string) hrefs = map(map(href_nodes->value_of_node(),
                                Protocols.HTTP.percent_decode),
                            utf8_to_string);
  return hrefs;
}

private int|WebDAVResponse do_webdav_ls(string path,
                                        array(string) expected,
                                        bool new_style,
                                        int|void expected_status_code)
{
  expected_status_code = expected_status_code ? expected_status_code :
                                                STATUS_MULTI_STATUS;
  string propfind = #"
<?xml version='1.0' encoding='utf-8'?>
<DAV:propfind xmlns:DAV='DAV:'>
  <DAV:propname/>
</DAV:propfind>
";
  WebDAVResponse res =
    webdav_request("PROPFIND", path, UNDEFINED, propfind);

  DAV_WERROR("Webdav: propfind result: %d\n%O\n", res[0], res[2]);

  if (new_style) {
    ASSERT_EQUAL(res->status, expected_status_code);
  } else {
    TEST_TRUE(res[0] >= 200 && res[0] < 300);
  }
  if (res[0] < 200 || res[0] > 300) {
    return 0;
  }
  array(string) hrefs = get_values_from_response("DAV:href", res->data);
  array(string) actual = Array.flatten(map(hrefs,
    lambda(string href) {
      // Remove leading "http://*/webdav_mount_pount/" from each string.
      string webdav_mp = webdav_mount_point;
      if (!has_suffix(webdav_mp, "/")) {
        webdav_mp += "/";
      }
      return array_sscanf(href, "%*s"+webdav_mp+"%s");
    }));
  // Remove leading "/"
  array(string) expected_ = map(expected,
    lambda(string path) { return has_prefix(path, "/") ? path[1..] : path; });
  // Remove empty strings if any.
  actual = filter(actual, lambda(string str) { return sizeof(str) > 0; });
  expected_ = filter(expected_, lambda(string str) { return sizeof(str) > 0; });
  expected_ = map(expected_, Unicode.normalize, "NFC");
  if (new_style) {
    ASSERT_EQUAL(sort(expected_), sort(actual));
    return res;
  }
  TEST_EQUAL(sort(expected_), sort(actual));
  return equal(sort(expected_), sort(actual));
}

protected WebDAVResponse webdav_ls(string path,
                                   array(string) expected,
                                   int|void expected_status_code)
{
  return [object(WebDAVResponse)]
    do_webdav_ls(path, expected, true, expected_status_code);
}

enum FSBehavior {
  FS_RAW = 0,
  FS_CASE_INSENSITIVE = 1,
  FS_UNICODE_NORMALIZING = 2,
  FS_BOTH = 3,
};

protected FSBehavior filesystem_behavior()
{
  string sysname = System.uname()->sysname;
  if (sysname == "Darwin") { // OS X
    return FS_BOTH;
  }
  if (has_value(sysname, "Win32")) { // Windows
    return FS_CASE_INSENSITIVE;
  }
  return FS_RAW;
}

protected bool case_sensitive_filesystem()
{
  return !(filesystem_behavior() & FS_CASE_INSENSITIVE);
}

protected bool non_normalizing_filesystem()
{
  return !(filesystem_behavior() & FS_UNICODE_NORMALIZING);
}

protected void prepare_testdir(string testdir)
{
  testdir = has_suffix(testdir, "/") ? testdir[..<1] : testdir;
  DAV_WERROR("Webdav: Test dir is: %O\n", testdir);

  // Consider working directly with the filesystem instead.
  // filesystem_recursive_rm(testdir);

  // webdav_mkcol may return true even it the dir already existed. Therefor
  // we always clean.
  webdav_request("DELETE", testdir); // In case it already exists...
  webdav_request("MKCOL", testdir);
  webdav_ls(testdir+"/", ({ testdir+"/" }));
}

// Clean/Create the testcase dir.
protected void before_testcase(string testcase)
{
  this::testcase_dir = Stdio.append_path(this::testdir, testcase, "/");
  prepare_testdir(this::testcase_dir);
}

protected void after_testcase(string testcase)
{
  webdav_unlock_all(); // Usefull when running tests agains an already running server.
}



public void run()
{
  mixed e = catch {
    ASSERT_CALL(prepare_testdir, this::testdir);
    array(mixed) testcases = indices(this);
    if (getenv("TEST_CASE")) {
      testcases = ({ getenv("TEST_CASE") });
    }
    foreach (testcases, mixed testcase) {
      if (stringp(testcase) &&
          has_prefix((string) testcase, "test_") &&
          !Parent::this[testcase]) // Do not mistake functins in parent class for testcases.
      {
        mixed e2 = catch {
          ASSERT_CALL(before_testcase, testcase);
          // Only run testcase if before() executed successfully.
          DAV_WERROR("Webdav: Running testcase: %O\n", testcase);
          TEST_CALL(this[testcase]);
          ASSERT_CALL(after_testcase, testcase);
        };
      }
      // Not a test case. This function for example...
    }
  };
}

protected mapping(string:string) make_filenames(string dir,
                                                string filename,
                                                string|void unicode_method,
                                                bool|void apply_string_to_utf8)
{
  ASSERT_NOT_EQUAL(filename, lower_case(filename));
  ASSERT_NOT_EQUAL(filename, upper_case(filename));
  mapping(string:string) filenames =
    (["mc" : filename,
      "lc" : lower_case(filename),
      "uc" : upper_case(filename)]);
  if (unicode_method) {
    filenames = map(filenames, Unicode.normalize, unicode_method);
  }
  if (apply_string_to_utf8) {
   filenames = map(filenames, string_to_utf8);
  }
  // NB: We do not want to encode dir in any way. Should be as given.
  return map(filenames, lambda(string filename) {
    return Stdio.append_path(dir, filename);
  });
}

protected void verify_lock_token(WebDAVResponse res)
{
  ASSERT_TRUE((res->status == STATUS_LOCKED) ||
	      (res->status == STATUS_MULTI_STATUS));
  // TODO: Parse data and verify response contains the
  // 'lock-token-submitted' precondition element and that is looks as expected.
  ASSERT_CALL_TRUE(has_value, res->data, "lock-token-submitted");
}

protected void verify_multistatus_response_when_resource_locked(
  WebDAVResponse res,
  array(string) locked_files)
{
  ASSERT_EQUAL(res->status, STATUS_MULTI_STATUS);
  foreach (locked_files, string file) {
    ASSERT_CALL_TRUE(has_value, res->data, file);
  }
  array(Parser.XML.Tree.AbstractNode) response_nodes =
    get_nodes_from_response("DAV:response", res->data);
  foreach (locked_files, string file) {
    bool href_found = false;
    foreach (response_nodes, Parser.XML.Tree.AbstractNode response_node) {
      Parser.XML.Tree.AbstractNode href_node =
        response_node->get_first_element("DAV:href", true);
      string href = utf8_to_string(Protocols.HTTP.percent_decode(
        href_node->value_of_node()));
      if (has_suffix(href, file)) {
        href_found = true;
        Parser.XML.Tree.AbstractNode status_node =
          response_node->get_first_element("DAV:status", true);
        string status = status_node->value_of_node();
        ASSERT_TRUE(has_suffix, status, STATUS_LOCKED);
        break;
      }
    }
    ASSERT_TRUE(href_found);
  }
  ASSERT_EQUAL(sizeof(locked_files), sizeof(response_nodes));
}


public void test_basics()
{
  int webdav_put(string path, string data)
  {
    WebDAVResponse res =
      webdav_request("PUT", path, UNDEFINED, data);

    if (!((res[0] >= 200) && (res[0] < 300))) {
      return 0;
    }

    return filesystem_check_content(path, data);
  };

  int webdav_lock(string path, mapping(string:string) locks)
  {
    string lock_info = #"
  <?xml version='1.0' encoding='utf-8'?>
  <DAV:lockinfo xmlns:DAV='DAV:'>
    <DAV:locktype><DAV:write/></DAV:locktype>
    <DAV:lockscope><DAV:exclusive/></DAV:lockscope>
  </DAV:lockinfo>
  ";

    WebDAVResponse res =
      webdav_request("LOCK", path, UNDEFINED, lock_info);

    if (res[0] != 200) return 0;

    if (!res[1]["lock-token"]) return 0;

    locks[path] = res[1]["lock-token"];
    all_locks[path] = res[1]["lock-token"];
    return 1;
  };

  int webdav_unlock(string path, mapping(string:string) locks)
  {
    WebDAVResponse res =
      webdav_request("UNLOCK", path, ([
           "lock-token": locks[path],
         ]));

    if (!((res[0] >= 200) && (res[0] < 300))) return 0;

    low_unlock(path, locks);
    return 1;
  };

  int webdav_ls(string path, array(string) expected)
  {
    return [int] do_webdav_ls(path, expected, false);
  };

  int webdav_delete(string path, mapping(string:string) locks)
  {
    WebDAVResponse res =
      webdav_request("DELETE", path);

    if (!((res[0] >= 200) && (res[0] < 300))) return 0;

    low_recursive_unlock(path, locks);
    return !filesystem_check_exists(path);
  };

  int webdav_copy(string src_path, string dst_path)
  {
    WebDAVResponse res =
      webdav_request("COPY", src_path, ([
           "new-uri": dst_path,
         ]));

    if (!((res[0] >= 200) && (res[0] < 300))) return 0;

    return filesystem_compare_files(src_path, dst_path);
  };

  int webdav_move(string src_path,
                                    string dst_path,
                                    mapping(string:string) locks)
  {
    string expected_content = filesystem_read_file(src_path);

    WebDAVResponse res =
      webdav_request("MOVE", src_path, ([
           "new-uri": dst_path,
         ]));

    if (!((res[0] >= 200) && (res[0] < 300))) {
      return 0;
    }

    low_recursive_unlock(src_path, locks);

    return TEST_CALL_TRUE(filesystem_check_exists, dst_path) &&
           TEST_CALL_TRUE(filesystem_check_content, dst_path, expected_content) &&
           !TEST_CALL_FALSE(filesystem_check_exists, src_path);
  };

  int webdav_mkcol(string path)
  {
    WebDAVResponse res =
      webdav_request("MKCOL", path);

    return (res[0] >= 200) && (res[0] < 300);
  };


  string testdir = this::testcase_dir;

  mapping(string:string) locks = ([]);

  // Test trivial uploads to existing and non-existing directories.
  TEST_CALL_TRUE(webdav_put, testdir+"test_file.txt", "TEST FILE\n");
  //test_false(webdav_put, "/test_dir/test_file.txt", "TEST FILE\n");

  TEST_CALL_TRUE(webdav_ls, testdir, ({ testdir,
                                   testdir+"test_file.txt" }));

  // Test locking and upload.
  TEST_CALL_TRUE(webdav_lock, testdir+"test_file.txt", locks);
  TEST_CALL_FALSE(webdav_lock, testdir+"test_file.txt", ([]));
  TEST_CALL_FALSE(webdav_put, testdir+"test_file.txt", "TEST FILE 2\n");
  TEST_CALL_FALSE(webdav_delete, testdir+"test_file.txt", locks);
  current_locks = locks + ([]);
  TEST_CALL_TRUE(webdav_put, testdir+"test_file.txt", "TEST FILE 3\n");
  TEST_CALL_TRUE(webdav_unlock, testdir+"test_file.txt", locks);
  TEST_CALL_FALSE(webdav_put, testdir+"test_file.txt", "TEST FILE 4\n");
  current_locks = locks + ([]);
  TEST_CALL_TRUE(webdav_put, testdir+"test_file.txt", "TEST FILE 5\n");
  TEST_CALL_TRUE(webdav_lock, testdir+"test_file.txt", locks);
  TEST_CALL_FALSE(webdav_delete, testdir+"test_file.txt", locks);
  current_locks = locks + ([]);
  TEST_CALL_TRUE(webdav_delete, testdir+"test_file.txt", locks);
  TEST_CALL_FALSE(webdav_put, testdir+"test_file.txt", "TEST FILE 6\n");
  current_locks = locks + ([]);
  TEST_CALL_TRUE(webdav_put, testdir+"test_file.txt", "TEST FILE 7\n");
  TEST_CALL_TRUE(webdav_delete, testdir+"test_file.txt", locks);

  //TEST_CALL_FALSE(webdav_mkcol, "/test_dir/sub_dir");
  TEST_CALL_TRUE(webdav_mkcol, testdir+"test_dir");
  TEST_CALL_TRUE(webdav_mkcol, testdir+"test_dir/sub_dir");
  TEST_CALL_TRUE(webdav_put, testdir+"test_dir/test_file.txt", "TEST FILE\n");

  TEST_CALL_TRUE(webdav_lock, testdir+"test_dir/test_file.txt", locks);
  TEST_CALL_FALSE(webdav_move, testdir+"test_dir/test_file.txt", testdir+"test_file.txt", locks);
  TEST_CALL_TRUE(webdav_copy, testdir+"test_dir/test_file.txt", testdir+"test_file.txt");
  TEST_CALL_FALSE(webdav_copy, testdir+"test_file.txt", testdir+"test_dir/test_file.txt");
  current_locks = locks + ([]);
  TEST_CALL_TRUE(webdav_move, testdir+"test_dir/test_file.txt", testdir+"test_file_2.txt", locks);
  // NB: /test_dir/test_file.txt lock invalidated by the move above.
  TEST_CALL_FALSE(webdav_copy, testdir+"test_file.txt", testdir+"test_dir/test_file.txt");
  current_locks = locks + ([]);
  TEST_CALL_TRUE(webdav_copy, testdir+"test_file.txt", testdir+"test_dir/test_file.txt");
  TEST_CALL_TRUE(webdav_lock, testdir+"test_dir/test_file.txt", locks);
  TEST_CALL_FALSE(webdav_copy, testdir+"test_file.txt", testdir+"test_dir/test_file.txt");
  current_locks = locks + ([]);
  TEST_CALL_TRUE(webdav_copy, testdir+"test_file.txt", testdir+"test_dir/test_file.txt");
  TEST_CALL_TRUE(webdav_unlock, testdir+"test_dir/test_file.txt", locks);
}


// -----------------------------------------------------------------------------
// 9.2.  PROPFIND Method
// -----------------------------------------------------------------------------

// TODO: Define and implement tests for the PROPFIND method.


// -----------------------------------------------------------------------------
// 9.2.  PROPPATCH Method
// -----------------------------------------------------------------------------

// TODO: Define and implement tests for the PROPPATCH method.


// -----------------------------------------------------------------------------
// 9.3.  MKCOL Method
// -----------------------------------------------------------------------------

// MKCOL creates a new collection resource at the location specified by
// the Request-URI.  If the Request-URI is already mapped to a resource,
// then the MKCOL MUST fail.
public void test_mkcol_dir_already_exist()
{
  string dir = Stdio.append_path(this::testcase_dir, "mydir");
  webdav_mkcol(dir, STATUS_CREATED);
  webdav_mkcol(dir, STATUS_METHOD_NOT_ALLOWED);
}

// If the server receives a MKCOL request entity type it does not support or
// understand, it MUST respond with a 415 (Unsupported Media Type) status code.
public void test_mkcol_unsupported_request_entity_type()
{
  WebDAVResponse res =
    webdav_request("MKCOL",
                   Stdio.append_path(this::testcase_dir, "foo"),
                   ([ "Content-type" : "application/json; charset=\"utf-8\"" ]),
                   Standards.JSON.encode((["foo": ({ "fizz", "buzz" })]),
                                         Standards.JSON.PIKE_CANONICAL));
  ASSERT_EQUAL(res->status, STATUS_UNSUPPORTED_MEDIA_TYPE);
}

// The parent collection of the Request-URI exists but cannot accept members.
// 403 (Forbidden) is expected.
// Eh, how to test? Test excluded for now...
// public void test_mkcol_request_uri_cannot_accept_members()
// {
// }

// 507 (Insufficient Storage) - The resource does not have sufficient space to
//record the state of the resource after the execution of this method.
// Eh, how to test? Test excluded for now...
// public void test_mkcol_not_sufficient_space()
// {
// }

// When the MKCOL operation creates a new collection
// resource, all ancestors MUST already exist, or the method MUST fail
// with a 409 (Conflict) status code.  For example, if a request to
// create collection /a/b/c/d/ is made, and /a/b/c/ does not exist, the
// request must fail.
public void test_mkcol_intermediate_collection_missing()
{
  string dir = Stdio.append_path(this::testcase_dir, "missing_col", "new_col");
  // NB: Expected status code is 409 not 405.
  webdav_mkcol(dir, STATUS_CONFLICT);
}

// When MKCOL is invoked without a request body, the newly created
// collection SHOULD have no members.
public void test_mkcol_no_message_body()
{
  string dir = Stdio.append_path(this::testcase_dir, "mydir");
  webdav_mkcol(dir, STATUS_CREATED);
  webdav_ls(dir, ({ dir }));
  ASSERT_CALL_TRUE(filesystem_is_dir, dir);
  ASSERT_CALL_EQUAL( ({ }), filesystem_get_dir, dir);
}

// A MKCOL request message may contain a message body.  The precise
// behavior of a MKCOL request when the body is present is undefined,
// but limited to creating collections, members of a collection, bodies
// of members, and properties on the collections or members.
//
// Not implemented. Skip for now...
// public void test_mkcol_message_body()
// {
// }


// -----------------------------------------------------------------------------
// 9.4.  GET, HEAD for Collections
// -----------------------------------------------------------------------------

private void do_test_get_non_existing_collection(function webdav_f /* get or head */)
{
  webdav_f(Stdio.append_path(this::testcase_dir, "non-existing-collection"),
           STATUS_NOT_FOUND);
}

public void test_get_non_existing_collection()
{
  do_test_get_non_existing_collection(webdav_get);
}

private void do_test_get_empty_collection(function webdav_f /* get or head */)
{
  WebDAVResponse res = webdav_f(this::testcase_dir, STATUS_OK);
  // TODO: Verify res->data is as expected.
}

// Get an empty collection.
public void test_get_empty_collection()
{
  do_test_get_empty_collection(webdav_get);
}

private void do_test_get_collection(function webdav_f /* get or head */)
{
  webdav_put(Stdio.append_path(this::testcase_dir, "index.html"),
             "Hello world!",
             STATUS_CREATED);
  WebDAVResponse res = webdav_get(this::testcase_dir, STATUS_OK);
  // TODO: Verify res->data is as expected.
  res = webdav_f(Stdio.append_path(this::testcase_dir, "index.html"),
                 STATUS_OK);
  // TODO: Verify res->data is as expected.
  webdav_mkcol(Stdio.append_path(this::testcase_dir, "mydir"),
               STATUS_CREATED);
  webdav_put(Stdio.append_path(this::testcase_dir, "mydir", "index.html"),
             "Hello in mydir!",
             STATUS_CREATED);
  res = webdav_f(Stdio.append_path(this::testcase_dir),
                 STATUS_OK);
  // TODO: Verify res->data is as expected.
}

// Get a collection that is not empty.
public void test_get_collection()
{
  do_test_get_collection(webdav_get);
}

public void test_head_non_existing_collection()
{
  do_test_get_non_existing_collection(webdav_head);
}

// Get an empty collection.
public void test_head_empty_collection()
{
  do_test_get_empty_collection(webdav_head);
}

// Get a collection that is not empty.
public void test_head_collection()
{
  do_test_get_collection(webdav_head);
}


// -----------------------------------------------------------------------------
// 9.6  DELETE Requirements
// -----------------------------------------------------------------------------

// A server processing a successful DELETE request must destroy locks rooted
// on the deleted resource
public void test_locks_deleted_when_resource_deleted_1()
{
  // Test on a file
  string path = Stdio.append_path(this::testcase_dir, "myfile.txt");
  webdav_put(path, "My content", STATUS_CREATED);
  mapping(string:string) locks = ([]);
  webdav_lock(path, locks, STATUS_OK);
  webdav_put(path, "New content", STATUS_LOCKED);

  current_locks = locks + ([]);
  webdav_delete(path, locks, STATUS_NO_CONTENT);

  webdav_put(path, "New content", STATUS_PRECONDITION_FAILED);
  current_locks = ([ ]);

  webdav_put(path, "New content", STATUS_CREATED);
}

public void test_locks_deleted_when_resource_deleted_2()
{
  // Test on a directory
  string dir = Stdio.append_path(this::testcase_dir, "mydir");
  webdav_mkcol(dir, STATUS_CREATED);
  mapping(string:string) locks = ([]);
  webdav_lock(dir, locks, STATUS_OK);
  string subdir = Stdio.append_path(dir, "subdir");
  webdav_mkcol(subdir, STATUS_LOCKED);

  current_locks = locks + ([]);
  webdav_delete(dir, locks, STATUS_NO_CONTENT);

  webdav_mkcol(dir, STATUS_PRECONDITION_FAILED);

  current_locks = locks + ([]);
  webdav_mkcol(dir, STATUS_CREATED);
  webdav_mkcol(subdir, STATUS_CREATED);
}

public void test_locks_deleted_when_resource_deleted_3()
{
  // Test on a file but the delete entire directory and create directory and
  // put file.
  string dir = Stdio.append_path(this::testcase_dir, "mydir");
  string file = Stdio.append_path(dir, "myfile.txt");
  webdav_mkcol(dir, STATUS_CREATED);
  webdav_put(file, "My content", STATUS_CREATED);
  mapping(string:string) locks = ([]);
  webdav_lock(file, locks, STATUS_OK);
  webdav_put(file, "New content", STATUS_LOCKED);

  current_locks = locks + ([]);
  webdav_delete(dir, locks, STATUS_NO_CONTENT);

  // NB: The PROPFIND and MKCOL don't submit the old lock token,
  //     as it is on a sub-path, and such locks should
  //     typically not exist for MKCOL...
  webdav_ls(this::testcase_dir, ({ this::testcase_dir }));
  webdav_mkcol(dir, STATUS_CREATED);

  webdav_put(file, "New content", STATUS_PRECONDITION_FAILED);
  current_locks = locks + ([]);
  webdav_put(file, "New content", STATUS_CREATED);
}

// A server processing a successful DELETE request must remove the mapping from
// the Request-URI to any resource.
// Thus, after a successful DELETE operation (and in the absence of
// other actions), a subsequent GET/HEAD/PROPFIND request to the target
// Request-URI MUST return 404 (Not Found).
public void test_delete()
{
  string dir = this::testcase_dir;
  webdav_get(dir, STATUS_OK);
  webdav_head(dir, STATUS_OK);
  webdav_ls(dir, ({ dir }));
  webdav_delete(dir, ([ ]), STATUS_NO_CONTENT);
  webdav_get(dir, STATUS_NOT_FOUND);
  webdav_head(dir, STATUS_NOT_FOUND);
  webdav_ls(dir, ({ }), STATUS_NOT_FOUND);
}

// -----------------------------------------------------------------------------
// 9.6.1.  DELETE for Collections
// -----------------------------------------------------------------------------

// The DELETE method on a collection MUST act as if a "Depth: infinity"
// header was used on it.  A client MUST NOT submit a Depth header with
// a DELETE on a collection with any value but infinity.
public void test_delete_using_invalid_depth_header()
{
  foreach (({"invalid-value", "0", "1"}), string depth) {
    WebDAVResponse res = webdav_request("DELETE",
                                        this::testcase_dir,
                                        ([ "Depth" : depth ]));
    ASSERT_EQUAL(res->status, STATUS_BAD_REQUEST);
  }
  WebDAVResponse res = webdav_request("DELETE",
                                      this::testcase_dir,
                                      ([ "Depth" : "infinity" ]));
  ASSERT_EQUAL(res->status, STATUS_NO_CONTENT);
}

// If any resource identified by a member URL cannot be deleted, then
// all of the member's ancestors MUST NOT be deleted, so as to maintain
// URL namespace consistency.
// Eh, how to test? Skip for now...
// public void test_namespace_consistency_when_delete_fails()
// {
// }

// If an error occurs deleting a member resource (a resource other than
// the resource identified in the Request-URI), then the response can be
// a 207 (Multi-Status).  Multi-Status is used here to indicate which
// internal resources could NOT be deleted, including an error code,
// which should help the client understand which resources caused the
// failure.  For example, the Multi-Status body could include a response
// with status 423 (Locked) if an internal resource was locked.
public void test_delete_fails_partly()
{
  string dir = this::testcase_dir;
  string file = Stdio.append_path(dir, "file1.txt");
  string file_locked = Stdio.append_path(dir, "file2.txt");
  webdav_put(file, "My content", STATUS_CREATED);
  webdav_put(file_locked, "My content 2", STATUS_CREATED);
  webdav_lock(file_locked, ([]), STATUS_OK);
  WebDAVResponse res = webdav_delete(dir, ([]), STATUS_MULTI_STATUS);
  verify_multistatus_response_when_resource_locked(res, ({ file_locked }));
}

// The server MAY return a 4xx status response, rather than a 207, if
// the request failed completely.
// Covered by other testcases. Skip for now...
// public void test_delete_fails_completely()
// {
// }


// -----------------------------------------------------------------------------
// 9.7.  PUT Requirements
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// 9.7.1.  PUT for Non-Collection Resources
// -----------------------------------------------------------------------------

// A PUT performed on an existing resource replaces the GET response
// entity of the resource.
public void test_put_on_existing_file()
{
  string file = Stdio.append_path(this::testcase_dir, "myfile.txt");
  webdav_put(file, "My content", STATUS_CREATED);
  WebDAVResponse res = webdav_get(file, STATUS_OK);
  ASSERT_EQUAL(res->data, "My content");
  webdav_put(file, "New content", STATUS_OK);
  res = webdav_get(file, STATUS_OK);
  ASSERT_EQUAL(res->data, "New content");
}

// A PUT that would result in the creation of a resource without an
// appropriately scoped parent collection MUST fail with a 409
// (Conflict).
public void test_put_when_parent_collection_missing()
{
  string file = Stdio.append_path(this::testcase_dir,
                                  "non_existing_collection",
                                  "myfile");
  webdav_put(file, "My content", STATUS_CONFLICT);
}

// A PUT request allows a client to indicate what media type an entity
// body has, and whether it should change if overwritten.
//
// Skip for now...
// public void test_put_indicate_media_type()
// {
// }

// -----------------------------------------------------------------------------
// 9.7.2.  PUT for Collections
// -----------------------------------------------------------------------------

// This specification does not define the behavior of the PUT method for
// existing collections.  A PUT request to an existing collection MAY be
// treated as an error (405 Method Not Allowed).
public void test_put_on_existing_collection()
{
  string dir = this::testcase_dir;
  ASSERT_CALL_TRUE(filesystem_is_dir, dir);
  webdav_put(dir, "My content", STATUS_METHOD_NOT_ALLOWED);
}


// -----------------------------------------------------------------------------
// 9.8.  COPY Method
// -----------------------------------------------------------------------------

// The COPY method creates a duplicate of the source resource identified
// by the Request-URI, in the destination resource identified by the URI
// in the Destination header. The Destination header MUST be present.
public void test_copy_with_missing_destination_header()
{
  WebDAVResponse res = webdav_request("COPY", this::testcase_dir);
  ASSERT_EQUAL(res->status, STATUS_BAD_REQUEST);
}

// -----------------------------------------------------------------------------
// 9.8.1.  COPY for Non-collection Resources
// -----------------------------------------------------------------------------

public void test_copy_file_to_new_collection()
{
  string src_dir = Stdio.append_path(this::testcase_dir, "srcdir");
  string dst_dir = Stdio.append_path(this::testcase_dir, "dstdir");
  string src_file = Stdio.append_path(src_dir, "myfile.txt");
  string dst_file = Stdio.append_path(dst_dir, "copy_of_myfile.txt");
  webdav_mkcol(src_dir, STATUS_CREATED);
  webdav_mkcol(dst_dir, STATUS_CREATED);
  webdav_put(src_file, "My content", STATUS_CREATED);
  webdav_copy(src_file, dst_file, STATUS_CREATED);
}

public void test_copy_file_to_same_collection()
{
  string src_file = Stdio.append_path(this::testcase_dir, "myfile.txt");
  string dst_file = Stdio.append_path(this::testcase_dir, "copy_of_myfile.txt");
  webdav_put(src_file, "My content", STATUS_CREATED);
  webdav_copy(src_file, dst_file, STATUS_CREATED);
}

// -----------------------------------------------------------------------------
// 9.8.2.  COPY for Properties
// -----------------------------------------------------------------------------

// After a successful COPY invocation, all dead properties on the source
// resource SHOULD be duplicated on the destination resource.  Live
// properties described in this document SHOULD be duplicated as
// identically behaving live properties at the destination resource, but
// not necessarily with the same values.  Servers SHOULD NOT convert
// live properties into dead properties on the destination resource,
// because clients may then draw incorrect conclusions about the state
// or functionality of a resource.  Note that some live properties are
// defined such that the absence of the property has a specific meaning
// (e.g., a flag with one meaning if present, and the opposite if
// absent), and in these cases, a successful COPY might result in the
// property being reported as "Not Found" in subsequent requests.

// When the destination is an unmapped URL, a COPY operation creates a
// new resource much like a PUT operation does.  Live properties that
// are related to resource creation (such as DAV:creationdate) should
// have their values set accordingly.

// Eh, how to test this? Skip for now...

// -----------------------------------------------------------------------------
// 9.8.3.  COPY for Collections
// -----------------------------------------------------------------------------

private void do_test_copy_col(string|void depth)
{
  ASSERT_TRUE(!depth || depth == "0" || depth == "infinity");
  string A = Stdio.append_path(this::testcase_dir, "A");
  array(string) directories =
    ({
      A,
      Stdio.append_path(A, "X"),
      Stdio.append_path(A, "X", "Y"),
    });
  array(string) files =
    ({
      Stdio.append_path(A, "file.txt"),
      Stdio.append_path(A, "X", "x_file.txt"),
      Stdio.append_path(A, "X", "Y", "y_file.txt"),
    });
  foreach(directories, string dir) {
    webdav_mkcol(dir, STATUS_CREATED);
  }
  foreach (files, string file) {
    webdav_put(file, "Some content", STATUS_CREATED);
  }
  string B = Stdio.append_path(this::testcase_dir, "B");
  WebDAVResponse res =
    webdav_request("COPY", A,
                   ([ "new-uri": B ]) + ( depth ? ([ "Depth" : depth ]) : ([]) )
                  );
  ASSERT_EQUAL(res->status, STATUS_CREATED);
  array(string) expected;
  if (!depth || depth == "infinity") {
    expected = map(directories + files, replace, "/A", "/B");
  } else if (depth == "0") {
    expected = ({ B });
  }
  webdav_ls(B, expected);
  // TODO: Verify content of copied files.
  webdav_ls(A, directories + files);
}

// The COPY method on a collection without a Depth header MUST act as if
// a Depth header with value "infinity" was included.
public void test_copy_col_no_depth_header()
{
  do_test_copy_col(UNDEFINED);
}

// An infinite-depth COPY instructs that the collection resource
// identified by the Request-URI is to be copied to the location
// identified by the URI in the Destination header, and all its internal
// member resources are to be copied to a location relative to it,
// recursively through all levels of the collection hierarchy.
public void test_copy_col_depth_header_infinity()
{
  do_test_copy_col("infinity");
}

// A COPY of "Depth: 0" only instructs that the collection and its
// properties, but not resources identified by its internal member URLs,
// are to be copied.
public void test_copy_col_depth_header_0()
{
  do_test_copy_col("0");
}

// Note that an infinite-depth COPY of /A/ into /A/B/ could lead to infinite
// recursion if not handled correctly.
public void test_copy_col_does_not_cause_recursion()
{
  string A = Stdio.append_path(this::testcase_dir);
  string AB = Stdio.append_path(A, "B");
  WebDAVResponse res = webdav_request("COPY", A,
                                      ([ "new-uri": AB,
                                         "Depth" : "infinity" ]));
  ASSERT_EQUAL(res->status, STATUS_FORBIDDEN);
}

// Any headers included with a COPY MUST be applied in processing every
// resource to be copied with the exception of the Destination header.
//
// Eh, how to test this? Skip for now...


// -----------------------------------------------------------------------------
// 9.8.4.  COPY and Overwriting Destination Resources
// -----------------------------------------------------------------------------

// All tests in this section are included in next section...

// -----------------------------------------------------------------------------
// 9.8.5.  Status Codes
// -----------------------------------------------------------------------------

// If a COPY request has an Overwrite header with a value of "F", and a
// resource exists at the Destination URL, the server MUST fail the
// request.
// 412 (Precondition Failed) - A precondition header check failed, e.g.,
// the Overwrite header is "F" and the destination URL is already mapped
// to a resource.
// 204 (No Content) - The source resource was successfully copied to a
// preexisting destination resource.

private void do_test_copy_dir_to_existing_dir(string method,
                                              string|void overwrite)
{
  ASSERT_TRUE(method == "COPY" || method == "MOVE");
  ASSERT_TRUE(!overwrite || overwrite == "T");
  mapping(string:string) headers = ([]);
  if (overwrite) {
    headers = ([ "Overwrite" : overwrite ]);
  }
  // Copy dir to dir
  string dir1 = Stdio.append_path(testcase_dir, "dir1");
  string file1 = Stdio.append_path(dir1, "file1.txt");
  string dir2 = Stdio.append_path(testcase_dir, "dir2");
  string file2 = Stdio.append_path(dir2, "file2.txt");
  webdav_mkcol(dir1, STATUS_CREATED);
  webdav_mkcol(dir2, STATUS_CREATED);
  webdav_put(file1, "Content 1", STATUS_CREATED);
  webdav_put(file2, "Content 2", STATUS_CREATED);
  mapping(string:string) locks = ([]);
  webdav_lock(dir2, locks, STATUS_OK);
  WebDAVResponse res = webdav_request(method, dir1,
                                      ([ "new-uri": dir2 ]) + headers);
  ASSERT_EQUAL(res->status, STATUS_LOCKED);
  verify_lock_token(res);
  current_locks = locks;
  res = webdav_request(method, dir1,
                       ([ "new-uri": dir2 ]) + headers);
  ASSERT_EQUAL(res->status, STATUS_NO_CONTENT);
  if (method == "COPY") {
    webdav_ls(testcase_dir,
              ({ testcase_dir,
                 dir1,
                 file1,
                 dir2,
                 Stdio.append_path(dir2, "file1.txt") }));
  } else { // method == "MOVE"
    webdav_ls(testcase_dir,
              ({ testcase_dir,
                 dir2,
                 Stdio.append_path(dir2, "file1.txt") }));
  }
}

private void do_test_copy_file_to_existing_file(string method,
                                                string|void overwrite)
{
  ASSERT_TRUE(method == "COPY" || method == "MOVE");
  ASSERT_TRUE(!overwrite || overwrite == "T");
  mapping(string:string) headers = ([]);
  if (overwrite) {
    headers = ([ "Overwrite" : overwrite ]);
  }
  // Copy file to file
  string file1 = Stdio.append_path(testcase_dir, "file1.txt");
  string file2 = Stdio.append_path(testcase_dir, "file2.txt");
  webdav_put(file1, "Content 1", STATUS_CREATED);
  webdav_put(file2, "Content 2", STATUS_CREATED);
  mapping(string:string) locks = ([]);
  webdav_lock(file2, locks, STATUS_OK);
  WebDAVResponse res = webdav_request(method, file1,
                                      ([ "new-uri": file2 ]) + headers);
  ASSERT_EQUAL(res->status, STATUS_LOCKED);
  verify_lock_token(res);
  current_locks = locks;
  res = webdav_request(method, file1,
                       ([ "new-uri": file2 ]) + headers);
  ASSERT_EQUAL(res->status, STATUS_NO_CONTENT);
  ASSERT_TRUE(filesystem_compare_files, file1, file2);
  ASSERT_TRUE(filesystem_check_content, file2, "Content 1");
  if (method == "COPY") {
    webdav_ls(testcase_dir,
              ({ testcase_dir,
                 file1,
                 file2 }));
  } else { // method == "MOVE"
    webdav_ls(testcase_dir,
              ({ testcase_dir,
                 file2 }));
  }
}

private void do_test_copy_file_to_existing_dir(string method,
                                               string|void overwrite)
{
  ASSERT_TRUE(method == "COPY" || method == "MOVE");
  ASSERT_TRUE(!overwrite || overwrite == "T");
  mapping(string:string) headers = ([]);
  if (overwrite) {
    headers = ([ "Overwrite" : overwrite ]);
  }
  // Copy file to dir
  string dir = Stdio.append_path(testcase_dir, "mydir");
  string file = Stdio.append_path(testcase_dir, "myfile.txt");
  webdav_mkcol(dir, STATUS_CREATED);
  ASSERT_CALL_TRUE(filesystem_is_dir, dir);
  ASSERT_CALL_FALSE(filesystem_is_file, dir);
  webdav_put(file, "My content", STATUS_CREATED);
  mapping(string:string) locks = ([]);
  webdav_lock(dir, locks, STATUS_OK);
  WebDAVResponse res = webdav_request(method, file,
                                      ([ "new-uri": dir ]) + headers);
  ASSERT_EQUAL(res->status, STATUS_LOCKED);
  verify_lock_token(res);
  current_locks = locks;
  res = webdav_request(method, file,
                       ([ "new-uri": dir ]) + headers);
  ASSERT_EQUAL(res->status, STATUS_NO_CONTENT);
  ASSERT_CALL_TRUE(filesystem_is_file, dir);
  ASSERT_CALL_FALSE(filesystem_is_dir, dir);
  ASSERT_CALL_TRUE(filesystem_check_content, dir, "My content");
  if (method == "COPY") {
    webdav_ls(testcase_dir,
      ({ testcase_dir,
         dir,
         file }));
  } else { // method == "MOVE"
    webdav_ls(testcase_dir,
      ({ testcase_dir,
         dir }));
  }
}

private void do_test_copy_dir_to_existing_file(string method,
                                               string|void overwrite)
{
  ASSERT_TRUE(method == "COPY" || method == "MOVE");
  ASSERT_TRUE(!overwrite || overwrite == "T");
  mapping(string:string) headers = ([]);
  if (overwrite) {
    headers = ([ "Overwrite" : overwrite ]);
  }
  // Copy dir to file
  string dir = Stdio.append_path(testcase_dir, "mydir");
  string file = Stdio.append_path(testcase_dir, "myfile.txt");
  webdav_mkcol(dir, STATUS_CREATED);
  webdav_put(file, "My content", STATUS_CREATED);
  ASSERT_CALL_TRUE(filesystem_is_file, file);
  ASSERT_CALL_FALSE(filesystem_is_dir, file);
  mapping(string:string) locks = ([]);
  webdav_lock(file, locks, STATUS_OK);
  WebDAVResponse res = webdav_request(method, dir,
                                      ([ "new-uri": file ]) + headers);
  ASSERT_EQUAL(res->status, STATUS_LOCKED);
  verify_lock_token(res);
  current_locks = locks + ([]);
  res = webdav_request(method, dir,
                       ([ "new-uri": file ]) + headers);
  ASSERT_EQUAL(res->status, STATUS_NO_CONTENT);
  ASSERT_CALL_TRUE(filesystem_is_dir, file);
  ASSERT_CALL_FALSE(filesystem_is_file, file);
  if (method == "COPY") {
    webdav_ls(testcase_dir,
              ({ testcase_dir,
                 dir,
                 file }));
  } else { // method = "MOVE"
    webdav_ls(testcase_dir,
              ({ testcase_dir,
                 file }));
  }
}

// Without overwrite header.
public void test_copy_file_to_existing_file_1()
{
  do_test_copy_file_to_existing_file("COPY", UNDEFINED);
}

// Without overwrite header.
public void test_copy_file_to_existing_dir_1()
{
  do_test_copy_file_to_existing_dir("COPY", UNDEFINED);
}

// Without overwrite header.
public void test_copy_dir_to_existing_file_1()
{
  do_test_copy_dir_to_existing_file("COPY", UNDEFINED);
}

// Without overwrite header.
public void test_copy_dir_to_existing_dir_1()
{
  do_test_copy_dir_to_existing_dir("COPY", UNDEFINED);
}

// With overwrite header T.
public void test_copy_file_to_existing_file_2()
{
  do_test_copy_file_to_existing_file("COPY", "T");
}

// With overwrite header T.
public void test_copy_file_to_existing_dir_2()
{
  do_test_copy_file_to_existing_dir("COPY", "T");
}

// With overwrite header T.
public void test_copy_dir_to_existing_file_2()
{
  do_test_copy_dir_to_existing_file("COPY", "T");
}

// With overwrite header T.
public void test_copy_dir_to_existing_dir_2()
{
  do_test_copy_dir_to_existing_dir("COPY", "T");
}

private void do_test_copy_dest_exist_overwrite_header_F(string method)
{
  ASSERT_TRUE(method == "COPY" || method == "MOVE");
  string dir1 = Stdio.append_path(this::testcase_dir, "mydir");
  string dir2 = Stdio.append_path(this::testcase_dir, "my_other_dir");
  string file1 = Stdio.append_path(this::testcase_dir, "myfile.txt");
  string file2 = Stdio.append_path(this::testcase_dir, "my_other_file.txt");
  webdav_mkcol(dir1, STATUS_CREATED);
  webdav_mkcol(dir2, STATUS_CREATED);
  webdav_put(file1, "Content 1", STATUS_CREATED);
  webdav_put(file2, "Content 2", STATUS_CREATED);
  foreach (
    ({ ({ dir1,  dir2  }),
       ({ dir1,  file1 }),
       ({ file1, file2 }),
       ({ file1, dir1  }) }), array(string) src_and_dst ) {
    string src = src_and_dst[0];
    string dst = src_and_dst[1];
    WebDAVResponse res = webdav_request(method, src,
                                        ([ "new-uri": dst, "Overwrite": "F" ]));
    ASSERT_EQUAL(res->status, STATUS_PRECONDITION_FAILED);
  }
  webdav_ls(this::testcase_dir,
    ({ this::testcase_dir, dir1, dir2, file1, file2 }));
}

public void test_copy_dest_exist_overwrite_header_F()
{
  do_test_copy_dest_exist_overwrite_header_F("COPY");
}

private void do_test_copy_col_fails_due_to_locked_file(string method)
{
  ASSERT_TRUE(method == "COPY" || method == "MOVE");
  string src_dir = Stdio.append_path(this::testcase_dir, "A");
  string dst_dir = Stdio.append_path(this::testcase_dir, "B");
  string src_file1 = Stdio.append_path(src_dir, "file1.txt");
  string src_file2 = Stdio.append_path(src_dir, "file2.txt");
  string dst_file1 = Stdio.append_path(dst_dir, "file1.txt");
  string dst_file2 = Stdio.append_path(dst_dir, "file2.txt");
  webdav_mkcol(src_dir, STATUS_CREATED);
  webdav_mkcol(dst_dir, STATUS_CREATED);
  webdav_put(src_file1, "file1 in dir1", STATUS_CREATED);
  webdav_put(src_file2, "file2 in dir1", STATUS_CREATED);
  webdav_put(dst_file1, "file1 in dir2", STATUS_CREATED);
  webdav_put(dst_file2, "file2 in dir2", STATUS_CREATED);
  webdav_lock(dst_file2, ([]), STATUS_OK);
  WebDAVResponse res;
  if (method == "COPY") {
    res = webdav_copy(src_dir, dst_dir, STATUS_MULTI_STATUS);
  } else {
    res = webdav_move(src_dir, dst_dir, ([]), STATUS_MULTI_STATUS);
  }
  verify_multistatus_response_when_resource_locked(res, ({ dst_file2 }));
  // The destination directory has been wiped, except for dst_file2,
  // which was locked.
  // No actual delete, copy or move was performed.
  webdav_ls(this::testcase_dir,
        ({ this::testcase_dir,
           src_dir,
           src_file1,
           src_file2,
           dst_dir,
	   dst_file1,
           dst_file2 }));
  ASSERT_CALL_TRUE(filesystem_check_content, dst_file2, "file2 in dir2");
}

private void do_test_copy_col_fails_due_to_locked_non_existing_file(string method)
{
  ASSERT_TRUE(method == "COPY" || method == "MOVE");
  string src_dir = Stdio.append_path(this::testcase_dir, "A");
  string dst_dir = Stdio.append_path(this::testcase_dir, "B");
  string src_file1 = Stdio.append_path(src_dir, "file1.txt");
  string src_file2 = Stdio.append_path(src_dir, "file2.txt");
  string dst_file1 = Stdio.append_path(dst_dir, "file1.txt");
  string dst_file2 = Stdio.append_path(dst_dir, "file2.txt");
  webdav_mkcol(src_dir, STATUS_CREATED);
  webdav_put(src_file1, "file1 in dir1", STATUS_CREATED);
  webdav_put(src_file2, "file2 in dir1", STATUS_CREATED);
  webdav_lock(dst_file2, ([]), STATUS_OK);
  WebDAVResponse res;
  if (method == "COPY") {
    res = webdav_copy(src_dir, dst_dir, STATUS_MULTI_STATUS);
  } else {
    res = webdav_move(src_dir, dst_dir, ([]), STATUS_MULTI_STATUS);
  }
  verify_multistatus_response_when_resource_locked(res, ({ dst_file2 }));
  // dst_file1 should have been overwritten by src_file1.
  // the path dst_file2 was locked so it should not have been copied.
  // src_file2 with same as dst_file2 should not have been moved if this was a
  // move.
  if (method == "COPY") {
    webdav_ls(this::testcase_dir,
              ({ this::testcase_dir,
                 src_dir,
                 src_file1,
                 src_file2,
                 dst_dir,
                 dst_file1 }));
    ASSERT_CALL_TRUE(filesystem_check_content, dst_file1, "file1 in dir1");
  } else { // method == "MOVE"
      webdav_ls(this::testcase_dir,
                ({ this::testcase_dir,
                   src_dir,
		   src_file1,
                   src_file2 }));
  }
  ASSERT_CALL_FALSE(filesystem_check_exists, dst_file2);
}

public void test_copy_col_fails_due_to_locked_file()
{
  do_test_copy_col_fails_due_to_locked_file("COPY");
}

public void test_copy_col_fails_due_to_locked_non_existing_file()
{
  do_test_copy_col_fails_due_to_locked_non_existing_file("COPY");
}

// After detecting an error, the COPY operation SHOULD try
// to finish as much of the original copy operation as possible.
// If an error in executing the COPY method occurs with a resource other
// than the resource identified in the Request-URI, then the response
// MUST be a 207 (Multi-Status), and the URL of the resource causing the
// failure MUST appear with the specific error.

private void do_test_copy_destination_equals_src(string method,
                                                 string|void overwrite)
{
  ASSERT_TRUE(method = "COPY" || method == "MOVE");
  ASSERT_TRUE(!overwrite || overwrite == "F" || overwrite == "T");
  mapping(string:string) headers = ([]);
  if (overwrite) {
    headers = ([ "Overwrite" : overwrite ]);
  }

  // Copy dir to dir
  string dir = this::testcase_dir;
  WebDAVResponse res =
    webdav_request("COPY", dir, ([ "new-uri": dir ]) + headers);
  ASSERT_EQUAL(res->status, STATUS_FORBIDDEN);

  // Copy file to file
  string file = Stdio.append_path(dir, "myfile.txt");
  webdav_put(file, "My content", STATUS_CREATED);
  res = webdav_request("COPY", file, ([ "new-uri": file ]) + headers);
  ASSERT_EQUAL(res->status, STATUS_FORBIDDEN);

  webdav_ls(dir, ({ dir, file }));
}

// 403 (Forbidden) - The operation is forbidden.  A special case for
// COPY could be that the source and destination resources are the same
// resource.
public void test_copy_destination_equals_src_no_overwrite_header()
{
  do_test_copy_destination_equals_src("COPY", UNDEFINED);
}

public void test_copy_destination_equals_src_overwrite_header_T()
{
  do_test_copy_destination_equals_src("COPY", "T");
}

public void test_copy_destination_equals_src_overwrite_header_F()
{
  do_test_copy_destination_equals_src("COPY", "F");
}

// 409 (Conflict) - A resource cannot be created at the destination
// until one or more intermediate collections have been created.  The
// server MUST NOT create those intermediate collections automatically.
public void test_copy_file_intermediate_destination_collection_missing()
{
  string file = Stdio.append_path(this::testcase_dir, "myfile.txt");
  webdav_put(file, "My content", STATUS_CREATED);
  webdav_copy(file,
              Stdio.append_path(this::testcase_dir,
                                "non-existing-dir",
                                "copy-of-myfile.txt"),
              STATUS_CONFLICT);
}

// 423 (Locked) - The destination resource, or resource within the
// destination collection, was locked.  This response SHOULD contain the
// 'lock-token-submitted' precondition element.
//
// This is already covered more or less by testcases
// Included in test_copy_dest_exist_overwrite_header_T() and
// test_copy_dest_exist_no_overwrite_header().
//
// public void test_copy_destination_locked()
// {
// }

// 502 (Bad Gateway) - This may occur when the destination is on another
// server, repository, or URL namespace.  Either the source namespace
// does not support copying to the destination namespace, or the
// destination namespace refuses to accept the resource.  The client may
// wish to try GET/PUT and PROPFIND/PROPPATCH instead.
//
// Skip testing this for now...

// 507 (Insufficient Storage) - The destination resource does not have
// sufficient space to record the state of the resource after the
// execution of this method.
//
// Skip testing this for now...


// -----------------------------------------------------------------------------
// 9.9.  MOVE Method
// -----------------------------------------------------------------------------

// The Destination header MUST be present on all MOVE methods
public void test_move_with_missing_destination_header()
{
  WebDAVResponse res = webdav_request("MOVE", this::testcase_dir);
  ASSERT_EQUAL(res->status, STATUS_BAD_REQUEST);
}

// -----------------------------------------------------------------------------
// 9.9.1.  MOVE for Properties
// -----------------------------------------------------------------------------

// Live properties described in this document SHOULD be moved along with
// the resource, such that the resource has identically behaving live
// properties at the destination resource, but not necessarily with the
// same values.  Note that some live properties are defined such that
// the absence of the property has a specific meaning (e.g., a flag with
// one meaning if present, and the opposite if absent), and in these
// cases, a successful MOVE might result in the property being reported
// as "Not Found" in subsequent requests.  If the live properties will
// not work the same way at the destination, the server MAY fail the
// request.

// MOVE is frequently used by clients to rename a file without changing
// its parent collection, so it's not appropriate to reset all live
// properties that are set at resource creation.  For example, the DAV:
// creationdate property value SHOULD remain the same after a MOVE.

// Dead properties MUST be moved along with the resource.

// Eh, how to test this? Skip for now...

// -----------------------------------------------------------------------------
// 9.9.2.  MOVE for Collections
// -----------------------------------------------------------------------------

private void do_test_move_col(string|void depth)
{
  ASSERT_TRUE(!depth || depth == "infinity");
  string A = Stdio.append_path(this::testcase_dir, "A");
  array(string) directories =
    ({
      A,
      Stdio.append_path(A, "X"),
      Stdio.append_path(A, "X", "Y"),
    });
  array(string) files =
    ({
      Stdio.append_path(A, "file.txt"),
      Stdio.append_path(A, "X", "x_file.txt"),
      Stdio.append_path(A, "X", "Y", "y_file.txt"),
    });
  foreach(directories, string dir) {
    webdav_mkcol(dir, STATUS_CREATED);
  }
  foreach (files, string file) {
    webdav_put(file, "Some content", STATUS_CREATED);
  }
  string B = Stdio.append_path(this::testcase_dir, "B");
  WebDAVResponse res = webdav_request("MOVE", A,
                                      ([ "new-uri": B ]) +
                                      ( depth ? ([ "Depth" : depth ]) : ([]) ));
  ASSERT_EQUAL(res->status, STATUS_CREATED);
  array(string) expected = map(directories + files, replace, "/A", "/B");
  ASSERT_CALL_TRUE(webdav_ls, B, expected);
  // TODO: Verify content of copied files.
  ASSERT_CALL_FALSE(webdav_ls, A, ({ }), STATUS_NOT_FOUND);
}


// The MOVE method on a collection MUST act as if a "Depth: infinity"
// header was used on it.
public void test_move_col_depth_header()
{
  do_test_move_col(UNDEFINED);
}

public void test_move_col_depth_header_infinity()
{
  do_test_move_col("infinity");
}

// A client MUST NOT submit a Depth header on a
// MOVE on a collection with any value but "infinity".
//
// However, if the client does so the behaviour is not defined... or is it?
// public void test_move_col_invalid_depth_header()
// {
// }

// Any headers included with MOVE MUST be applied in processing every
// resource to be moved with the exception of the Destination header.
//
// Eh, how to test this? Skip for now...

// -----------------------------------------------------------------------------
// 9.9.3.  MOVE and the Overwrite Header
// -----------------------------------------------------------------------------

// All tests in this section are included in next section...

// -----------------------------------------------------------------------------
// 9.9.3.  MOVE and the Overwrite Header
// -----------------------------------------------------------------------------

// All tests in this section are included in next section...

// -----------------------------------------------------------------------------
// 9.9.4.  Status Codes
// -----------------------------------------------------------------------------

// 201 (Created) - The source resource was successfully moved, and a new
// URL mapping was created at the destination.
//
// Covered by so many other tests...
// public void test_move()
// {
// }

// If a resource exists at the destination and the Overwrite header is
// "T", then prior to performing the move, the server MUST perform a
// DELETE with "Depth: infinity" on the destination resource.  If the
// Overwrite header is set to "F", then the operation will fail.
//
// 412 (Precondition Failed) - A condition header failed.  Specific to
// MOVE, this could mean that the Overwrite header is "F" and the
// destination URL is already mapped to a resource.
//
// 204 (No Content) - The source resource was successfully moved to a
// URL that was already mapped.

// Without overwrite header.
public void test_move_dir_to_existing_dir_1()
{
  do_test_copy_dir_to_existing_dir("MOVE", UNDEFINED);
}

// Without overwrite header.
public void test_move_dir_to_existing_file_1()
{
  do_test_copy_dir_to_existing_file( "MOVE", UNDEFINED);
}

// Without overwrite header.
public void test_move_file_to_existing_file_1()
{
  do_test_copy_file_to_existing_file("MOVE", UNDEFINED);
}

// Without overwrite header.
public void test_move_file_to_existing_dir_1()
{
  do_test_copy_file_to_existing_dir("MOVE", UNDEFINED);
}

// With overwrite header T.
public void test_move_dir_to_existing_dir_2()
{
  do_test_copy_dir_to_existing_dir("MOVE", "T");
}

// With overwrite header T.
public void test_move_dir_to_existing_file_2()
{
  do_test_copy_dir_to_existing_file("MOVE", "T");
}

// With overwrite header T.
public void test_move_file_to_existing_file_2()
{
  do_test_copy_file_to_existing_file("MOVE", "T");
}

// With overwrite header T.
public void test_move_file_to_existing_dir_2()
{
  do_test_copy_file_to_existing_dir( "MOVE", "T");
}

public void test_move_dest_exist_overwrite_header_F()
{
  do_test_copy_dest_exist_overwrite_header_F("MOVE");
}

// 207 (Multi-Status) - Multiple resources were to be affected by the
// MOVE, but errors on some of them prevented the operation from taking
// place.  Specific error messages, together with the most appropriate
// of the source and destination URLs, appear in the body of the multi-
// status response.  For example, if a source resource was locked and
// could not be moved, then the source resource URL appears with the 423
// (Locked) status.
public void test_move_col_fails_due_to_locked_file()
{
  do_test_copy_col_fails_due_to_locked_file("MOVE");
}

public void test_move_col_fails_due_to_locked_non_existing_file()
{
  do_test_copy_col_fails_due_to_locked_non_existing_file("MOVE");
}

// 403 (Forbidden) - Among many possible reasons for forbidding a MOVE
// operation, this status code is recommended for use when the source
// and destination resources are the same.
public void test_move_destination_equals_src_no_overwrite_header()
{
  do_test_copy_destination_equals_src("MOVE", UNDEFINED);
}

public void test_move_destination_equals_src_overwrite_header_T()
{
  do_test_copy_destination_equals_src("MOVE", "T");
}

public void test_move_destination_equals_src_overwrite_header_F()
{
  do_test_copy_destination_equals_src("MOVE", "F");
}


// 409 (Conflict) - A resource cannot be created at the destination
// until one or more intermediate collections have been created.  The
// server MUST NOT create those intermediate collections automatically.
// Or, the server was unable to preserve the behavior of the live
// properties and still move the resource to the destination (see
// 'preserved-live-properties' postcondition).
public void test_move_file_intermediate_destination_collection_missing()
{
  string file = Stdio.append_path(this::testcase_dir, "myfile.txt");
  webdav_put(file, "My content", STATUS_CREATED);
  webdav_move(file,
              Stdio.append_path(this::testcase_dir,
                                "non-existing-dir",
                                "copy-of-myfile.txt"),
              ([]),
              STATUS_CONFLICT);
}

// 423 (Locked) - The source or the destination resource, the source or
// destination resource parent, or some resource within the source or
// destination collection, was locked.  This response SHOULD contain the
// 'lock-token-submitted' precondition element.
public void test_move_src_locked()
{
  string src_parent = Stdio.append_path(this::testcase_dir, "parent");
  string src = Stdio.append_path(src_parent, "src");
  string child = Stdio.append_path(src, "child");
  string dst = Stdio.append_path(this::testcase_dir, "dst");
  webdav_mkcol(src_parent, STATUS_CREATED);
  webdav_mkcol(src, STATUS_CREATED);
  webdav_put(child, "Child content", STATUS_CREATED);
  foreach (({src_parent, src, child}), string resource_to_lock) {
    mapping(string:string) locks = ([]);
    webdav_lock(resource_to_lock, locks, STATUS_OK);
    WebDAVResponse res = webdav_move(src, dst, ([]),
				     (resource_to_lock == child) ?
				     STATUS_MULTI_STATUS: STATUS_LOCKED);
    verify_lock_token(res);
    webdav_unlock(resource_to_lock, locks, STATUS_NO_CONTENT);
  }
  WebDAVResponse res = webdav_move(src, dst, ([]), STATUS_CREATED);
  webdav_ls(this::testcase_dir,
            ({ this::testcase_dir,
               src_parent,
               dst,
               Stdio.append_path(dst, "child") }));
}

// 423 (Locked) - The source or the destination resource, the source or
// destination resource parent, or some resource within the source or
// destination collection, was locked.  This response SHOULD contain the
// 'lock-token-submitted' precondition element.
public void test_move_destination_locked()
{
  string child_name = "child";
  string src = Stdio.append_path(this::testcase_dir, "src");
  string src_child = Stdio.append_path(src, child_name);
  string dst_parent = Stdio.append_path(this::testcase_dir, "dst_parent");
  string dst = Stdio.append_path(dst_parent, "dst");
  string dst_child = Stdio.append_path(dst, child_name); // Must be same name as src child!
  foreach (({src, dst_parent, dst}), string col) {
    webdav_mkcol(col, STATUS_CREATED);
  }
  webdav_put(src_child, "src child content", STATUS_CREATED);
  webdav_put(dst_child, "dst child content", STATUS_CREATED);
  foreach (({dst_parent, dst, dst_child}), string resource_to_lock) {
    mapping(string:string) locks = ([]);
    webdav_lock(resource_to_lock, locks, STATUS_OK);
    WebDAVResponse res = webdav_move(src, dst, ([]),
				     (resource_to_lock == dst_child) ?
				     STATUS_MULTI_STATUS:STATUS_LOCKED);
    verify_lock_token(res);
    webdav_unlock(resource_to_lock, locks, STATUS_NO_CONTENT);
  }
  WebDAVResponse res = webdav_move(src, dst, ([]), STATUS_NO_CONTENT);
  filesystem_check_content(dst_child, "src child content");
  webdav_ls(this::testcase_dir,
            ({ this::testcase_dir,
           dst_parent,
               dst,
               dst_child }));
}

// 502 (Bad Gateway) - This may occur when the destination is on another
// server and the destination server refuses to accept the resource.
// This could also occur when the destination is on another sub-section
// of the same server namespace.
//
// Skip testing this for now...


// -----------------------------------------------------------------------------
// 9.10.  LOCK Method
// -----------------------------------------------------------------------------

// TODO: Define and implement tests for the LOCK method.


/*
 * More TODOs and stuff to think about.:

  All tests should test on both directories and files (e.g. move, and copy, and ls)

  Make sure that copy/move of non empty directories that contain both
  directories and files (subdirectories should also contain stuff), are being
  tested.

  Test list directory with multiple directories and files in it.

  Make move and copy tests share code where possible.

  When testing copy/move, return code 207 (multi-status), due to locked
  resource, verify that the locked resource URL appears with the 423 status in
  the response.

  For move, test the following:
    The 424 (Failed Dependency) status code SHOULD NOT be returned in the
    207 (Multi-Status) response from a MOVE method.  These errors can be
    safely omitted because the client will know that the progeny of a
    resource could not be moved when the client receives an error for the
    parent.  Additionally, 201 (Created)/204 (No Content) responses
    SHOULD NOT be returned as values in 207 (Multi-Status) responses from
    a MOVE.  These responses can be safely omitted because they are the
    default success codes.

  For copy/move test where destination exists and is a directory,
    Test both with an empty destination directory and with a non empty
    destination directory. (We already test at least one of the cases.)
*/


// -----------------------------------------------------------------------------
// Special testcases combining different encodings and mixed/lower/upper case
// letters.
// -----------------------------------------------------------------------------

// NB: Some character sets (eg kanji, hangul, etc) only have
//     a single "case", and make_filenames() requires multiple
//     cases. Work around this issue by prefixing with some
//     multi-case ascii characters.
protected constant FILENAMES =
  ({
    "Ascii-myFile", // To compare with
#ifndef WEBDAV_TEST_ASCII_ONLY
    "Latin1-åÅäÄöÖæÆüÜñÑ@", // Some Latin 1 chars
    "Latin2-ąĄŁůŮăĂçÇ", // Some Latin 2 chars
    "Cyrillic-фщъЂЃЄЉЖ", // Some Cyrillic chars
    "Greek-ώψφλξβΩΠΞΔ€", // Some Greek chars
    "Kanji-日本語ひらがなカタカナ", // Some Kanji, hiragana and katakana.
    "Specials-)(<*~^[", // Various special characters.
#endif
  });

// Create directory and file using one encoding and mixed, lower or upper case.
// Then do ls for all combinations of (same encoding, other encoding) x
// (mixed case, lower case, upper case).
public void test_x_ls()
{
  int count = 0;
  bool normalizing = !non_normalizing_filesystem();
  bool casesensitive = case_sensitive_filesystem();
  int w = sizeof("" + (sizeof(FILENAMES)*2*3) );
  foreach (FILENAMES, string str) {
    // TODO: Skip the following 2 loops and just pick an encoding and a case for the src, or?
    foreach (({"NFC", "NFD"}), string unicode_method_create) {
      foreach (({"mc", "lc", "uc"}), string case_create) {
        foreach (({"NFC", "NFD"}), string unicode_method_ls) {
          foreach (({"mc", "lc", "uc"}), string case_ls) {
            string filename = sprintf("%0"+w+"d_%s", count++, str);
            string new_dir =
              make_filenames(this::testcase_dir, filename,
                             unicode_method_create, true)[case_create];
            string new_file =
              make_filenames("", filename, unicode_method_create,
                             true)[case_create];
            string dir_ls = make_filenames(this::testcase_dir, filename,
                                           unicode_method_ls, true)[case_ls];
            string file_ls = make_filenames("", filename, unicode_method_ls,
                                            true)[case_ls];
            mapping(string:string) exp_dir =
              make_filenames(this::testcase_dir, filename, "NFC", false);
            mapping(string:string) exp_file = make_filenames("", filename,
                                                             "NFC", false);
            ASSERT_EQUAL(filesystem_mkdir_recursive(new_dir), 1);
            string exp_path = exp_dir[case_ls] + "/" + exp_file[case_ls];

	    // NB: In normalizing (which implies !casesensitive) mode
	    //     the paths should always match.
	    int exp_match = 1;
	    if (!normalizing) {
	      // NB: In casesensitive mode the paths only match if they
	      //     are coded identically.
	      exp_match = (string_to_utf8(exp_path) ==
			   Stdio.append_path(new_dir, new_file));
	      if (!exp_match && !casesensitive) {
		// NB: To handle cases where the NFC and NFD normalizations
		//     are equal (eg ascii or kanji) it is not sufficient
		//     to just look at whether unicode_method_create is
		//     "NFC" or "NFD".
		exp_match = (new_dir ==
			     make_filenames(this::testcase_dir, filename,
					    "NFC", true)[case_create]);
	      }
	    }
#if 0
	    werror("normalizing: %d\n"
		   "casesensitive: %d\n"
		   "str: %O\n"
		   "umc: %O\n"
		   "cc: %O\n"
		   "uml: %O\n"
		   "cls: %O\n"
		   "fn: %O\n"
		   "nd: %O\n"
		   "nf: %O\n"
		   "dls: %O\n"
		   "fls: %O\n"
		   "ed: %O\n"
		   "ef: %O\n"
		   "ep: %O\n"
		   "em: %O\n"
		   "--------\n"
		   "utf8(ep):   %O\n"
		   "ap(nd, nf): %O\n",
		   normalizing, casesensitive,
		   str, unicode_method_create, case_create,
		   unicode_method_ls, case_ls,
		   filename,
		   new_dir, new_file,
		   dir_ls, file_ls,
		   exp_dir, exp_file, exp_path, exp_match,
		   string_to_utf8(exp_path),
		   Stdio.append_path(new_dir, new_file));
#endif

            if (exp_match) {
              webdav_ls(dir_ls, ({ exp_dir[case_ls] }) );
	    } else {
              webdav_ls(dir_ls, ({}), STATUS_NOT_FOUND);
            }
            string testdata = "FILE " + count;
            ASSERT_EQUAL(filesystem_direct_write(new_dir + "/" + new_file,
                                                 testdata),
                         sizeof(testdata));
            if (exp_match) {
              // In this case we should always get a successful listing.
              webdav_ls(dir_ls,
                        ({ exp_dir[case_ls],
                           exp_dir[case_ls] + "/" + exp_file[case_create] }) );

              // When listing a file directly, it will have equivalent case
              // in the returned list.
              webdav_ls(dir_ls + "/" + file_ls,
                        ({ exp_dir[case_ls] + "/" + exp_file[case_ls] }) );
            } else {
	      webdav_ls(dir_ls, ({}), STATUS_NOT_FOUND);
	      webdav_ls(dir_ls + "/" + file_ls, ({ }), STATUS_NOT_FOUND);
            }
          }
        }
      }
    }
  }
}

// Test create directory and file containing special chars.
public void test_x_special_chars()
{
  string testdir = this::testcase_dir;
  // If you want to try single chars, just ad them as new strings to the array
  // below.
  array(string) FILENAMES = ({
#ifdef __NT__
    /* NB: *, ? and | are apparently invalid characters in NTFS. */
    /* NB: Space at the end of path segments is *sometimes* stripped on NTFS. */
    " _ [](){}+-#%&=$~",
#else /* !__NT__ */
    " _ [](){}+-*#%&=?|$~ ",
#endif /* __NT__ */
    /* NB: Test mismatching parenthesis. */
    "])}",
    "[({",
  });
  foreach (FILENAMES, string file) {
    mixed e = catch {
      // This test should only include chars that are the same before and after
      // encoding
      ASSERT_EQUAL(file, Unicode.normalize(file, "NFC"));
      ASSERT_EQUAL(file, Unicode.normalize(file, "NFD"));
      // Test starts here...
      string dir_path = Stdio.append_path("/", testdir, file);
      string file_path = dir_path + "/" + file + ".txt";
      DAV_WERROR("Webdav special chars test: Creating dir: %s.\n", dir_path);
      webdav_mkcol(dir_path, STATUS_CREATED);
      webdav_ls(dir_path, ({ dir_path }) );
      webdav_put(file_path, "FILE\n", STATUS_CREATED);
      webdav_ls(dir_path, ({ dir_path, file_path }) );
    };
  }
}

public void test_x_put()
{
  int count = 0;
  bool caseSensitive = case_sensitive_filesystem();
  int w = sizeof("" + (sizeof(FILENAMES)*2*3) );
  foreach (FILENAMES, string str) {
    // TODO: Skip the following 2 loops and just pick an encoding and a case for the src, or?
    foreach (({"NFC", "NFD"}), string unicode_method_put1) {
      foreach (({"mc", "lc", "uc"}), string case_put1) {
        foreach (({"NFC", "NFD"}), string unicode_method_put2) {
          foreach (({"mc", "lc", "uc"}), string case_put2) {
            string filename = sprintf("%0"+w+"d_%s", count++, str);
            string dir = make_filenames(this::testcase_dir, filename,
                                        unicode_method_put1, true)[case_put1];
            string file1 = make_filenames(dir, filename,
                                          unicode_method_put1, true)[case_put1];
            string file2 = make_filenames(dir, filename,
                                          unicode_method_put2, true)[case_put2];
            string exp_dir = make_filenames(this::testcase_dir, filename,
                                            "NFC", false)[case_put1];
            mapping(string:string) exp_file = make_filenames(exp_dir, filename,
                                                             "NFC", false);
            webdav_mkcol(dir, STATUS_CREATED);
            webdav_put(file1, "FILE " + count, STATUS_CREATED);
            // Try to put again, possibly with different encoding and
            // possible with different case.
            int expected_status_code = STATUS_CREATED;
            bool filenames_considered_equal;
            if (caseSensitive) {
              filenames_considered_equal =
                Unicode.normalize(utf8_to_string(file1), "NFC") ==
                Unicode.normalize(utf8_to_string(file2), "NFC");
            } else {
              filenames_considered_equal =
                lower_case(Unicode.normalize(utf8_to_string(file1), "NFC")) ==
                lower_case(Unicode.normalize(utf8_to_string(file2), "NFC"));
            }
            if (filenames_considered_equal) {
              expected_status_code = STATUS_OK;
            }
            webdav_put(file2, "FILE 2" + count, expected_status_code);
            if (case_put1 == case_put2) {
              webdav_ls(dir,
                        ({ exp_dir, exp_file[case_put1] }) );
            } else {
              webdav_ls(dir,
                        caseSensitive ?
                          ({ exp_dir,
                             exp_file[case_put1],
                             exp_file[case_put2] }) :
                          ({ exp_dir,
                              exp_file[case_put1] }) );
            }
          }
        }
      }
    }
  }
}

// Test copy where src and target is the same except for case.
public void test_x_copy_file()
{
  int count = 0;
  bool caseSensitive = case_sensitive_filesystem();
  int w = sizeof("" + (sizeof(FILENAMES)*2*3) );
  foreach (FILENAMES, string str) {
    // TODO: Skip the following 2 loops and just pick an encoding and a case for the src, or?
    foreach (({"NFC", "NFD"}), string unicode_method_src) {
      foreach (({"mc", "lc", "uc"}), string case_src) {
        foreach (({"NFC", "NFD"}), string unicode_method_target) {
          foreach (({"mc", "lc", "uc"}), string case_target) {
            string filename = sprintf("%0"+w+"d_%s", count++, str);
            string src_file =
              make_filenames(this::testcase_dir, filename, unicode_method_src,
                             true)[case_src];
            string target_file =
              make_filenames(this::testcase_dir, filename,
                             unicode_method_target, true)[case_target];
            webdav_put(src_file, "FILE " + count, STATUS_CREATED);
            if (case_src == case_target) {
              // Src and target are equal and same case but may be different
              // encoded (will be at least once when looping...)
              webdav_copy(src_file, target_file, STATUS_FORBIDDEN);
            } else {
              // Src and target is different case (but the same otherwise).
              webdav_copy(src_file, target_file,
                          caseSensitive ? STATUS_CREATED : STATUS_FORBIDDEN);
            }
          }
        }
      }
    }
  }
}

// This testcase tests creating a directory that already exists.
public void test_x_mkcol()
{
  int count = 0;
  bool caseSensitive = case_sensitive_filesystem();
  int w = sizeof("" + (sizeof(FILENAMES)*2*3) );
  foreach (FILENAMES, string str) {
    // TODO: Skip the following 2 loops and just pick an encoding and a case for the src, or?
    foreach (({"NFC", "NFD"}), string unicode_method_dir1) {
      foreach (({"mc", "lc", "uc"}), string case_dir1) {
        foreach (({"NFC", "NFD"}), string unicode_method_dir2) {
          foreach (({"mc", "lc", "uc"}), string case_dir2) {
            string filename = sprintf("%0"+w+"d_%s", count++, str);
            string dir1 = make_filenames(this::testcase_dir, filename,
                                         unicode_method_dir1, true)[case_dir1];
            string dir2 =
              make_filenames(this::testcase_dir, filename, unicode_method_dir2,
                             true)[case_dir2];
            webdav_mkcol(dir1, STATUS_CREATED);
            if (case_dir1 == case_dir2) {
              // Src and target is equal and same case but may be different
              // encoded (will be at least once when looping...)
              webdav_mkcol(dir2, STATUS_METHOD_NOT_ALLOWED);
            } else {
              // Src and target is different case (but the same otherwise).
              webdav_mkcol(dir2,
                           caseSensitive ? STATUS_CREATED : STATUS_METHOD_NOT_ALLOWED);
            }
          }
        }
      }
    }
  }
}

// Test move where src and target is the same except for case.
public void test_x_move_file()
{
  int count = 0;
  bool caseSensitive = case_sensitive_filesystem();
  int w = sizeof("" + (sizeof(FILENAMES)*2*3) );
  foreach (FILENAMES, string str) {
    // TODO: Skip the following 2 loops and just pick an encoding and a case for the src, or?
    foreach (({"NFC", "NFD"}), string unicode_method_src) {
      foreach (({"mc", "lc", "uc"}), string case_src) {
        foreach (({"NFC", "NFD"}), string unicode_method_target) {
          foreach (({"mc", "lc", "uc"}), string case_target) {
            string filename = sprintf("%0"+w+"d_%s", count++, str);
            string src_file = make_filenames(this::testcase_dir, filename,
                                             unicode_method_src, true)[case_src];
            string target_file =
              make_filenames(this::testcase_dir, filename, unicode_method_target,
                             true)[case_target];
            webdav_put(src_file, "FILE " + count, STATUS_CREATED);
            mapping(string:string) locks = ([]);
            if (case_src == case_target) {
              // Src and target is equal and same case but may be different
              // encoded (will be at least once when looping...)
              webdav_move(src_file, target_file, locks, STATUS_FORBIDDEN);
            } else {
              // Src and target is different case (but the same otherwise).
              webdav_move(src_file, target_file, locks,
                          caseSensitive ? STATUS_CREATED : STATUS_NO_CONTENT);
            }
	    // Delete the target file, so that we are guaranteed that the
	    // source file actually gets created with the expected file
	    // name by the put in the next loop.
	    webdav_delete(target_file, locks, STATUS_NO_CONTENT);
          }
        }
      }
    }
  }
}

// Runs only on case insensitive systems.
public void test_x_put_copy_move_delete()
{
  if (case_sensitive_filesystem()) {
    return;
  }
  string mv_dst = Stdio.append_path(this::testcase_dir, "mv_dst");
  string cp_dst = Stdio.append_path(this::testcase_dir, "cp_dst");
  foreach (FILENAMES, string filename) {
    foreach (({"NFC", "NFD"}), string unicode_method_put) {
      string put_path = make_filenames(this::testcase_dir,
                                       filename,
                                       unicode_method_put,
                                       true)->mc;
      string ls_name = make_filenames(this::testcase_dir,
                                       filename,
                                       "NFC",
                                       false)->mc;
      foreach (({"NFC", "NFD"}), string unicode_method_cpmv) {
        mapping(string:string) path = make_filenames(this::testcase_dir,
                                                         filename,
                                                         unicode_method_cpmv,
                                                         true);
        foreach (({"lc", "uc"}), string case_) {
          webdav_put(put_path, "My content", STATUS_CREATED);
          webdav_ls(this::testcase_dir, ({ this::testcase_dir, ls_name }));

          // Put with wrong case should not change filename.
          webdav_put(path[case_], "My new content", STATUS_OK);
          webdav_ls(this::testcase_dir, ({ this::testcase_dir, ls_name }));

          // Copy/Move with wrong case in path.
          webdav_copy(path[case_], cp_dst, STATUS_CREATED);
          webdav_move(path[case_], mv_dst, ([]), STATUS_CREATED);
          webdav_ls(this::testcase_dir, ({ this::testcase_dir, cp_dst, mv_dst }));

          // Cleanup for next round.
          webdav_delete(cp_dst, ([]), STATUS_NO_CONTENT);
          webdav_delete(mv_dst, ([]), STATUS_NO_CONTENT);

          // Delete with wrong case in path.
          webdav_put(put_path, "My content", STATUS_CREATED);
          webdav_ls(this::testcase_dir, ({ this::testcase_dir, ls_name }));
          webdav_delete(path[case_], ([]), STATUS_NO_CONTENT);

          // Assert testcase dir is empty.
          webdav_ls(this::testcase_dir, ({ this::testcase_dir }));
        }
      }
    }
  }
}

public void test_x_lock()
// Test cannot do mkcol on a locked non existing resource without lock.
// Test cannot put on a locked non existing resource without lock.
// Test cannot put on locked existing resource without lock.
// Test cannot delete locked existing resource without lock.
// Test can put on locked existing resource if we have the lock.
// Test can delete locked existing resource if we have the lock.
// Test lock handling is case insensitive on case insensitive systems.
//
// We satisfy with taking a lock on a resource with mixed case and later
// creating a file with the same case.
{
  bool caseSensitive = case_sensitive_filesystem();
  array(string) cases = ({"mc", "lc", "uc"});
  if (caseSensitive) {
    cases = ({ "mc" });
  }
  foreach (FILENAMES, string filename) {
    foreach (({"NFC", "NFD"}), string unicode_method) {
      mapping(string:string) resources = make_filenames(this::testcase_dir,
                                                        filename,
                                                        unicode_method,
                                                        true);
      string resource = resources->mc;
      string ls_name = make_filenames(this::testcase_dir,
                                       filename,
                                       "NFC",
                                       false)->mc;
      foreach (({"NFC", "NFD"}), string unicode_method) {
        mapping(string:string) resources = make_filenames(this::testcase_dir,
                                                          filename,
                                                          unicode_method,
                                                          true);
        foreach (cases, string case_) {
          // Lock the resource (does not exist yet).
          mapping(string:string) locks = ([]);
          webdav_lock(resource, locks, STATUS_OK);

          // Verify that we cannot create collection or file without the lock.
          // Try do delete without lock.
          webdav_mkcol(resources[case_], STATUS_LOCKED);
          webdav_put(resources[case_], "My content", STATUS_LOCKED);
          webdav_ls(resources[case_], ({ }), STATUS_NOT_FOUND);
          webdav_delete(resources[case_], ([]), STATUS_NOT_FOUND);

          // Now lets create a the resources (a file) that we have locked.
          webdav_put(resource, "My content", STATUS_CREATED,
                     make_lock_header(locks));
          webdav_ls(this::testcase_dir, ({ this::testcase_dir, ls_name }));

          // Try to write to the locked file. Try to delete the locked file.
          webdav_put(resources[case_], "New content", STATUS_LOCKED);
          webdav_delete(resources[case_], ([]), STATUS_LOCKED);

          string lock_token = locks[resource];
          mapping(string:string) lock_header =
            make_lock_header(([ resources[case_] : lock_token ]));
          // Put using lock.
          webdav_put(resources[case_], "New content", STATUS_OK, lock_header);
          // The put above should not have changed the filename
          webdav_ls(this::testcase_dir, ({ this::testcase_dir, ls_name }));

          // Delete without the lock.
          webdav_delete(resources[case_], ([]), STATUS_LOCKED);
          // Delete using lock.
          webdav_delete(resources[case_], ([]), STATUS_NO_CONTENT, lock_header);

          // Assert testcase dir is empty before next run.
          webdav_ls(this::testcase_dir, ({ this::testcase_dir }));
        }
      }
    }
  }
}

