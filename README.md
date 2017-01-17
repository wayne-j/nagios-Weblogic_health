# nagios-Weblogic_health
Oracle Weblogic server checks via snmp


Can alert based on overall system health or you can specify the required status of the server.  
In example specify a critical scenario where less than (x) applications, servers or jdbc connectors are running.

## Monitors:

Number and health of applications deployed  
Number of application user sessions  
Number and health of runtimes deployed  
Number and health of JDBC connectors including connection count  
JVM server health and heap usage  

## Performance Data:

JVM Heap usage  
Total number of current JDCB connections  
Total number of (user)sessions  

## Usage
```
 weblogic_health.pl -H hostname [-P port] [-C community] [-h] [-d] [-f] [-a int][-n str][-u str] [-r int][-m %] [-j int]
 Version: 0.5

 -h|--help          This help screen
 -H|--hostname      Hostname to send query.
 -P|--port          Port where SNMP server is listening [Default: 165]
 -C|--community     SNMP Community [Default: public]
 -a|--appscount     Check for number of deployed applications
 -n|--appname         Filter deployed applications, separated by "|", eg "fooapp|fooapp2"
 -u|--urifilter       Default only apps running weburi "formsweb.war" and "web.war" are counted, as most
                      other apps are system apps.  If you want to monitor those too, you can give a new
                      filter here. (without value all apps are selected. You can also use | to separate.)
 -r|--runtime       Check for number of Weblogic JVM Runtimes.
 -m|--minheapfree   Maximum allowed percentage Runtime JVM heapspace. [Default 10]
 -j|--jdbccount     Check number of JDBC connectors.
 -f|--perf          Show perfdata JVM heapspace, JDBC and app-user-sessions.
 -d|--debug         Activate debug mode.
```
You might have to play around with port numbers. If you enable SNMP, each JVM seems to have it's own port number, but there's also one port which gives all JVM's data. Just play around.

## Enable SNMP in Weblogic.

Before you can use this plugin, you need to enable SNMP in Weblogic. In short, this is how that goes:

* Start Weblogic Administration Console.
* First click in  the left ‘Change Center’ - ‘Lock & Edit’  to edit your config.
* Click on domain structure : frdomain - Diagnostics – SNMP
* Create in tab ‘Agents’, under ‘Server SNMP Agents’ – ‘New’ a new Agent:
* Tab Configuration – General:
 * Click ‘Enabled’ to enable the agent.
 * Select SNMP UDP port, if you’re host is already running SNMP, you could change this to 163. (default 161)
 * Enable Cummunity Based Acces, en give your Community Prefix (default public)
 * Disable traps if you don’t use it.
* Tab Targets:
 * Select the servers that you want this SNMP agent to monitor.
 * Klik Save.
* Finally click in ‘Change Center’ - ‘Activate Changes’ to save and activate your new config.
