#ifndef TIMER_PREFIX
#define TIMER_PREFIX ""
#endif

#ifdef TIMERS
mapping(string:int) timers = ([]);
#define TIMER_START(X)  int _timer_##X = gethrtime()
#define TIMER_END(X)    timers[TIMER_PREFIX+#X] += gethrtime()-_timer_##X
#define TIMER_STARTS(X) int _timer_ = gethrtime()
#define TIMER_ENDS(X)   timers[TIMER_PREFIX+X] += gethrtime()-_timer_
#define MERGE_TIMERS(X) do{if(X)foreach(indices(timers),string t)X->timers[t]+=timers[t];timers=([]);}while(0)
#else
#define TIMER_STARTS(X)
#define TIMER_ENDS(X)  
#define TIMER_START(X)
#define TIMER_END(X)
#define MERGE_TIMERS(X)
#endif
