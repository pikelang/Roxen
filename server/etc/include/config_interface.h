#define config_setting(X) (id->misc->config_settings->query(X,1))
#define config_setting2(X) RXML.get_var(X,"usr")
#define config_perm(X)    (id->misc->config_user && id->misc->config_user->auth(X))
#define config_host       id->misc->remote_config_host

#define SITE_TEMPLATES "site_templates/"
#define ACTIONS        "config_interface/actions/"

#ifdef ADMIN_IF_DEBUG
# define TRACE(X...)werror("%s:%d: %s",basename(__FILE__),__LINE__,sprintf(X))
# define CFIF_THROW(X...)error("CFIF17: " + sprintf(X))
#else
# define TRACE(X...)
# define CFIF_THROW(X...)werror("__notice__:%s:%d: %s",basename(__FILE__),__LINE__,sprintf(X))
#endif
