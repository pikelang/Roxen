Author:  Marcus Wellhardh, Roxen Internet Software AB, 2007-11-12
Version: 1.0

ABOUT
-----

This package can be used to create graphs in cacti that monitors a
Roxen Webserver, Roxen CMS or a Roxen Editorial Portal server. The
package contains about 20 graphable data source, some examples:

  - Requests per second
  - Transfered bytes
  - MySQL queries

The templates fetches data via the SNMP protocol. You will have to
enable SNMP on the Roxen server that should be monitored.

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

  The templates was created and tested on cacti version 0.8.6j. The
  templates might be compatible with earlier versions. Cacti can be
  downloaded from:

    http://cacti.net/


INSTALL
-------

  Make sure the cacti installation works as intended.

  Make sure the SNMP support is enabled on the Roxen server that
  should be monitored

  Copy "roxen-mib_core.xml" and "roxen-mib_feed.xml" to the
  "resource/snmp_queries" directory in the cacti installation, this is
  typically the following directory:

    /usr/share/cacti/resource/snmp_queries

  Import the "cacti_host_template_roxen_mib_editorial_portal.xml" file
  into cacti via the "Import Templates" function.

  Create a device that should be monitored, example:

    Description:    "PRINT metro.roxen.com"
    Hostname:       "metro.roxen.com"
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
  
    Roxen MIB - Core - Requests   	
    Roxen MIB - Core - Traffic (bytes/sec) 	
    Roxen MIB - Feed - Last Import 	
    Roxen MIB - Feed - Minimum Disk Space 	
    Roxen MIB - Feed - Scanned Files 	
    Roxen MIB - Feed - Total Last Import 	
    Roxen MIB - Feed - Total Scanned Files 	
    Roxen MIB - MySQL - Connections 	
    Roxen MIB - MySQL - Queries 	
    Roxen MIB - MySQL - Slow Queries 	
    Roxen MIB - MySQL - Uptime 	
    Roxen MIB - Print - Actions 	
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
    Roxen MIB - Print - Stories 	
    Roxen MIB - Print - Story Item Versions 	
    Roxen MIB - Print - Story Items
  
  Data Templates:
  
    Roxen MIB - Core
    Roxen MIB - Core - Uptime
    Roxen MIB - Feed
    Roxen MIB - Feed - lastImport
    Roxen MIB - Feed - minFeedDiskCapacity
    Roxen MIB - Feed - minFeedDiskFree
    Roxen MIB - Feed - minFeedDiskUsage
    Roxen MIB - Feed - pendingDeletionsTotal
    Roxen MIB - Feed - pendingFilesTotal
    Roxen MIB - Feed - scannedFilesTotal
    Roxen MIB - MySQL - Connections
    Roxen MIB - MySQL - Queries
    Roxen MIB - MySQL - Slow Queries
    Roxen MIB - MySQL - Uptime
    Roxen MIB - Print - backupDiskCapacity
    Roxen MIB - Print - backupDiskFree
    Roxen MIB - Print - backupDiskUsed
    Roxen MIB - Print - backupErrors
    Roxen MIB - Print - backupIdleTime
    Roxen MIB - Print - backupOperations
    Roxen MIB - Print - backupQueueLength
    Roxen MIB - Print - databaseDiskCapacity
    Roxen MIB - Print - databaseDiskUsed
    Roxen MIB - Print - databaseFreeDisk
    Roxen MIB - Print - numActions
    Roxen MIB - Print - numEditions
    Roxen MIB - Print - numFeedItems
    Roxen MIB - Print - numIssues
    Roxen MIB - Print - numPages
    Roxen MIB - Print - numPageVersions
    Roxen MIB - Print - numStories
    Roxen MIB - Print - numStoryItems
    Roxen MIB - Print - numStoryItemVersions
