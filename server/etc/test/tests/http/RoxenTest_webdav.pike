inherit "etc/test/tests/http/WebdavTestBase.pike";

private string testdir = "/testdir/";
private string filesystem_dir = "$VARDIR/testsuite/webdav";
// Expanded filesystem_dir.
private string real_dir;

string get_testdir() {
  return testdir;
}

int filesystem_check_exists(string path)
{
  string real_path = Stdio.append_path(real_dir, path);
  return Stdio.is_file(real_path);
}

string filesystem_read_file(string path)
{
  string real_path = Stdio.append_path(real_dir, path);
  return Stdio.read_bytes(real_path);
}

void setup()
{
  webdav_mount_point = "webdav/";
  basic_auth = "test:test";
  real_dir = roxen_path(filesystem_dir);
  report_debug("Webdav real_dir: %O\n", real_dir);
  Stdio.mkdirhier(real_dir);
}
