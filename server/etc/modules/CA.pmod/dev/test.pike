#!/usr/bin/env pike

/*
  Run with: pike -M../../ test.pike
*/

constant DIR_URI = "https://acme-staging.api.letsencrypt.org/directory";

import CA;

int main(int argc, array(string) argv)
{
  // thread_create(run);
  // run();
  check_account();

  return -1;
}

void check_account()
{
  string fname = "4925811.account";
  if (!Stdio.exist(fname)) {
    werror("Account file %O doesn't exist\n", fname);
    exit(1);
  }

  string raw = Stdio.read_file(fname);

  ACME.Account account = ACME.decode_account(raw);
  ACME.Service acme = ACME.get_service(DIR_URI, account->key);

  acme->check_account(account->key)
    ->then(lambda (mixed ok) {
      werror("Yay: %O\n", ok);
      exit(0);
    })
    ->thencatch(lambda (ACME.Error e) {
      werror("Dope: %O\n", e);
      exit(1);
    });
}

void run()
{
  ACME.Key key = ACME.generate_key();
  ACME.Service acme = ACME.get_service(DIR_URI, key);

  acme->register("pontus@roxen.com")
    ->then(lambda (ACME.Account res) {
      werror("OK: %O\n", res);
      string s = ACME.encode_account(res);
      Stdio.write_file(res->id + ".account", s);
      exit(0);
    })
    ->thencatch(lambda (mixed err) {
      werror("Error: %O\n", err);
      exit(1);
    });
}
