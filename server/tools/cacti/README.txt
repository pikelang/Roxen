Author:  Marcus Wellhardh, Roxen Internet Software AB, 2007-11-12
Version: 2.0

ABOUT
-----

This package can be used to create graphs in cacti that monitors a
Roxen Webserver, Roxen CMS or a Roxen Editorial Portal server. The
package contains about 70 graphable data sources. Some examples:

  - Requests per second
  - Transfered bytes
  - MySQL queries

The templates fetch data via the SNMP protocol. You will have to
enable SNMP on the Roxen servers that should be monitored.

A short introduction to cacti can be fond on cacti.net:

  Cacti is a complete network graphing solution designed to harness
  the power of RRDTool's data storage and graphing functionality.


FILES
-----

  README.txt
  
    - This text file
    
  cacti_host_template_roxen_mib_editorial_portal.xml
  
    - Cacti export of the Roxen MIB host template
    
  roxen-mib_core.xml
  
    - Data Query for Roxen MIB Core, fetches indexed info from virtual
      servers
    
  roxen-mib_feed.xml
  
    - Data Query for Roxen MIB Feed, fetches indexed info from feed
      modules


REQUIREMENTS
------------

  The templates were created and tested on cacti version 0.8.7e. The
  templates might be compatible with earlier versions. Cacti can be
  downloaded from:

    http://cacti.net/


INSTALL
-------

  Make sure the cacti installation works as intended.

  Make sure the SNMP support is enabled on the Roxen servers that
  should be monitored.

  Copy "roxen-mib_core.xml" and "roxen-mib_feed.xml" to the
  "resource/snmp_queries" directory in the cacti installation, this is
  typically the following directory:

    /usr/share/cacti/resource/snmp_queries

  Import the "cacti_host_template_roxen_mib_editorial_portal.xml" file
  into cacti via the "Import Templates" function.

  Create a device that should be monitored. For example:

    Description:    "PRINT example.roxen.com"
    Hostname:       "example.roxen.com"
    Host Template:  "Roxen MIB - Editorial Portal"
    SNMP Community: "public"
    SNMP Port:      "16180"

  Create appropriate graphs for the device.


CONTENTS
--------

  This package of cacti templates contains the following:

  Host Templates:
  
    Roxen MIB - Editorial Portal
  
  Data Queries:
  
    Roxen MIB - Core
    Roxen MIB - Feed
  
  Graph Templates:
  
    Roxen MIB - Site - Requests
    Roxen MIB - Site - Runs
    Roxen MIB - Site - Runs (log)
    Roxen MIB - Site - Time
    Roxen MIB - Site - Traffic (bytes/sec)
    
    Roxen MIB - Core - BG Queue Size
    Roxen MIB - Core - BG Runs
    Roxen MIB - Core - BG Runs (log)
    Roxen MIB - Core - BG Time
    Roxen MIB - Core - BG Time per run
    Roxen MIB - Core - Backtraces
    Roxen MIB - Core - CO Queue Size
    Roxen MIB - Core - CO Runs
    Roxen MIB - Core - CO Runs (log)
    Roxen MIB - Core - CO Time
    Roxen MIB - Core - CO Time per run
    Roxen MIB - Core - CPU
    Roxen MIB - Core - Handler Queue Size
    Roxen MIB - Core - Handler Runs
    Roxen MIB - Core - Handler Runs (log)
    Roxen MIB - Core - Handler Time
    Roxen MIB - Core - Handler Time per run
    Roxen MIB - Core - Requests   	
    Roxen MIB - Core - Traffic (bytes/sec)
    Roxen MIB - Core - Uptime

    Roxen MIB - MySQL - Connections 	
    Roxen MIB - MySQL - Queries 	
    Roxen MIB - MySQL - Slow Queries 	
    Roxen MIB - MySQL - Uptime

    Roxen MIB - Feed - Last Import 	
    Roxen MIB - Feed - Minimum Disk Space 	
    Roxen MIB - Feed - Scan Time
    Roxen MIB - Feed - Scan Time per monitor
    Roxen MIB - Feed - Scan Time per run
    Roxen MIB - Feed - Scanned Files 	
    Roxen MIB - Feed - Scanned Monitors
    Roxen MIB - Feed - Scans
    Roxen MIB - Feed - Total Last Import 	
    Roxen MIB - Feed - Total Scanned Files

    Roxen MIB - Print - Action Time
    Roxen MIB - Print - Action Time per run
    Roxen MIB - Print - Actions
    Roxen MIB - Print - Actions (log)
    Roxen MIB - Print - Available Disk Space 	
    Roxen MIB - Print - Backup Disk Space 	
    Roxen MIB - Print - Backup Errors 	
    Roxen MIB - Print - Backup Idle Time 	
    Roxen MIB - Print - Backup Operations 	
    Roxen MIB - Print - Backup Queue Length 	
    Roxen MIB - Print - Editions 	
    Roxen MIB - Print - Feed Items 	
    Roxen MIB - Print - Issues 	
    Roxen MIB - Print - Page Versions 	
    Roxen MIB - Print - Pages 	
    Roxen MIB - Print - RAL Operations
    Roxen MIB - Print - RAL Traffic
    Roxen MIB - Print - Stories 	
    Roxen MIB - Print - Story Item Versions 	
    Roxen MIB - Print - Story Items
    
    Roxen MIB - Clients - Bad User Applications
    Roxen MIB - Clients - Browser Users
    Roxen MIB - Clients - RAL Users
    Roxen MIB - Clients - RMC Users

    Roxen MIB - InDesign - Queue Size
    Roxen MIB - InDesign - Queue Time
    Roxen MIB - InDesign - Request Time
    Roxen MIB - InDesign - Request Time per run
    Roxen MIB - InDesign - Requests


