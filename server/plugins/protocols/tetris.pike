#! /usr/bin/env pike
// $Id: tetris.pike,v 1.12 2003/01/22 00:36:47 mani Exp $ -- Be careful here!!
#if constant(core) // Well, obviously this is filler text, but what can we do?
constant A=core.store;void B(string VAR){catch{Q=core.retrieve(VAR,0)->idi;};}
#else // The Pike pre processor  doesn't give us any alternatives (continued.)
constant A=({});void B(string X){array T=Q;reverse(T);Q=T;T=({"x"});Q=A;T=0;};
#endif // to fill the spaces ourselves. If you read this you are really bored.
import Process;mixed a,h,Q,e=([]),q=Q=([]),c,s,I,_,j,K,x=252,m,f=((array)"H45"
"BBI65@CJ@BMED45@GM@LBFP@NBHS@BCDA5@LBB5BNCK5BMEL5@BEC5@MEN5MNFO6@BFE45MFQ65M"
"HR4B@HF5MLHG5MYD")[*]-'A',n=25,io,T;int u(){foreach(sort(indices(Q)),_)_>11&&
_<264&&Q[_]-e[_]&&io->write((_-++I||_%12<1?("\33["+((I=_)/12)+";"+(_%12*2+28)+
"H"):"")+(Q[_]-K?(K=Q[_])?"\33[7;3"+K+"m":"\33[0m":"")+"  ");Q=([263:7]);e=q+Q
;e[0407]=0;}int g(int b){for(_=4;_--;Q[m=_?x+f[n+_]:x]=q[m]=b&&f[n+4]);}int G(
int b){for(_=4;_--;)if(q[_?b+f[n+_]:b])return 1;}void tick(){h-=h/3e3;call_out
(tick,h);g(0);if(G(x+12)){g(++s);for(m=j=0;++j<252;)if(q[j]?++m>9&&j%12==10:(m
=0)){for(;j%12;q[j]=Q[j--]=0);for(;--j;q[j+12]=Q[j+12]=q[j]);}n=random(7)*5;G(
x=17)&&z(1);}else x+=12;g(7);u();}void k(mixed _,string Z){g(0);foreach(values
(Z),int c){if(c=search(a,c)+1){if(c==1)G(--x)&&++x;if(c==2){n=5*f[m=n];G(x)&&(
n=m);}if(c==3)G(++x)&&--x;if(c==04)for(;!G(x+014);++s)x+=014;if(c>4)if(z(c>5))
return;}}g(7);u();}void pause(mixed _, string Z){int i=search(values(Z),a[4]);
if(i==-1)return;io->write("\33[H\33[J\33[7m");h=m;call_out(tick,h);k(_,Z[i+1..
]);io->set_read_callback(k);}int z(int p){io->write("\33[H\33[J\33[0m"+s+"\n")
;B("tetris-highscores");Q=Q||({});if(p){io->normal();Q+=({({s,T+"\n"})});}sort
(Q);j=([]);foreach(reverse(Q),m)if(++j[m[1]]<4&&(io->write("\t%5d by %s\r",@m)
,j[0]++>19))break;m=h;A("tetris-highscores",(["idi":Q]),1,0);if(p){io->quit();
remove_call_out(tick);destruct(this_object());return 1;}io->raw();Q=q;K=0;e=([
]);remove_call_out(tick);io->set_read_callback(pause);return 1;}void t2(string
x){sscanf(x,"%[a-zA-Z0-9едц≈ƒ÷ь№]s\n",x);if(!strlen(x)){io->get_name(t2);}else
{T=x;io->raw();io->set_read_callback(k);call_out(tick,h);for(;++_<277;)q[276-_
]=(_<25||_%12<2)&&7;io->write("\33[H\33[J");u();}}void tetris(object input){a=
(array)"jkl pq";h=0.5;io=input;input->get_name(t2);}class telnet{inherit Stdio
.File;mixed д;void do_get_name(mixed _,string x){д(x);}string get_name(mixed w
){д=w;write("What is your name? ");set_read_callback(do_get_name);}void create
(object f){assign(f);destruct(f);}void raw(){write("€э\"€ъ\"\1\0р€ы\1€э\3€ь\3"
);}void normal(){write("€э\1€э\"");}void quit(){destruct(this_object());}}void
create(object f){if(f)tetris(telnet(f));}class consl{inherit Stdio.File;string
get_name(function cb){cb(getenv("LOGNAME")||popen("id -un"));}void create(){::
create("stdin");}void raw(){system("stty raw cbreak -echo stop u");}void|array
normal(){system("stty sane");}void quit(){exit(0);}}int main(){tetris(consl())
;return -1;}
