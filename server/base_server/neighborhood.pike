#define DELAY 10

mapping neighborhood = ([ ]);
object udp_broad=spider.dumUDP();

void got_info()
{
  int cs;
  mapping m = decode_value(udp_broad->read()->data),
          ns = neighborhood[m->configurl]||([]);

  if(m->last_reboot < ns->last_reboot)
  {
    m->last_last_reboot = m->last_reboot;
    m->seq_reboots++;
  } else {
    if(m->sequence!=ns->sequence)
      m->seq_reboots=0;
  }
  neighborhood[m->configurl] = ns | m;
}

string network_number()
{
  return roxen->query("neigh_ip");
}

int seq,lr=time();
void broadcast()
{
  udp_broad->
    send(network_number(),51521,
	 encode_value((["configurl":roxen->config_url(),
			"host":gethostname(),
			"sequence":seq++,
		     	"uid":getuid(),
			"last_reboot":lr,
			"comment":roxen->query("neigh_com"),
			"server_urls":Array.map(roxen->configurations,
				   lambda(object c)  {
			  return c->query("MyWorldLocation");
			})
		      ])));
  call_out(broadcast,30);
}

void create()
{
  udp_broad->bind(51521);
  udp_broad->set_read_callback(got_info);
  if(roxen->query("neighborhood"))
     broadcast();
  add_constant("neighborhood", neighborhood);
}
