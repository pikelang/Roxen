inherit "../pike_test_common";

#include <testsuite.h>


protected string webdav_mount_point;

protected string basic_auth;

// Current Base URL to run the test suite for.
// Note that the hostname is an ip-number.
private Standards.URI base_uri;

// Current http client connection.
private Protocols.HTTP.Query con;

// Common HTTP headers to send for all HTTP requests.
private mapping(string:string) base_headers;

/* Some globals to avoid having to pass this stuff around explicitly. */
protected mapping(string:string) current_locks;

int filesystem_check_exists(string path);

string filesystem_read_file(string path);

int filesystem_check_content(string path, string expected_data)
{
  string actual_data = filesystem_read_file(path);
  TEST_EQUAL(actual_data, expected_data);
  return actual_data == expected_data;
}

int filesystem_compare_files(string first_path, string other_path)
{
  return filesystem_check_content(other_path, filesystem_read_file(first_path));
}


array(int|mapping(string:string)|string) webdav_request(string method,
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
    Standards.URI dest_uri = Standards.URI(new_uri, base_uri);
    headers["destination"] = (string)dest_uri;
  }

  multiset(string) locks = (<>);
  if (current_locks) {
    foreach(lock_paths, string dir) {
      while(1) {
        string lock = current_locks[dir];
        if (lock) {
          locks[lock] = 1;
        }
        if (dir == "/") {
          break;
        }
        dir = dirname(dir);
      }
    }
    if (sizeof(locks)) {
      headers->if = "(<" + (indices(locks) * ">), (<") + ">)";
    }
  }
  if (has_prefix(path, "/")) {
    path = path[1..];
  }

  Standards.URI url = Standards.URI(path, base_uri);
  con = Protocols.HTTP.do_method(method, url, UNDEFINED, headers, con, data);

  report_debug("Webdav: %s %O (url: %O) ==> code: %d\n",
         method, path, url, con?con->status:600);

  if (!con) {
    return ({ 600, ([]), "" });
  }

  return ({ con->status, con->headers, con->data() });
}

int webdav_put(string path, string data)
{
  array(int|mapping(string:string)|string) res =
    webdav_request("PUT", path, UNDEFINED, data);

  if (!((res[0] >= 200) && (res[0] < 300))) {
    return 0;
  }

  return filesystem_check_content(path, data);
}

int webdav_lock(string path, mapping(string:string) locks)
{
  string lock_info = #"
<?xml version='1.0' encoding='utf-8'?>
<DAV:lockinfo xmlns:DAV='DAV:'>
  <DAV:locktype><DAV:write/></DAV:locktype>
  <DAV:lockscope><DAV:exclusive/></DAV:lockscope>
</DAV:lockinfo>
";

  array(int|mapping(string:string)|string) res =
    webdav_request("LOCK", path, UNDEFINED, lock_info);

  if (res[0] != 200) return 0;

  if (!res[1]["lock-token"]) return 0;

  locks[path] = res[1]["lock-token"];
  return 1;
}

void low_unlock(string path, mapping(string:string) locks)
{
  m_delete(locks, path);
}

void low_recursive_unlock(string path, mapping(string:string) locks)
{
  foreach(indices(locks), string lock_path) {
    if (has_prefix(lock_path, path)) {
      low_unlock(path, locks);
    }
  }
}

int webdav_unlock(string path, mapping(string:string) locks)
{
  array(int|mapping(string:string)|string) res =
    webdav_request("UNLOCK", path, ([
         "lock-token": locks[path],
       ]));

  if (!((res[0] >= 200) && (res[0] < 300))) return 0;

  low_unlock(path, locks);
  return 1;
}

int webdav_delete(string path, mapping(string:string) locks)
{
  array(int|mapping(string:string)|string) res =
    webdav_request("DELETE", path);

  if (!((res[0] >= 200) && (res[0] < 300))) return 0;

  low_recursive_unlock(path, locks);
  return !filesystem_check_exists(path);
}

int webdav_copy(string src_path, string dst_path)
{
  array(int|mapping(string:string)|string) res =
    webdav_request("COPY", src_path, ([
         "new-uri": dst_path,
       ]));

  if (!((res[0] >= 200) && (res[0] < 300))) return 0;

  return filesystem_compare_files(src_path, dst_path);
}

int webdav_move(string src_path, string dst_path, mapping(string:string) locks)
{
  string expected_content = filesystem_read_file(src_path);

  array(int|mapping(string:string)|string) res =
    webdav_request("MOVE", src_path, ([
         "new-uri": dst_path,
       ]));

  if (!((res[0] >= 200) && (res[0] < 300))) return 0;

  low_recursive_unlock(src_path, locks);
  test_false(filesystem_check_exists, src_path);
  test_true(filesystem_check_exists, dst_path);
  test_true(filesystem_check_content, dst_path, expected_content);
  return
    !filesystem_check_exists(src_path) &&
    filesystem_check_content(dst_path, expected_content);
}

int webdav_mkcol(string path)
{
  array(int|mapping(string:string)|string) res =
    webdav_request("MKCOL", path);

  return (res[0] >= 200) && (res[0] < 300);
}

int webdav_ls(string path, array(string) expected)
{
  string propfind = #"
<?xml version='1.0' encoding='utf-8'?>
<DAV:propfind xmlns:DAV='DAV:'>
  <DAV:propname/>
</DAV:propfind>
";
  array(int|mapping(string:string)|string) res =
    webdav_request("PROPFIND", path, UNDEFINED, propfind);

  report_debug("Webdav: propfind result: %d\n%O\n", res[0], res[2]);

  TEST_TRUE(res[0] >= 200 && res[0] < 300);
  if (res[0] < 200 || res[0] > 300) {
    return 0;
  }
  Parser.XML.Tree.SimpleRootNode root_node =
    Parser.XML.Tree.simple_parse_input(res[2]);
  array(Parser.XML.Tree.AbstractNode) multistatus_nodes =
    root_node->get_elements("DAV:multistatus", true);
  TEST_TRUE(sizeof(multistatus_nodes) > 0);
  array(Parser.XML.Tree.AbstractNode) response_nodes =
    Array.flatten(multistatus_nodes->get_elements("DAV:response", true));
  TEST_TRUE(sizeof(response_nodes) > 0);
  array(Parser.XML.Tree.AbstractNode) href_nodes =
    Array.flatten(response_nodes->get_elements("DAV:href", true));
  TEST_TRUE(sizeof(href_nodes) > 0);
  array(string) hrefs = href_nodes->value_of_node();
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
  TEST_EQUAL(sort(expected_), sort(actual));
  return equal(sort(expected_), sort(actual));
}

void setup();

void run_tests(Configuration conf)
{
  setup();

  // Run the suite once with every http protocol modules in the conf.
  // This allows for testing such things as sub-path mounted sites etc.
  foreach(conf->registered_urls, string full_url) {
    mapping(string:string|Configuration|array(Protocol)) port_info =
      roxen.urls[full_url];
    if (!test_true(mappingp, port_info)) continue;
    array(Protocol) ports = port_info->ports;
    if (!test_true(arrayp, ports)) continue;
    foreach(ports, Protocol prot) {
      if (!test_true(stringp, prot->prot_name)) continue;
      if (prot->prot_name != "http") continue;

      if (prot->bound != 1) continue;

      if (!test_true(mappingp, prot->urls)) continue;

      // Strip the fragment from the full_url.
      string url = (full_url/"#")[0];
      mapping(string:mixed) url_data = prot->urls[url];
      if (!test_true(mappingp, url_data)) continue;

      report_debug("url data: %O\n", url_data);
      test_true(`==, url_data->conf, conf);
      test_true(`==, url_data->port, prot);
      test_true(stringp, url_data->hostname);
      test_true(stringp, url_data->path || "/");

      Standards.URI url_uri = Standards.URI(url, "http://*/");
      base_uri = Standards.URI(Stdio.append_path(url_data->path || "/",
                                                 webdav_mount_point),
                               url_uri);
      base_uri->port = prot->port;
      base_uri->host = prot->ip;

      if (basic_auth) {
        base_uri->user = (basic_auth/":")[0];
        base_uri->password = (basic_auth/":")[1..] * ":";
      }

      report_debug("Webdav testsuite: Base URI: %s\n", (string)base_uri);

      base_headers = ([
        "host": url_uri->host,
        "user-agent": "Roxen WebDAV Tester",
      ]);

      con = 0;  // Make sure that we get a new connection.

      do_run_tests();
    }
  }
}

string get_testdir();

void do_run_tests() {

  string testdir = get_testdir();
  if (!has_prefix(testdir, "/")) {
    testdir = "/" + testdir;
  }
  if (!has_suffix(testdir, "/")) {
    // Saves us from having to use Stdio.append_path like a million times
    // below...
    testdir += "/";
  }

  report_debug("Webdav: testdir is: %O\n", testdir);

  mapping(string:string) locks = ([]);

  // Clean the test directory.
  test_true(webdav_delete, testdir, locks);
  test_true(webdav_mkcol, testdir);
  test_true(webdav_ls, testdir, ({ testdir }));

  // Test trivial uploads to existing and non-existing directories.
  test_true(webdav_put, testdir+"test_file.txt", "TEST FILE\n");
  //test_false(webdav_put, "/test_dir/test_file.txt", "TEST FILE\n");

  test_true(webdav_ls, testdir, ({ testdir,
                                   testdir+"test_file.txt" }));

  // Test locking and upload.
  test_true(webdav_lock, testdir+"test_file.txt", locks);
  test_false(webdav_lock, testdir+"test_file.txt", ([]));
  test_false(webdav_put, testdir+"test_file.txt", "TEST FILE 2\n");
  test_false(webdav_delete, testdir+"test_file.txt", locks);
  current_locks = locks + ([]);
  test_true(webdav_put, testdir+"test_file.txt", "TEST FILE 3\n");
  test_true(webdav_unlock, testdir+"test_file.txt", locks);
  test_false(webdav_put, testdir+"test_file.txt", "TEST FILE 4\n");
  current_locks = locks + ([]);
  test_true(webdav_put, testdir+"test_file.txt", "TEST FILE 5\n");
  test_true(webdav_lock, testdir+"test_file.txt", locks);
  test_false(webdav_delete, testdir+"test_file.txt", locks);
  current_locks = locks + ([]);
  test_true(webdav_delete, testdir+"test_file.txt", locks);
  test_false(webdav_put, testdir+"test_file.txt", "TEST FILE 6\n");
  current_locks = locks + ([]);
  test_true(webdav_put, testdir+"test_file.txt", "TEST FILE 7\n");
  test_true(webdav_delete, testdir+"test_file.txt", locks);

  //test_false(webdav_mkcol, "/test_dir/sub_dir");
  test_true(webdav_mkcol, testdir+"test_dir");
  test_true(webdav_mkcol, testdir+"test_dir/sub_dir");
  test_true(webdav_put, testdir+"test_dir/test_file.txt", "TEST FILE\n");

  test_true(webdav_lock, testdir+"test_dir/test_file.txt", locks);
  test_false(webdav_move, testdir+"test_dir/test_file.txt", testdir+"test_file.txt", locks);
  test_true(webdav_copy, testdir+"test_dir/test_file.txt", testdir+"test_file.txt");
  test_false(webdav_copy, testdir+"test_file.txt", testdir+"test_dir/test_file.txt");
  current_locks = locks + ([]);
  test_true(webdav_move, testdir+"test_dir/test_file.txt", testdir+"test_file_2.txt", locks);
  // NB: /test_dir/test_file.txt lock invalidated by the move above.
  test_false(webdav_copy, testdir+"test_file.txt", testdir+"test_dir/test_file.txt");
  current_locks = locks + ([]);
  test_true(webdav_copy, testdir+"test_file.txt", testdir+"test_dir/test_file.txt");
  test_true(webdav_lock, testdir+"test_dir/test_file.txt", locks);
  test_false(webdav_copy, testdir+"test_file.txt", testdir+"test_dir/test_file.txt");
  current_locks = locks + ([]);
  test_true(webdav_copy, testdir+"test_file.txt", testdir+"test_dir/test_file.txt");
  test_true(webdav_unlock, testdir+"test_dir/test_file.txt", locks);
}
