Param(
    [switch]$Console = $false,          #--[ Set to true to enable local console result display. Defaults to false ]--
    [switch]$Debug = $False,            #--[ Reserved for future use ]--
    [switch]$Detail = $False,           #--[ Full detail verses brief ]--  
    [switch]$IgnoreErrors = $False      #--[ Won't report errors it encounters unless set to true ]--
)

<#==============================================================================
         File Name : DiskCleanup.ps1
   Original Author : Kenneth C. Mazie (kcmjr AT kcmjr.com)
                   : 
       Description : Clears out all specified temp folders and files on the LOCAL PC.  To be run as a scheduled task
                   : using the SYSTEM context.
                   : 
             Notes : Normal operation is with no command line options. See explenations above. 
                   : Greater-than (>) in email subject indicated free space growth
                   : Less-than (<) in email subject indicated free space loss
                   : Equals (=) in email subject indicated no space change. 
                   :
         Arguments : - $Console - Set to $true forces console messages
                   : - $Debug   - Forces debugging mode. Only sends email to debug user.  Extra console messages
                   : - $Detail  - Forces extra details in result email.
                   : - $IgnoreErrors - Forces errors to not be included in result email.
                   :
      Requirements : None.  Best with PowerShell 3 or newer but checks for version.
	               : Requires an external XML settings file.  See end of script for sample.
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
   Version History : v1.00 - 10-16-15 - Original 
    Change History : v2.00 - 10-27-15 - numerous bug fixes 
                   : v2.10 - 11-09-15 - edited log.  now outputs html.
                   : v2.20 - 07-08-20 - Added details option        
                   : v3.00 - 06-24-22 - Corrected script folder reference. Added send only if successful option. Corrected for PowerShell 
                   :                   v6 and above.  Fixed log file creation and removal. Edited log format.
                   : v3.10 - 08-03-22 - Added additional info to identify sending system.  Changed log file name.  Added debug messages.
                   :                   Added script version to log.
                   : v3.20 - 09-20-22 - Added percentages to email results.
                   : v3.30 - 10-03-22 - Added percentage change to email results.
                   : v3.40 - 10-18-22 - Added summary to header.
                   : v3.50 - 10-26-22 - Added script root path descrimination for PS versions prior to v3
                   : v3.60 - 11-16-22 - Added report header colorization to match disk space changes for report quick glance. 
                   : v3.70 - 05-09-23 - Added ASCII characters to email subject for quick glance results.  Moved email away from
                   :                   function.  Reordered script sections.  Fixed minor typos.
                   : v3.80 - 05-11-23 - Removed invalid characters from email subject.  Moved settings out to XML file.
                   : v3.90 - 05-12-23 - Added checks for PS version to aloow running on older OS ver.  
                   : v3.91 - 05-15-23 - Corrected issue with email subject when space grows.
                   : v3.92 - 05-18-23 - Corrected a typo with recalling recipients from XML
==============================================================================#>

$ScriptVer = "v3.92"
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

#--[ Operational Variables ]--
$ScriptName = $MyInvocation.MyCommand.Name   #--[ Not used currently ]--
$ScriptFullPath = $PSScriptRoot+"\"+$MyInvocation.MyCommand.Name 
$ConfigFile = $Script:ScriptFullPath.Split(".")[0]+".xml"
$SendIt = $false
$Datetime = Get-Date -Format "MM-dd-yyyy_HHmm"
$Target = $Env:COMPUTERNAME
$Email = New-Object System.Net.Mail.MailMessage

Function StatusMsg ($Msg, $Color, $Debug){
    If ($Null -eq $Color){
        $Color = "Magenta"
    }
    If ($Debug){
        Write-Host "-- Script Debug: $Msg" -ForegroundColor $Color
    }Else{
        Write-Host "-- Script Status: $Msg" -ForegroundColor $Color
    }
    $Msg = ""
}

#--[ Read and load configuration file ]-----------------------------------------
If (!(Test-Path $Script:ConfigFile)){       #--[ Error out if configuration file doesn't exist ]--
    Write-Host "---------------------------------------------" -ForegroundColor Red
    Write-Host "--[ MISSING CONFIG FILE. Script aborted. ]--" -ForegroundColor Red
    Write-Host "---------------------------------------------" -ForegroundColor Red    
    break
}Else{
    [xml]$Configuration = Get-Content $ConfigFile       
    $IPPattern = $Configuration.Settings.IPPattern   #--[ Used for system IP identification ]--
    $SmtpServer = $Configuration.Settings.SMTPServer
    $Domain = $Configuration.Settings.Domain
    $DebugUser = $Configuration.Settings.DebugUser+"@"+$domain
    $Email.To.Add($DebugUser)  #--[ The "main" user who always gets an email ]--
    ForEach($Recipient in $Configuration.Settings.Users.User){   
        If (!($Debug)){
            $Email.To.Add("$Recipient@$Domain")   #--[ Each other user to get the email when not debugging ]--
        }Else{
            StatusMsg "Email recipient = $Recipient" yellow debug
        }
    }
    $Alternates = @{}  
    ForEach($Item in $Configuration.Settings.Alternates.Alternate){
        $Alternates.Add($Item.Name,$Item.Display)  #--[ Alternate target names to use in the email ]--
        If ($Item.Name -eq $Target){
            $Email.From = $Item.Display+"@"+$Domain 
        }Else{
            $Email.From = $Target+"@"+$Domain 
        }
    }    
}

If ($PSVersionTable.PSVersion.Major -lt 3){
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

If ($Debug){
    StatusMsg "Debug user = $DebugUser" yellow debug
    StatusMsg "IP pattern = $IPPattern" yellow debug
    StatusMsg "SMTP server = $SmtpServer" yellow debug
    StatusMsg "List of target systems =" yellow debug
    $Alternates 
}

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
    $Disk = Get-CimInstance Win32_LogicalDisk | Where-Object{$_.DeviceID -eq 'C:'}
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
    $Email.Subject = "(<) Diskspace Cleanup Results on $ENV:computername"
    If ($Console -or $Debug){
        write-host  "-- Free disk space decrease of $Delta GB" -ForegroundColor Red
    }
}ElseIf ($FinalFree -gt $InitialFree){                            #--[ Free space increase ]-- 
    $Delta = [Math]::Round(($FinalFree-$InitialFree),2)
    $HeaderData += '<font color=green>'
    $SummaryData += "<font color=green>  -- Free disk space increase of $Delta GB<br>"
	$Email.Subject = "(>) Diskspace Cleanup Results on $ENV:computername"
    If ($Console -or $Debug){
        write-host "-- Free disk space increase of $Delta GB" -ForegroundColor Green
    }
}Else{
    $SummaryData += "<font color=darkcyan>  -- No change in free disk space...<br>" 
    $Email.Subject = "(=) Diskspace Cleanup Results on $ENV:computername"
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
    $SMTP = new-object System.Net.Mail.SmtpClient($SmtpServer+"."+$Domain)
    $Email.Body = $FinalData
    $Email.IsBodyHtml = $true
    $SMTP.Send($Email)
    $Email.Dispose()
    $SMTP.Dispose()    
    If ($Console){write-host "Sending Email." -ForegroundColor Green}
}Else{
    If ($Console){write-host "Not Sending Email." -ForegroundColor Red}
}

If ($Console){write-host "--- Process Completed ---" -ForegroundColor Red}


<#===[ Sample of XML settings file.  To be named same as the script and located in the scripot folder ]===

<?xml version="1.0" encoding="UTF-8"?>
<Settings>
  <SMTPServer>mymailsvr</SMTPServer>
  <Domain>mydomain.com</Domain>
  <IPPattern>192.168*</IPPattern>
  <!--  The debug user ALWAYS gets an email -->
  <DebugUser>myemail</DebugUser>
  <!--  The rest of the listed users only get an email when NOT in debug mode. -->
  <Users>
    <User>mybossemail</User>
  </Users>
  <!--  Alternates change the hostname to another display name in the email -->
  <Alternates>
    <Alternate> 
	   <Name>server01</Name>
       <Display>2nd_Floor_Server</Display>
	</Alternate>
    <Alternate>
      <Name>testbox</Name>
      <Display>The_Test_Server</Display>
    </Alternate>
  </Alternates>
</Settings>



#>