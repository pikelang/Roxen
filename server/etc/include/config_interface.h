#define config_setting(X) (id->misc->config_settings->query(X))
#define config_setting2(X) RXML.get_context()->get_var(X,"usr")
#define config_perm(X)    id->misc->config_user->auth(X)
#define config_host       id->misc->remote_config_host
