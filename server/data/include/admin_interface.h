#define config_setting(X) (id->misc->config_settings->query(X,1))
#define config_setting2(X) RXML.get_var(X,"usr")
#define config_perm(X)    (id->misc->config_user && id->misc->config_user->auth(X))

#define SITE_TEMPLATES "site_templates/"
