# nagios-Weblogic_health
Weblogic server check via snmp/n


Can alert based on overall system health or you can specify the required status of the server.  
In example specify a critical scenario where less than (x) applications, servers or jdbc connectors are running.


Monitors:

Number and health of applications deployed

Number and health of runtimes deployed

Number and health of JDBC connectors including connection count

jVM server health and heap size

Performance Data:

jVM Heap Size

Total number of current JDCB connections


Example command

$USER1$/MyWeblogic $HOSTADDRESS$:$ARG1$ $ARG2$ $ARG3$


$ARG1$ = Port

$ARG2$ = community string

$ARG3$ = blank or used to specify critical scenario (#apps #runtimes #jdbc)
