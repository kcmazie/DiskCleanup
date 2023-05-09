Param(
	[switch]$Console = $false,            #--[ Set to true to enable local console result display. Defaults to false ]--
	[switch]$Debug = $False,              #--[ Reserved for future use ]--
	[switch]$Detail = $False,             #--[ Full detail verses brief ]--  
	[switch]$IgnoreErrors = $False        #--[ Won't report errors it encounters unless set to true ]--
)

<#==============================================================================
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
==============================================================================#>
$ScriptVer = "v3.7"
#Requires -version 2
Clear-Host 

#--[ Tweaks for testing ]--
#$Console = $false #true
#$Debug = $false
$IgnoreErrors = $true
#--------------------------
# --[ Detect if running from a console or IDE, VScode in particular ]-------
If ($host.Name -like "Visual Studio*"){
	$Debug = $True
}

If ($Debug){
    $ErrorActionPreference = "stop"
	$Console = $true
}Else{
    $ErrorActionPreference = "silentlycontinue"
}

#--[ Operational Variables - ADJUST THESE ]--
$SendIt = $false
$Datetime = Get-Date -Format "MM-dd-yyyy_HHmm"
$Target = $Env:COMPUTERNAME
$IPPattern = "192.168*"            #--[ Filter for checking the local system IP ]--
$SmtpServer = "MyMailServer"
$Domain = "MyCompany.org"
$DebugUser = "MyEmailAddr"         #--[ This user ALWAYS gets the email ]--
$Recipients = @(                   #--[ These users get email when not in debug mode ]--
	"bob"
	"mygroup"
)
$SMTP = new-object System.Net.Mail.SmtpClient($SmtpServer+"."+$Domain)
$Email = New-Object System.Net.Mail.MailMessage

#--[ This section allows for different "from" name than the PC actual name, if desired. ]--
Switch ($Env:Computername){
	"PC01" {
		$Email.From = "Bob's PC@"+$Domain
	}
	"Server02" {
		$Email.From = "PrintServer2@"+$Domain
	}
	Default {
		$Email.From = $Env:Computername+"@"+$Domain
	}
}

$Email.To.Add($DebugUser+"@"+$Domain)
If (!($debug)){
	ForEach($Recipient in $Recipients){
		$Email.To.Add($Recipient+"@"+$Domain)
	}
}

If ($PSVersionTable.psversion.major -lt 3){
	$WorkDir = "c:\windows\temp"
}Else{
	$WorkDir = $PSScriptRoot
}
If ($PSVersionTable.PSVersion.Major -gt "2"){
	$ThisIP = (Get-NetIPAddress | Where-Object -FilterScript { $_.IPAddress -Like $IPPattern }).IPAddress  
}Else{
	$ThisIP = [net.dns]::GetHostAddresses("") | Select-Object -ExpandProperty IPAddressToString | Where-Object {$_ -notlike "*::*"}
}
If (!(Test-path -Path $WorkDir)){[System.IO.Directory]::CreateDirectory($WorkDir) | Out-Null}                 #--[ Create the scripts folder if needed ]--
If (!(Test-path -Path "$WorkDir\logs")){[System.IO.Directory]::CreateDirectory("$WorkDir\logs") | Out-Null}   #--[ Create the logs folder if needed ]--
$LogFile = $WorkDir+"\logs\DiskCleanupLog-"+$DateTime+".html"                                                          #--[ Define the current log file ]--
#--[ This next line detects the log files and deletes all except the most recent 9 ]--
Get-ChildItem -Path "$WorkDir\logs" -Include * | Where-Object { -not $_.PsIsContainer } | Where-Object { $_.name -like "*.html"} | Sort-Object -Descending -Property CreationTime | Select-Object -Skip 9 | Remove-Item 		

$FileTypes = ""
$LogData = ""
$HeaderData = ""
$SummaryData = ""
$FinalData

#--[ This list contains file extentions to scan for ]---------------------------
$FileTypes = @(  
"*.tmp",
"*.dmp",
"*.temp",
"*.dump",
"*.cab",  
"*.log",
"*.chk"
)

#--[ This list contains folders to purge.  The folder itself is not deleted ]---
$FolderLocations = @(
"C:\Temp",
"C:\Windows\Temp",
"C:\Windows\Log",
"C:\Windows\Logs",
"C:\Windows\System32\winevt\Logs", 
$Env:TEMP,
$Env:TMP 
)

#==================================================================#>
$HeaderData += '<HTML>'
$HeaderData += '<table class="myTable">'
#--[ Remainder of header is at end of script ]--

If ($Debug){
	$LogData += '<tr class="noBorder"><td><center><font color=darkred>--- Script is running in DEBUG mode.  No files will be deleted. ---</font></td></tr></Center>'
}
$LogData += '<tr class="noBorder"><td><br> --- Begin File Purge at '+$Datetime+' ---<br><br>'

If ($PSversionTable.PSVersion.Major -ge 6){
	$Disk = Get-CimInstance Win32_LogicalDisk | where{$_.DeviceID -eq 'C:'}
}Else{
	$Disk = Get-WmiObject Win32_LogicalDisk -ComputerName "." -Filter "DeviceID='C:'" #| Foreach-Object {$_.Size,$_.FreeSpace}
}
$DiskSize = [math]::round(($Disk.Size/1GB),2)
$InitialFree = [math]::round(($Disk.FreeSpace/1GB),2)

#--[ All TARGETED Folders ]-----------------------------------------------------
ForEach ($Script:Folder in $Script:FolderLocations){
	If ($Script:Detail){
		$LogData += "<br><font color=Black>-- Checking folder $Script:Folder...<br>"
	}		
	if (Test-Path -Path $Script:Folder ){	
        #--[ All TEMP File Types ]------------------------------------------------------
        ForEach ($Type in $FileTypes){
			If ($Script:Detail){
				$LogData += "<font color=darkcyan>&nbsp&nbsp-- Checking file type $Type...<br>"
			}
            $Targets = get-childitem -path $Script:Folder -include $Type -recurse -ErrorAction SilentlyContinue
            If ($Targets.count -ne 0){
	            foreach ($Target in $Targets){
		            $ErrorMessage = ""
		            try{
						If ($Debug){
	                        If(remove-item $Target -ErrorAction Stop -Confirm:$false -Force:$true -Recurse:$true -WhatIf | Where {!$Target.PSIsContainer } ){
                            	#$LogData += "<font color=darkgreen>&nbsp&nbsp-- Removed $Target --<br>"
								$SendIt = $true
							}
						}Else{
	                        If(remove-item $Target -ErrorAction Stop -Confirm:$false -Force:$true -Recurse:$true | Where {!$Target.PSIsContainer } ){
                            	#$LogData += "<font color=darkgreen>&nbsp&nbsp-- Removed $Target --<br>"
								$SendIt = $true
                        	}
						}
		            }Catch{
						$ErrorMessage = $_.Exception.Message
						If ($ErrorMessage -like "*null*"){
							If ($Script:Detail){
								$LogData += "<font color=darkred>&nbsp&nbsp&nbsp&nbsp -- File type not found in target path. -- $Target<br>"
							}
						}Else{
							If (!($IgnoreErrors)){   #--[ Selects whether errors are included in log ]--
				            	$LogData += "<font color=darkred>&nbsp&nbsp&nbsp&nbsp-- Delete Failed -- $Target<br>"
								If ($ErrorMessage){
									$SendIt = $True
									If ($ErrorMessage -like "*used by another*"){
										$LogData += "&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp---- Error Message = File is being used by another process.<br>"
									}Else{
										$LogData += "&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp---- Error Message = $ErrorMessage<br>"
									}							
								}
							}
						}
		            }
                    If ($ErrorMessage -eq ""){
						If ($Debug){
							$LogData += "<font color=darkgreen>&nbsp&nbsp&nbsp&nbsp-- Simulated Delete -- $Target<br>"
						}Else{
							$LogData += "<font color=darkgreen>&nbsp&nbsp&nbsp&nbsp-- Deleted -- $Target<br>"
						}
						$SendIt = $True
					}
                }
	        }Else{
		        If ($Script:Detail){
					$LogData += "<font color=orange>&nbsp&nbsp&nbsp&nbsp-- No files of type $Type found...<br>"
				}
			}
        }
	}Else{
		If ($Script:Detail){$LogData += "<font color=orange>&nbsp&nbsp&nbsp&nbsp-- $Script:Folder folder NOT found...<br>" }
	}
}

If ($PSversionTable.PSVersion.Major -ge 6){
	$Disk = Get-CimInstance Win32_LogicalDisk | where{$_.DeviceID -eq 'C:'}
}Else{
	$Disk = Get-WmiObject Win32_LogicalDisk -ComputerName "." -Filter "DeviceID='C:'" #| Foreach-Object {$_.Size,$_.FreeSpace}
}

$FinalFree = [math]::round(($Disk.FreeSpace/1GB),2)
$Percent1 = ($InitialFree/$DiskSize).ToString("P")
$Percent2 = ($FinalFree/$DiskSize).ToString("P")

$LogData += "<br><font color=darkcyan>-- C: drive size&nbsp&nbsp : $DiskSize GB<br>"
$LogData += "-- C: drive INITIAL free space&nbsp&nbsp : $InitialFree GB  ($Percent1 of total disk)<br>"
$LogData += "-- C: drive FINAL free&nbsp&nbsp&nbsp     : $FinalFree GB  ($Percent2 of total disk)<br>" 
If ($Console -or $Debug){
	write-host "-- C: drive size               : $DiskSize GB" -ForegroundColor Yellow
	write-host "-- C: drive INITIAL free space : $InitialFree GB  ($Percent1) of total disk)" -ForegroundColor Yellow
	write-host "-- C: drive FINAL free         : $FinalFree GB  ($Percent2) of total disk)" -ForegroundColor Yellow
}

#--[ Font color adjustments ]--
$HeaderData += '<tr class="noBorder"><td><center><h1>'
If ($InitialFree -gt $FinalFree){                                 #--[ Free space decrease ]--
	$Delta = [Math]::Round(($FinalFree-$InitialFree),2)
	$HeaderData += '<font color=red>'
   	$SummaryData += "<font color=red>  -- Free disk space decrease of $Delta GB<br>"  
    $Email.Subject = "▼ Diskspace Cleanup Results on $ENV:computername"
	If ($Console -or $Debug){
		write-host  "-- Free disk space decrease of $Delta GB" -ForegroundColor Red
	}
}ElseIf ($FinalFree -gt $InitialFree){                            #--[ Free space increase ]-- 
	$Delta = [Math]::Round(($FinalFree-$InitialFree),2)
	$HeaderData += '<font color=green>'
	$SummaryData += "<font color=green>  -- Free disk space increase of $Delta GB<br>"
	$Email.Subject = "▲ Diskspace Cleanup Results on $ENV:computername"
	If ($Console -or $Debug){
		write-host "-- Free disk space increase of $Delta GB" -ForegroundColor Green
	}
}Else{
	$SummaryData += "<font color=darkcyan>  -- No change in free disk space...<br>" 
	$Email.Subject = "- Diskspace Cleanup Results on $ENV:computername"
	If ($Console -or $Debug){
		$HeaderData += '<font color=darkcyan>'  #--[ Only change the color for debugging.  Move this line up for always change. ]--
		write-host "-- No change in free disk space..." -ForegroundColor Yellow
	}
}

$LogData += $SummaryData
$LogData += "<font color=red><br>--- Completed ---" 
$LogData += '</td></table></html>'

Add-Content $LogFile $LogData -ErrorAction:Stop

$HeaderData += '- Diskspace Cleanup Report -<font color=black></h1></td></tr>'
$HeaderData += '<tr class="noBorder"><td><center>The following report displays the temp and log files deleted from PC "'+$Env:Computername+'".</td></tr>'
$HeaderData += '<tr class="noBorder"><td><center>System IP address: '+$ThisIP+'</td></tr>'
$HeaderData += '<tr class="noBorder"><td><center>Script Version: '+$ScriptVer+'</td></tr></Center>'

$FinalData = $HeaderData
$FinalData += "<center>Process Summary"
$FinalData += $SummaryData
$FinalData += "</center>"
$FinalData += $LogData

If ($SendIt){
	$Email.Body = $FinalData
	$Email.IsBodyHtml = $true
	$Email.From = $FromWho 
	$SMTP.Send($Email)
	$Email.Dispose()
	$SMTP.Dispose()	
	If ($Console){write-host "Sending Email."}
}Else{
	If ($Console){write-host "Not Sending Email."}
}

