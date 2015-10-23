// This file is part of Roxen WebServer.
// Copyright © 1999 - 2009, Roxen IS.
//
// A throttling co-ordinator. Will share bandiwdth among
// many pending requests.
//
// By Francesco Chemolli
//
// Notice: this works under the hypothesis that there's only one thread
// shuffling data (so no locking is done). This might be a wrong
// assumption. Per? Grubba?
//

constant cvs_version="$Id$";

#define DEFAULT_MINGRANT 1300
#define DEFAULT_MAXGRANT 65000

#ifdef THROTTLING_DEBUG
# undef THROTTLING_DEBUG
# define THROTTLING_DEBUG(X) report_debug("throttler: "+X+"\n")
#else
# define THROTTLING_DEBUG(X)
#endif

private int bucket=0;
private int fill_rate=0;    //if 0, no throttling is done
private int depth;          //the max bucket depth
private int last_fill=0;

private int min_grant=0;    //if we'd grant less than this, don't grant at all.
private int max_grant=0;    //maximum granted size for a single request

ADT.Queue requests_queue; //lazily instantiated.

//request format: ({ int howmuch, function callback, string host,
//                   array(mixed) extra_args })

//start throttling, given rate, depth, initial fillup, and min grant
//if not supplied, mingrant is set to DEFAULT_MINGRANT by default
//same for maxgrant
void throttle (int r, int d, int|void initial,
               int|void mingrant, int|void maxgrant) {
  THROTTLING_DEBUG("throttle(rate="+r+", depth="+d+
                   ",\n\tinitial="+initial+", mingrant="+mingrant+
                   ", maxgrant="+maxgrant);
  fill_rate=r;
  depth=max(d,r);
  if( initial )
    bucket=initial;
  min_grant=(zero_type(mingrant)?DEFAULT_MINGRANT:mingrant);
  max_grant=(zero_type(maxgrant)?DEFAULT_MAXGRANT:maxgrant);
  if( !requests_queue ) // First time.
  {
    last_fill=time(1);
    requests_queue=ADT.Queue();
  }
  remove_call_out(safety_net);
  call_out(safety_net,1);
}

//fills the bucket up, and tries to wake up some requests if possible.
private void fill_bucket() {
  int toadd;
  if (!fill_rate) //nothing to do.
    return;
  toadd=((time(1)-last_fill)*fill_rate);
  bucket+=toadd;
  THROTTLING_DEBUG("adding "+toadd+" tokens");
  last_fill=time(1);
  if (bucket>depth)
  {
    bucket=depth;
    if( min_grant >= depth )
    {
      THROTTLING_DEBUG("Adjusting min_grant to depth ("+depth+") was "+
		       min_grant);
      min_grant = depth;
    }
  }
  wake_up_some();
}

//handles as many pending requests as possible
private void wake_up_some () {
  THROTTLING_DEBUG("wake_up_some");
  array request;
  multiset seen = (<>);
  multiset have = (<>);
  while ((!requests_queue->is_empty()) && (bucket >= min_grant)) {
    request=requests_queue->get();
    if( seen[request] )
    {
      have = (<>);
      seen = (<>);
    }
    seen[request] = 1;
    if( have[request[2]] )
    {
      requests_queue->put( request );
      continue;
    }
    have[request[2]]=1;
    grant(@request);
  }
  THROTTLING_DEBUG("Done waking up requests");
}

//handles a single request. It assumes it has been granted, otherwise
//it will allow going over quota.
private void grant (int howmuch, function callback, string host,
		    array(mixed) cb_args ) {
  THROTTLING_DEBUG("grant("+howmuch+"). bucket="+bucket);
  if (!callback) {
    THROTTLING_DEBUG("no callback. Exiting");
    return;
  }
  if (howmuch >= bucket) {
    THROTTLING_DEBUG("limiting granted bandwidth");
    howmuch=bucket;
  }
  bucket-=howmuch;
  callback(howmuch,@cb_args);
}


//request for permission to send this much data.
//when granted, callback will be called. First arg is the number
//of allowed bytes. Then the hereby supplied args.
void request (int howmuch, function(int,mixed ...:void) callback,
	      string host, mixed ... cb_args) {
  if (!fill_rate) { //no throttling is actually done
    THROTTLING_DEBUG("auto-grant (not throttling)");
    callback(howmuch,@cb_args);
    return;
  }

  if (howmuch > max_grant) {
    THROTTLING_DEBUG("request too big, limiting");
    howmuch=max_grant;
  }

//    fill_bucket(); //maybe we can squeeze some more bandwidth.

  if (bucket <= min_grant ) { //bad luck. Nothing to allow. Enqueue
    THROTTLING_DEBUG("no tokens, enqueueing");
    requests_queue->put( ({howmuch,callback,host,cb_args}) );
    return;
  }

  THROTTLING_DEBUG("granting");
  grant (howmuch, callback, host, cb_args);
}


//after a request has been granted, if the request doesn't use all of the
//assigned bandwidth, it can return the unused amount.
void report_unused (int howmuch) {
  THROTTLING_DEBUG("got an unused bandwidth report ("+howmuch+")");
  bucket+=howmuch;
}

//a call_out cycle, in order to make sure that we fill the bucket at least
//once per second. Otherwise we might enqueue all the pending requests, and
//get stuck until a new one is done.
private void safety_net () {
  /* THROTTLING_DEBUG("throttler: safety net"); */
  call_out(safety_net,1);
  if (requests_queue->is_empty())
    return;
  fill_bucket(); //might wake a request up there.
}

void destruct () {
  THROTTLING_DEBUG("destroying");
  remove_call_out(safety_net);
}

#ifdef THROTTLING_DEBUG
void create() {
  THROTTLING_DEBUG("creating");
}
#endif
