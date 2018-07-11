inherit "../pike_test_common";

#include <testsuite.h>

import TEST.http.WebDAV;

#ifdef DAV_DEBUG
#define DAV_WERROR(X...)	werror(X)
#else /* !DAV_DEBUG */
#define DAV_WERROR(X...)
#endif /* DAV_DEBUG */

private string filesystem_dir = "$VARDIR/testsuite/webdav";
// Expanded filesystem_dir.
private string webdav_mount_point = "webdav/";
private string username = "test";
private string password = "test";

void run_tests(Configuration conf)
{
  array(Standards.URI) base_uris = TestUtils.get_test_urls(conf,
                                                 webdav_mount_point,
                                                 username,
                                                 password);
  int count = 0;
  foreach (base_uris, Standards.URI base_uri) {
    DAV_WERROR("Webdav testsuite: Base URI: %s\n", (string)base_uri);
    mapping(string:string) base_headers = ([
      "host": base_uri->host,
      "user-agent": "Roxen WebDAV Tester",
      "connection": "keep-alive",
    ]);
    WebdavTest testsuite =
      WebdavTest(webdav_mount_point, base_uri, base_headers, "testdir"+count++);
    testsuite->run();
    // Hack for counting number of tests.
    ::current_test += testsuite->current_test;
    ::tests_failed += testsuite->tests_failed;
  }
}


private class WebdavTest {

  inherit TestBase;

  private string real_dir = roxen_path(filesystem_dir);

  protected void create(string webdav_mount_point,
                        Standards.URI base_uri,
                        mapping(string:string) base_headers,
                        string testdir)
  {
    ::create(webdav_mount_point, base_uri, base_headers, testdir);
    DAV_WERROR("Webdav real_dir: %O\n", real_dir);
    Stdio.mkdirhier(real_dir);
  }

  protected int filesystem_check_exists(string path)
  {
    path = string_to_utf8(Unicode.normalize(utf8_to_string(path), "NFC"));
    string real_path = Stdio.append_path(real_dir, path);
    return Stdio.exist(real_path);
  }

  protected string filesystem_read_file(string path)
  {
    path = string_to_utf8(Unicode.normalize(utf8_to_string(path), "NFC"));
    string real_path = Stdio.append_path(real_dir, path);
    return Stdio.read_bytes(real_path);
  }

  protected array(string) filesystem_get_dir(string path)
  {
    path = string_to_utf8(Unicode.normalize(utf8_to_string(path), "NFC"));
    string real_path = Stdio.append_path(real_dir, path);
    return get_dir(real_path);
  }

  protected int filesystem_is_dir(string path)
  {
    path = string_to_utf8(Unicode.normalize(utf8_to_string(path), "NFC"));
    string real_path = Stdio.append_path(real_dir, path);
    return Stdio.is_dir(real_path);
  }

  protected int filesystem_is_file(string path)
  {
    path = string_to_utf8(Unicode.normalize(utf8_to_string(path), "NFC"));
    string real_path = Stdio.append_path(real_dir, path);
    return Stdio.is_file(real_path);
  }

  protected int(0..1) filesystem_mkdir_recursive(string(8bit) path)
  {
    string real_path = Stdio.append_path (real_dir, path);
    return Stdio.mkdirhier(real_path);
  }

  //! Writes a file to @[path], which is used verbatim without any normalization.
  protected int(0..) filesystem_direct_write(string(8bit) path,
                                             string(8bit) data)
  {
    string real_path = Stdio.append_path (real_dir, path);
    return Stdio.write_file(real_path, data);
  }

  // protected int filesystem_recursive_rm(string path)
  // {
  //   path = string_to_utf8(Unicode.normalize(utf8_to_string(path), "NFC"));
  //   string real_path = Stdio.append_path(real_dir, path);
  //   return Stdio.recursive_rm(real_path);
  // }

}

