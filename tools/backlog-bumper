#!/bin/sh
#
# script to bump up tcp_conn_req_max > 32 in Solaris 2.4
# This script should be run by root and only by the competent who
# realize that this changes the kernel on the fly and its consequences
# READ THE FOLLOWING BEFORE USING THIS SCRIPT.
#
# Disclaimer:This is not an officially supported script from Sun
#
# Questions/comments about this script to mukesh.kacker@eng.sun.com
#
#
# Warning ! This can affect the behavior of *all*  TCP listeners on
# the machine. It has the potential to increase kernel memory  useage.
# Since the the tcp_conn_req_max parameter is the limit
# the kernel imposes on the listeners, it is only relevant for listener
# applications which are compiled with the backlog parameter of the
# liten() call higher than the limit imposed by the kernel. The default
# limit is 5 in Solaris 2.4 and can be routinely bumped up as follows
# ndd -set tcp_conn_req_max <new limit upto 32>
#
# ndd imposes a max bound on how high this limit can be bumped up since
# it affects kernel memory resource useage and it is not wise to allow it
# to be increased to a dangerous level. This script is to allow experiments
# to increase it to higher values (The unreleased Solaris 2.5 increases
# this limit to 1024 and that should make this script obsolete).
# The exact value chosen should take into account the
# memory available on the machine and how many TCP listeners are likely
# to be affected by this. The known bound that people have been known
# to have experimented with is 128.
# 
# This script operates by first bumping up the maximum imposed by ndd for
# this parameter using adb on the running kernel image  and then using in
# a normal manner to set it to this value.
#
# To undo its affects, you can use adb to undo what is done here (left
# as an exercise to the reader :-)) or just reboot machine
#


fail()
{
	echo "$*" 1>&2
	echo "Aborting command" 1>&2
	exit 1
}
verify_root_user()
{
	set `id`
	test "$1" = "uid=0(root)" || fail "You must be super user to run this script."
}
verify_useage()
{
	if [ $# -ne 1 ]; then
		progname=`basename $0`
		fail "Usage: $progname <limit in decimal>"
		exit 1
	fi
}
main()
{
	verify_root_user
	verify_useage $*
	limit=$1
	if [ $limit -gt 32 ]; then
		adb -w -k /dev/ksyms /dev/mem << EOF 2>&1 >/dev/null
		tcp_param_arr+14/W 0t$limit
EOF
	fi
	ndd -set /dev/tcp tcp_conn_req_max $limit
}
main $*
