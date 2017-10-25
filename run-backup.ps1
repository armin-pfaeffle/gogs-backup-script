###################################################################################################
#                                                                                                 #
#  Script for Executing Gogs Backups                                                              #
#                                                                                                 #
#  Version: 0.1                                                                                   #
#  Date: 25.10.2017                                                                               #
#  Author: Armin Pfäffle                                                                          #
#  E-Mail mail@armin-pfaeffle.de                                                                  #
#  Web: http://www.armin-pfaeffle.de                                                              #
#                                                                                                 #
#  Gogs -- A painless self-hosted Git service                                                     #
#  https://gogs.io/                                                                               #
#                                                                                                 #
###################################################################################################


# Include configuration
. .\configuration.ps1


#
# Logs a message to the log file and outputs it if $echo is $TRUE.
#
Function Log($text, $withTimestamp = $TRUE, $echo = $TRUE)
{
	$line = ""
	if ($text) {
		$line = [string]$text
		if ($withTimestamp) {
			$now = Get-Date
			$line = "{0} {1}" -f $now, $line
		}
	}

	$line >> $logFilename
	if ($echo) {
		Write-host $line
	}
}

#
# Ensures that there is log directory given by $logDirectory. If folder does not
# exist it is created.
#
Function EnsureLogDirectory
{
	if( -not (Test-Path $logDirectory) )
	{
		New-Item $logDirectory -type directory
	}
}

#
# Checks if mail credential file exists; if not asks user for credential and saves given
# information in credential file. Password is encrypted.
#
Function EnsureMailCredentialFile
{
	If (!(Test-Path $mailCredentialFilename))
	{
		Log "Ask for mail credential"
		Try {
			$credential = Get-Credential
		} Catch {
			$ErrorMessage = $_.Exception.Message
			Write-Error $ErrorMessage
			Exit
		}

		Log "Create mail credential file"
		$encrytpedPassword = ConvertFrom-SecureString $credential.password
		$line = "{0}|{1}" -f $credential.username, $encrytpedPassword
		$line > $mailCredentialFilename

		Log "Send test mail"
		$result = SendMail $configuration["Mail"]["Subject"]["Test"] -ErrorAction Stop
		if (!$result) {
			Log "Delete credential file because of an error while sending mail. Please check you credential!"
			Remove-Item $mailCredentialFilename
		}

		Exit
	}
}

#
# Returns date from mail credential file and returns PSCredential instance.
#
Function GetMailCredential
{
	Log "Load mail credential"

	$line = Get-Content $mailCredentialFilename
	$rawCredential = $line.Split("|")
	$username = $rawCredential[0]
	$password = ConvertTo-SecureString $rawCredential[1]
	$credential = New-Object System.Management.Automation.PSCredential $username, $password
	Return $credential
}

#
# Sends mail with given subject. Adds additional text to body if $additionalBody is set.
#
Function SendMail($subject, $body = "", $prependScriptStartAndEndTimestamp = $TRUE)
{
	Log ("Sending mail '{0}'" -f $subject)

	$credential = GetMailCredential

	# Gather all needed server information
	$mail = $configuration["Mail"];
	$from = $mail["From"]
	$to = $mail["To"]
	$server = $mail["Server"]

	# Obtain subject and body
	if ($mail["Subject"]["Prefix"]) {
		$subject = "{0} {1}" -f $mail["Subject"]["Prefix"], $subject
	}

	if ($prependScriptStartAndEndTimestamp) {
		$currentTimestamp = Get-Date
		$body = "Skript started: {0}`nSkript ended: {1}`n`n{2}" -f $scriptStartedTimestamp, $currentTimestamp, $body
	}

	# Ensure that there is no problem with certificates...
	[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { return $true }

	Try {
		Send-MailMessage -From $from -To $to -Subject $subject -Body $body -SmtpServer $server -Credential $credential -UseSsl -ErrorAction Stop
		Return $TRUE
	} Catch {
		Write-Error $_.Exception
		Return $FALSE
	}

}

#
# Changes working directory to Backup Client directory, then runs the Backup Client
# and finally returns to the original working directory.
#
Function RunBackup
{
	Log "Executing backup"

	$gogs = $configuration["Gogs"]
	$options = $gogs["Options"]
	
	$executable = "{0} backup" -f $gogs["Executable"]

	if ($options["Config"]) {
		$executable = "{0} --config ""{1}""" -f $executable, $options["Config"]
	}
	if ($options["Verbose"]) {
		$executable = $executable + " --verbose"
	}
	if ($options["TempDir"]) {
		$executable = "{0} --tempdir ""{1}""" -f $executable, $options["TempDir"]
	}
	if ($options["Target"]) {
		$executable = "{0} --target ""{1}""" -f $executable, $options["Target"]
	}
	if ($options["ArchiveName"]) {
		$executable = "{0} --archive-name ""{1}""" -f $executable, $options["ArchiveName"]
	}
	if ($options["DatabaseOnly"]) {
		$executable = $executable + " --database-only"
	}
	if ($options["ExcludeRepositories"]) {
		$executable = $executable + " --exclude-repos"
	}
	
	Log ("Calling: " + $executable)	
		
	Try {
		$output = (Invoke-Expression $executable 2>&1) | Out-String
		$output = "Calling: " + $executable + "`n`n" + $output
	} Catch {
		$ErrorMessage = $_.Exception.Message
		Write-Error $ErrorMessage
		$output = "Exception: " + $ErrorMessage
	}
	
	Log $output $FALSE

	Return $output
}

#
# Returns the file size in a human readable size. If file could not be extracted from mail output
# or file does not exist, then $FALSE is returned.
#
Function GetBackupFileSize($backupOutput)
{
	$filename = GetBackupFilename $backupOutput
	if (Test-Path $filename) {
		$fileSize = (Get-Item $filename).length # in KB
		Return FormatFileSize $fileSize
	}
	Return $FALSE
}

#
# Formats file size so it is readable for humans.
#
Function FormatFileSize($size)
{
    If     ($size -gt 1TB) { Return "{0:0.00} TB" -f ($size / 1TB) }
    ElseIf ($size -gt 1GB) { Return "{0:0.00} GB" -f ($size / 1GB) }
    ElseIf ($size -gt 1MB) { Return "{0:0.00} MB" -f ($size / 1MB) }
    ElseIf ($size -gt 1KB) { Return "{0:0.00} kB" -f ($size / 1KB) }
    ElseIf ($size -gt 0)   { Return "{0:0.00} B" -f $size }
    Else                   { Return "" }
}

#
# Returns free disk space of partition where backup is stored.
#
Function GetFreeDiskSpace($backupOutput)
{
	$filename = GetBackupFilename $backupOutput
	if ($filename -ne $FALSE) {
		Try {
			$qualifier = split-path $filename -qualifier
			$filter = "name='{0}'" -f $qualifier
			$diskSpace = Get-WMIObject Win32_LogicalDisk -filter $filter | select freespace
			$freeDiskSpace = FormatFileSize $diskSpace.freespace
			Return $freeDiskSpace
		} Catch {
			$ErrorMessage = $_.Exception.Message
			Write-Error $ErrorMessage
		}
	}
	Return $FALSE
}

#
# Extracts filename of backup from backup process output.
#
Function GetBackupFilename($backupOutput)
{
	$pattern = "Archive is located at: (.*?)\.zip"
	$regex = [regex] $pattern
	$match = $regex.Match($backupOutput)
	if ($match.Success -and ($match.Groups.Count -gt 1)) {
		$filename = "{0}.zip" -f $match.Groups[1]
		Return $filename
	}
	Return $FALSE
}

#
# Prepares the body for the final notification mail. Adds the computername and the backup
# file size if backup was successful.
#
Function PrepareMailBody($successful, $backupOutput)
{
	if (!$configuration["Mail"]["AddLogToBody"]) {
		$body = ""
	} Else {
		$computername = gc env:computername
		$body = "Computername: {0}" -f $computername

		if ($successful) {
			$fileSize = GetBackupFileSize $backupOutput
			$body = "{0}`nSize of backup: {1}" -f $body, $fileSize
			
			$freeDiskSpace = GetFreeDiskSpace $backupOutput
			if ($freeDiskSpace -ne $FALSE) {
				$filename = GetBackupFilename $backupOutput
				Log $filename;
				$qualifier = split-path $filename -qualifier
				$body = "{0}`nFree disk space on ""{1}"": {2}" -f $body, $qualifier, $freeDiskSpace
			} Else {
				$body = "{0}`nFree disk space: unknown" -f $body
			}
		}

		$body = "{0}`n`n-----`n{1}" -f $body, $backupOutput
	}
	Return $body
}


###################################################################################################


$scriptStartedTimestamp = Get-Date
$mailCredentialFilename = ".\backup-client.mail-credential"

$currentDirectory = $(get-location)
$logDirectory = "{0}\log" -f $currentDirectory

$today = Get-Date -UFormat "%Y%m%d"
$logFilename = "{0}\{1}.log" -f $logDirectory, $today

EnsureLogDirectory

if ($configuration["SendMailBeforeBackup"] -or $configuration["SendMailAfterBackup"]) {
	EnsureMailCredentialFile
}

if ($configuration["SendMailBeforeBackup"]) {
	$sendResult = SendMail $configuration["Mail"]["Subject"]["Start"] " " $FALSE
}


$backupOutput = RunBackup

if ($configuration["SendMailAfterBackup"]) {
	if ($backupOutput -match " \[FATAL\] ") {
		$subject = $configuration["Mail"]["Subject"]["Error"]
		$successful = $FALSE
	} Else {
		$subject = $configuration["Mail"]["Subject"]["Success"]
		$successful = $TRUE
	}
		
	$body = PrepareMailBody $successful $backupOutput
	$sendResult = SendMail $subject $body
}
