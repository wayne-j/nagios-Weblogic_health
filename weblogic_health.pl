#!/usr/bin/perl
#https://github.com/waynejgrace/nagios-Weblogic_health
#version 0.02 12/28/2015
use strict;
use warnings;

### identify your named deployed applications for filtering, separated by "|"
### my $lapps="fooapp|fooapp2";
my $lapps="";

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
my $perfout="";
my $STATE_CRITICAL=2;
my $STATE_WARNING=1;
my $STATE_UNKNOWN=3;
my $STATE_OK=0;
my $jdbcerrout="";

sub print_usage {
    print "weblogic_health.pl IP:Port COMMUNITY [#apps] [#runtimes] [#JDBC]\n";
}

if  ( !$ARGV[0] || !$ARGV[1] ) {
    print_usage();
    exit $STATE_UNKNOWN;
}

if (( $ARGV[2] ) && ( !$ARGV[3] || !$ARGV[4] )) {
        print_usage();
        exit $STATE_UNKNOWN;
}

my $IP=$ARGV[0];
my $COMMUNITY=$ARGV[1];
my $dplcrit=$ARGV[2];
my $runcrit=$ARGV[3];
my $jdbccrit=$ARGV[4];

my $lservers =`snmpwalk -v 1 -c $COMMUNITY $IP enterprises.140.625.360.1.60 2> /dev/null`;
if ( !$lservers ) { print "No Weblogic Server Responding to SNMP.\n"; exit $STATE_UNKNOWN;}
my $connections =`snmpwalk -v 1 -c $COMMUNITY $IP enterprises.140.625.190.1.25 2> /dev/null`;
my $totconnections =`snmpwalk -v 1 -c $COMMUNITY $IP enterprises.140.625.190.1.60 2> /dev/null`;
my $nameconnections =`snmpwalk -v 1 -c $COMMUNITY $IP enterprises.140.625.190.1.05 2> /dev/null`;
my $connector =`snmpwalk -v 1 -c $COMMUNITY $IP enterprises.140.625.190.1.75 2> /dev/null`;
my $lservername =`snmpwalk -v 1 -c $COMMUNITY $IP enterprises.140.625.360.1.5 2> /dev/null`;
my $lstatus =`snmpwalk -v 1 -c $COMMUNITY $IP enterprises.140.625.360.1.99 2> /dev/null`;
my $lheap =`snmpwalk -v 1 -c $COMMUNITY $IP enterprises.140.625.340.1.52 2> /dev/null`;
my $lheapname =`snmpwalk -v 1 -c $COMMUNITY $IP enterprises.140.625.340.1.15 2> /dev/null`;
my $lappname =`snmpwalk -v 1 -c $COMMUNITY $IP enterprises.140.625.430.1.15 2> /dev/null`;
my $lappdepl =`snmpwalk -v 1 -c $COMMUNITY $IP enterprises.140.625.430.1.30 2> /dev/null`;

my @lservers = split (/\n/,$lservers);
my @lservername = split (/\n/,$lservername);
my @lstatus = split (/\n/,$lstatus);
foreach ( @lservers ) {
	s/^.*STRING:.//s;
}
foreach ( @lservername ) {
   	s/^.*Name=//s;
   	s/,Type.*//;
}
foreach ( @lstatus ) {
	s/^.*State://s;
	s/,MBean:.*Code://;
	s/"//;
}	
for ( $x = 0; $x <= $#lservers; $x++ ) {
	if ( $lservers[$x] !~ "RUNNING" ) {
		$errout = $errout."Weblogic Runtime $lservername[$x] has status $lservers[$x]. ";
		$crit++;
	}
    else {
		$runnum++;
    }
}
$strout="$runnum Running weblogic runtime(s)";

for ( $x = 0; $x <= $#lstatus; $x++ ) {
	if ( $lstatus[$x] !~ "HEALTH_OK" ) {
		$errout = $errout."$lservername[$x] indicates $lstatus[$x]. ";
		$crit++;
		$health++;
	}
}	

if ( $connections ) {
	my @connections = split (/\n/,$connections);
	my @totconnections = split (/\n/,$totconnections);
	my @nameconnections = split (/\n/,$nameconnections);
	my @connector = split (/\n/,$connector);
	foreach ( @connections ) {
		s/^.*INTEGER:.//s;
	}
	foreach ( @totconnections ) {
		s/^.*INTEGER:.//s;
	}
	foreach ( @nameconnections ) {
		s/^.*Name=//s;
		s/,ServerRuntime.*//;
	}
	foreach ( @connector ) {
		s/^.*STRING:.//s;
	}
	for ( $x = 0; $x <= $#connections; $x++ ) {
		$k=($connections[$x]+$k);
		if ( $connections[$x] >= $totconnections[$x] ) {
			$jdbcerrout = $jdbcerrout.$nameconnections[$x]." ";
			$crit++;
			$health++;
		}	    
	}
	for ( $x = 0; $x <= $#connector; $x++ ) {
		if ( $connector[$x] !~ "Running") {
		$crit++;
		$errout= $errout.$nameconnections[$x]." is $connector[$x]. ";
		}
		else {
		$jdbcnum++;
		}
	}

$strout = $strout.", $jdbcnum active JDBC connectors with $k connections";

if ($jdbcerrout) {
	$errout= $errout."JDBC connector(s) $jdbcerrout"."reached max connections. ";
	}
}
else {
	$crit++;
	$errout= $errout."No JDBC Connectors Running. ";
}

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
		$perfout=$perfout."'$lheapname[$x]'=".(100-$lheap[$x])."%;;90;0;100 ";
		if ( $lheap[$x] <= 10 ) {
			$errout = $errout."$lheapname[$x] is at $lheap[$x]% heap free. ";
		$crit++;
		$health++;
		}
	}
}

if ( $lappname ) {
	my @lappname = split (/\n/,$lappname);
	my @lappdepl = split (/\n/,$lappdepl);
	foreach ( @lappname ) {
		s/^.*STRING: .//s;
		s#_/#-#s;
		s/"//;
	}
	foreach ( @lappdepl ) {
		s/^.*STRING: .//s;
	  	s/"//;
	}
	for ( $x = 0; $x <= $#lappname; $x++ ) {
		if (( $lappname[$x] =~ m{$lapps} ) && ( $lappdepl[$x] eq "DEPLOYED" ) ) {
			$dplnum++;
		}
		elsif ( $lappname[$x] =~ m{$lapps} ) {
		$errout= $errout."$lappname[$x] is $lappdepl[$x]. ";
		$crit++;
		}
	}
  $strout= "$dplnum Apps deployed, ".$strout;
  if ( $dplnum == 0 ) { $crit++; }
}

$perfout=$perfout."'jdbc connections'=$k;;;";
$strout="$strout. | $perfout";

if ( $dplcrit ) {
	if ( $health == 0 ) { $warn=$crit; $crit=0; }
	$warnout=$errout;
	$errout="";
	if ( $dplnum != $dplcrit ) {
		$crit++;
		$errout= "Application count mismatch ($dplnum,$dplcrit). ";
	}
	if ( $runnum != $runcrit ) {
		$crit++;
		$errout= "Runtime count mismatch ($runnum,$runcrit). ".$errout;
	}
	if ( $jdbcnum != $jdbccrit ) {
		$crit++;
		$errout= "JDBC count mismatch ($jdbcnum,$jdbccrit). ".$errout;
	}
if ( $crit != 0 ) {
        print "Error: $errout$warnout\n";
        print "$strout\n";
        exit $STATE_CRITICAL;
}
elsif ( $warn != 0 ) {
        print "Warning: $warnout\n";
        print "$strout\n";
	exit $STATE_WARNING;
}
else {
        print "Everything OK: ";
        print "$strout\n";
	exit $STATE_OK;
}
}

if ( $crit != 0 ) {
	print "Error: $errout\n";
	print "$strout\n";
	exit $STATE_CRITICAL;
}
else { 
	print "Everything OK: ";
	print "$strout\n";
	exit $STATE_OK;
}
