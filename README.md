# DiskCleanup
Automatically clears out all specified temp folders and files on the LOCAL PC.  To be run as a scheduled task using the SYSTEM context.

         File Name : DiskCleanup.ps1
   Original Author : Kenneth C. Mazie (kcmjr AT kcmjr.com)
                   : 
       Description : Clears out all specified temp folders and files on the LOCAL PC.  To be run as a scheduled task
	                 : using the SYSTEM context.
                   : 
             Notes : Normal operation is with no command line options. See explenations above. 
		               :
         Arguments : - $Console - Set to $true forces console messages
		               : - $Debug   - Forces debugging mode. Only sends email to debug user.  Extra console messages
                   : - $Detail  - Forces extra details in result email.
 		               : - $IgnoreErrors - Forces errors to not be included in result email.
		               :
      Requirements : None.  Best with PowerShell 3 or newer but checks for version.
                   : 
          Warnings : Yes, it deletes files....
                   :   
             Legal : Public Domain. Modify and redistribute freely. No rights reserved.
                   : SCRIPT PROVIDED "AS IS" WITHOUT WARRANTIES OR GUARANTEES OF 
                   : ANY KIND. USE AT YOUR OWN RISK. NO TECHNICAL SUPPORT PROVIDED.
                   :
           Credits : Code snippets and/or ideas came from many sources including but 
                   :   not limited to the following:
                   : 
    Last Update by : Kenneth C. Mazie                                           
   Version History : v1.0 - 10-16-15 - Original 
    Change History : v2.0 - 10-27-15 - numerous bug fixes 
                   : v2.1 - 11-09-15 - edited log.  now outputs html.
                   : v2.2 - 07-08-20 - Added details option		
            		   : v3.0 - 06-24-22 - Corrected script folder reference. Added send only if successful option. Corrected for PowerShell 
		               :                   v6 and above.  Fixed log file creation and removal. Edited log format.
		               : v3.1 - 08-03-22 - Added additional info to identify sending system.  Changed log file name.  Added debug messages.
		               :                   Added script version to log.
		               : v3.2 - 09-20-22 - Added percentages to email results.
		               : v3.3 - 10-03-22 - Added percentage change to email results.
		               : v3.4 - 10-18-22 - Added summary to header.
		               : v3.5 - 10-26-22 - Added script root path descrimination for PS versions prior to v3
		               : v3.6 - 11-16-22 - Added report header colorization to match disk space changes for report quick glance. 
                   : v3.7 - 05-09-23 - Added ASCII characters to email subject for quick glance results.  Moved email away from
		               :                   function.  Reordered script sections.  Fixed minor typos.
