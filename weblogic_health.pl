#!/usr/bin/perl
# Forked by Gerrit Doornenbal 
# https://github.com/gdoornenbal/nagios-Weblogic_health
#
# version 0.5 jan 2017
#	* enhanced commandline options and manageability.
#   * removed lstatus as that MIB doesn't exist.
#   * added debug to show more info while testing.
#   * added option to filter applications.
#   * added option to count (user) sessions.
#
# https://github.com/waynejgrace/nagios-Weblogic_health
# version 0.02 12/28/2015

use strict;
use warnings;
use File::Basename;
use Getopt::Long;

my $version="0.5";

#Commandline option vars.
my $port=165;
my $COMMUNITY="public";
my $IP;
my $lapps="";
my $dplcrit;
my $runcrit;
my $jdbccrit;
my $perfout="";
my $minheapfree=10;
my $debug =	0;
my $perf = 0;
my $weburifilter="formsweb.war|web.war";

my $x=0;
my $k=0;
my $warn=0;
my $crit=0;
my $health=0;
my $strout="";
my $errout="";
my $warnout="";
my $dplnum=0;
my $runnum=0;
my $jdbcnum=0;
my $sessions=0;

my $STATE_CRITICAL=2;
my $STATE_WARNING=1;
my $STATE_UNKNOWN=3;
my $STATE_OK=0;
my $jdbcerrout="";


sub print_usage() {
	my $basename = basename($0);

print <<DATA;

 $basename -H hostname [-P port] [-C community] [-h] [-d] [-f] [-a int][-n str][-u str] [-r int][-m %] [-j int]
 Version: $version
	
 -h|--help          This help screen
 -H|--hostname      Hostname to send query.
 -P|--port          Port where SNMP server is listening [Default: $port]
 -C|--community     SNMP Community [Default: public]
 -a|--appscount     Check for number of deployed applications
 -n|--appname         Filter deployed applications, separated by "|", eg "fooapp|fooapp2"
 -u|--urifilter       Default only apps running weburi "formsweb.war" and "web.war" are counted, as most
                      other apps are system apps.  If you want to monitor those too, you can give a new 
                      filter here. (without value all apps are selected. You can also use | to separate.)
 -r|--runtime       Check for number of Weblogic JVM Runtimes.
 -m|--minheapfree   Maximum allowed percentage Runtime JVM heapspace. [Default $minheapfree]
 -j|--jdbccount     Check number of JDBC connectors.
 -f|--perf          Show perfdata JVM heapspace, JDBC and app-user-sessions.
 -d|--debug         Activate debug mode.
	
DATA
	exit $STATE_UNKNOWN;
}

sub check_options () {
	my $o_help;
	my $o_debug;

	Getopt::Long::Configure ("bundling");
	GetOptions(
		'h|help'	=> \$o_help,
		'H|hostname:s'	=> \$IP,
		'C|community:s'	=> \$COMMUNITY,
		'P|port:i'	=> \$port,
		'a|appscount:i'	=> \$dplcrit,
		'n|appname:s' => \$lapps,
		'u|urifilter:s' => \$weburifilter,
		'r|runtime:i' => \$runcrit,
		'j|jdbccount:i' => \$jdbccrit,
		'm|minheapfree:i' => \$minheapfree,
		'd|debug'	=> \$debug,
		'f|perf'	=> \$perf,
	);

	print_usage() if (defined($o_help));
	$debug = 1 if (defined($o_debug));
	if ( $minheapfree !~ /^\d+$/ or ($minheapfree <= 0 or $minheapfree > 100)) {
		print "\nPlease insert an integer value between 1 and 100 for --minheapfree\n";
		print_usage();
	}
	if ( !defined($IP) ) {
		print "\nPlease give a host to check\n";
		print_usage();
	}
}


#Start 
check_options();

#Retrieve SNMP info..
#Weblogic Runtimes
my $lservers =`snmpwalk -v 1 -c $COMMUNITY $IP:$port enterprises.140.625.360.1.60 2> /dev/null`;
if ( !$lservers ) { print "No Weblogic Server Responding to SNMP.\n"; exit $STATE_UNKNOWN;}
my $lservername =`snmpwalk -v 1 -c $COMMUNITY $IP:$port enterprises.140.625.360.1.5 2> /dev/null`;
my $lheapname =`snmpwalk -v 1 -c $COMMUNITY $IP:$port enterprises.140.625.340.1.15 2> /dev/null`;
my $lheap =`snmpwalk -v 1 -c $COMMUNITY $IP:$port enterprises.140.625.340.1.52 2> /dev/null`;

#jdbc
my $connections =`snmpwalk -v 1 -c $COMMUNITY $IP:$port enterprises.140.625.190.1.25 2> /dev/null`;
my $maxconnections =`snmpwalk -v 1 -c $COMMUNITY $IP:$port enterprises.140.625.190.1.60 2> /dev/null`;
my $nameconnections =`snmpwalk -v 1 -c $COMMUNITY $IP:$port enterprises.140.625.190.1.05 2> /dev/null`;
my $connectorstate =`snmpwalk -v 1 -c $COMMUNITY $IP:$port enterprises.140.625.190.1.75 2> /dev/null`;

#Application Deployments
my $lappname =`snmpwalk -v 1 -c $COMMUNITY $IP:$port enterprises.140.625.430.1.25 2> /dev/null`;
my $lappdepl =`snmpwalk -v 1 -c $COMMUNITY $IP:$port enterprises.140.625.430.1.30 2> /dev/null`;
my $lappsess =`snmpwalk -v 1 -c $COMMUNITY $IP:$port enterprises.140.625.430.1.50 2> /dev/null`;
my $lappuri = `snmpwalk -v 1 -c $COMMUNITY $IP:$port enterprises.140.625.430.1.76 2> /dev/null`;

#Weblogic runtimes logic
my @lservers = split (/\n/,$lservers);
my @lservername = split (/\n/,$lservername);
foreach ( @lservers ) {
	s/^.*STRING:.//s;
}
foreach ( @lservername ) {
   	s/^.*Name=//s;
   	s/,Type.*//;
}

for ( $x = 0; $x <= $#lservers; $x++ ) {
	if ( $debug ) { print "Weblogic instance: $lservername[$x] is $lservers[$x]\n"; } 
	if ( $lservers[$x] !~ "RUNNING" ) {
		$errout = $errout."Weblogic Runtime $lservername[$x] has status $lservers[$x]. ";
		$crit++;
	}
    else {
		$runnum++;
    }
}
$strout="$runnum Running weblogic runtime(s)";

# Weblogic heapspace checks
if( $lheap ) {
	my @lheap = split (/\n/,$lheap);
	my @lheapname = split (/\n/,$lheapname);
	foreach ( @lheap) {
		s/^.*INTEGER:.//s;
	}
	foreach ( @lheapname ) {
		s/^.*STRING:.//s;
		s/"//;
		s/"//;
	}
	
	for ( $x = 0; $x <= $#lheap; $x++ ) {
		$perfout=$perfout."'$lheapname[$x]_heap'=".(100-$lheap[$x])."%;;90;0;100 ";
		if ( $debug ) { print "Weblogic jvmRuntime : $lheapname[$x] heapspace is $lheap[$x]% free\n"; } 
		if ( $lheap[$x] <= $minheapfree ) {
			$errout = $errout."$lheapname[$x] is at $lheap[$x]% heap free. ";
		$crit++;
		$health++;
		}
	}
}
#END Weblogic

#START JDBC
if ( $connections ) {
	my @connections = split (/\n/,$connections);
	my @maxconnections = split (/\n/,$maxconnections);
	my @nameconnections = split (/\n/,$nameconnections);
	my @connectorstate = split (/\n/,$connectorstate);
	foreach ( @connections ) {
		s/^.*INTEGER:.//s;
	}
	foreach ( @maxconnections ) {
		s/^.*INTEGER:.//s;
	}
	foreach ( @nameconnections ) {
		s/^.*Name=//s;
		s/,ServerRuntime.*//;
	}
	foreach ( @connectorstate ) {
		s/^.*STRING:.//s;
	}
	
	for ( $x = 0; $x <= $#connections; $x++ ) {
		$k=($connections[$x]+$k);
		if ( $connections[$x] >= $maxconnections[$x] ) {
			$jdbcerrout = $jdbcerrout.$nameconnections[$x]." ";
			$crit++;
			$health++;
		}	    
	}
	for ( $x = 0; $x <= $#connectorstate; $x++ ) {
		if ( $debug ) { print "JDBC Connector: $nameconnections[$x] is $connectorstate[$x]\n"; } 
		if ( $connectorstate[$x] !~ "Running") {
		$crit++;
		$errout= $errout.$nameconnections[$x]." is $connectorstate[$x]. ";
		}
		else {
		$jdbcnum++;
		}
	}

$strout = $strout.", $jdbcnum JDBC connector(s)";
if ( $k != 0 ) {$strout = $strout." with $k connections";}

if ($jdbcerrout) {
	$errout= $errout."JDBC connector(s) $jdbcerrout"."reached max connections. ";
	}
}
else {
	$crit++;
	$errout= $errout."No JDBC Connectors Running. ";
}

$perfout=$perfout."'JDBC_connections'=$k;;;0; ";
# END JDBC


# Start Weblogic Apps
if ( $lappname ) {
	my @lappname = split (/\n/,$lappname);
	my @lappdepl = split (/\n/,$lappdepl);
	my @lappuri = split (/\n/,$lappuri);
	my @lappsess = split (/\n/,$lappsess);
	foreach ( @lappname ) {
		s/^.*STRING: .//s;
		s#_/#-#s;
		s/"//;
	}
	foreach ( @lappdepl ) {
		s/^.*STRING: .//s;
	  	s/"//;
	}
	foreach ( @lappuri ) {
		s/^.*STRING: .//s;
	  	s/"//;
	}
	foreach ( @lappsess ) {
		s/^.*INTEGER:.//s;
	}

	for ( $x = 0; $x <= $#lappname; $x++ ) {
		if ( $debug ) { print "Application $lappname[$x] uri $lappuri[$x] is $lappdepl[$x], current $lappsess[$x] sessions\n"; } 
		
		if (( $lappname[$x] =~ m{$lapps} ) && ($lappuri[$x] =~ $weburifilter) && ( $lappdepl[$x] eq "DEPLOYED" ) ) {
			$dplnum++;
			$sessions=$sessions+$lappsess[$x];
		    if ( $debug ) { print "  Selected!!\n"; } 
		}
		elsif ( $lappname[$x] =~ m{$lapps} && ($lappuri[$x] =~ $weburifilter) ) {
			$errout= $errout."$lappname[$x] is $lappdepl[$x]. ";
			$crit++;
			if ( $debug ) { print "  Selected, but not Deployed!!\n"; } 
		}
	}
  $strout= "$dplnum Apps deployed, $sessions users active. ".$strout;
  if ( $dplnum == 0 ) { $crit++; }
}
$perfout=$perfout."'User_sessions'=$sessions;;;0;";
# END Weblogic Apps


#Check for Performance data output.
if ( $perf == 1 ) { $strout="$strout.|$perfout"; }

# Check for count mismatches, CRITICAL state when incorrect.
	#print "Health = $health Warn=$warn Crit=$crit\n";
	if ( $health == 0 ) { $warn=$crit; $crit=0; }
	$warnout=$errout;
	#$errout="";

	if ( $dplcrit && $dplnum != $dplcrit ) {
		$crit++;
		$errout= "Application count mismatch ($dplnum,$dplcrit). ";
	}
	if ( $runcrit && $runnum != $runcrit ) {
		$crit++;
		$errout= "Runtime count mismatch ($runnum,$runcrit). ".$errout;
	}
	if ( $jdbccrit && $jdbcnum != $jdbccrit ) {
		$crit++;
		$errout= "JDBC count mismatch ($jdbcnum,$jdbccrit). ".$errout;
	}

#Exit script with state info.
if ( $crit != 0 ) {
        print "CRITICAL: $errout$warnout\n";
        print "$strout\n";
        exit $STATE_CRITICAL;
}
elsif ( $warn != 0 ) {
        print "WARNING: $warnout\n";
        print "$strout\n";
	exit $STATE_WARNING;
}
else {
        print "OK: ";
        print "$strout\n";
	exit $STATE_OK;
}



