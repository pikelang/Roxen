inherit "etc/test/tests/http/WebdavTestBase.pike";

string filesystem_dir = "$VARDIR/testsuite/webdav/testdir";
// Expanded filesystem_dir.
string real_dir;

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
  real_dir = roxen_path(filesystem_dir);

  report_debug("Webdav real_dir: %O\n", real_dir);

  Stdio.mkdirhier(real_dir);
}
