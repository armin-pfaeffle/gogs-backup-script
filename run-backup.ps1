###################################################################################################
#                                                                                                 #
#  Script for Executing Gogs Backups                                                              #
#                                                                                                 #
#  Version: 0.2                                                                                   #
#  Date: 04.12.2017                                                                               #
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



Function Log($text, $withTimestamp = $true, $echo = $true)
{
	$line = ""
	If ($text) {
		$line = [string]$text
		If ($withTimestamp) {
			$now = Get-Date
			$line = "{0} {1}" -f $now, $line
		}
	}

	$line >> $logFilename
	If ($echo) {
		Write-Host $line
	}
}

Function EnsureLogDirectory
{
	If (!(Test-Path $logDirectory))
	{
		New-Item $logDirectory -type directory
	}
}



Function EnsureCredentialFile($type)
{
	$filename = GetCredentialFilename $type
	If ($filename -eq "") {
		Return "false"
	}
		
	If (!(Test-Path $filename))
	{
		Log ("Ask for credential, type: {0}" -f $type)
		
		$message = GetCredentialDialogMessage $type
		Try {
			$credential = Get-Credential -Message $message
			If ($credential -eq $null) {
				Log "Cancelled"
				Return "false"
			}
		} Catch {
			Write-Error $_.Exception
			Log $_.Exception.Message
			Return "false"
		}
		
		Log "Create credential file"
		$encrytpedPassword = ConvertFrom-SecureString $credential.password
		$line = "{0}|{1}" -f $credential.username, $encrytpedPassword
		$line > $filename
		Return "created"
	}
	Return "existant"
}

Function GetCredentialFromFile($type)
{
	$filename = GetCredentialFilename $type
	If ($filename -eq "") {
		Log "Invalid credential type"
		Return $false
	}
	
	If (!(Test-Path($filename))) {
		Log "Credential file does not exist"
		Return $false
	}

	$line = Get-Content $filename
	$rawCredential = $line.Split("|")
	$username = $rawCredential[0]
	$password = ConvertTo-SecureString $rawCredential[1]
	$credential = New-Object System.Management.Automation.PSCredential $username, $password
	Return $credential
}

Function GetCredentialFilename($type)
{
	$filename = ""
	switch ($type) 
    { 
        "mail" { $filename = $mailCredentialFilename }
        "ssh"  { $filename = $sshCredentialFilename  }
		default { Log ("Invalid credential type: {0}" -f $type) }
	}
	Return $filename
}

Function GetCredentialDialogMessage($type)
{
	$message = $null
	switch ($type) 
    { 
        "mail" { $message = "Enter the MAIL credential:" }
        "ssh"  { $message = "Enter the SSH credential:"  }
		default { Log ("Invalid credential type: {0}" -f $type) }
	}
	Return $message
}



Function TestMailCredential
{
	Log "Send test mail"
	$result = SendMail $configuration["Mail"]["Subject"]["Test"] " " $false
	If (!$result) {
		$filename = GetCredentialFilename "mail"
		If ($filename -and (Test-Path $filename)) {
			Log "Delete credential file because of an error while sending mail. Please check your credential!"
			Remove-Item $filename
		}
		Return $false
	}
	Return $true
}

Function SendMail($subject, $body = "", $prependScriptStartAndEndTimestamp = $true)
{
	Log ("Send mail '{0}'" -f $subject)

	$credential = GetCredentialFromFile "mail"
	If ($credential -eq $false) {
		Return $false
	}

	$mail = $configuration["Mail"];
	$from = $mail["From"]
	$to = $mail["To"]
	$server = $mail["Server"]

	If ($mail["Subject"]["Prefix"]) {
		$subject = "{0} {1}" -f $mail["Subject"]["Prefix"], $subject
	}
	If ($prependScriptStartAndEndTimestamp) {
		$currentTimestamp = Get-Date
		$body = "Skript started: {0}`nSkript ended: {1}`n`n{2}" -f $scriptStartedTimestamp, $currentTimestamp, $body
	}

	# Ensure that there is no problem with certificates...
	[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { return $true }

	Try {
		Log ("Sending mail -- from: {0}, to: {1}, server: {2}" -f $from, $to, $server)
		Send-MailMessage -From $from -To $to -Subject $subject -Body $body -SmtpServer $server -Credential $credential -UseSsl -ErrorAction Stop
		Return $true
	} Catch {
		Write-Error $_.Exception
		Log $_.Exception.Message
		Return $false
	}
}

Function PrepareBackupMailBody($successful, $backupOutput)
{
	If (!$configuration["Mail"]["AddLogToBody"]) {
		$body = ""
	} Else {
		$computername = gc env:computername
		$body = "Computername: {0}" -f $computername

		If ($successful) {
			$fileSize = GetBackupFileSize $backupOutput
			$body = "{0}`nSize of backup: {1}" -f $body, $fileSize
			
			$freeDiskSpace = GetFreeDiskSpace $backupOutput
			If ($freeDiskSpace -ne $false) {
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



Function CheckPoshSSHInstallation
{
	If (!(Get-Module -ListAvailable -Name Posh-SSH)) {
		Log "You must install Posh-SSH before you can use SSH upload. Use command 'Find-Module Posh-SSH | Install-Module' in administrator mode to install this module."
		Return $false
	}
	Return $true
}

Function TestSSHCredentials
{
	Log "Test SSH connection"
	
	If (!(CheckPoshSSHInstallation)) {
		Return $false
	}

	$credential = GetCredentialFromFile "ssh"
	If ($credential -eq $false) {
		Return $false
	}
	
	$computerName = $configuration["UploadToSSH"]["ComputerName"]
	$result = New-SSHSession -ComputerName $computerName -Credential $credential
	If ($?) {
		Log "SSH connection successfully tested"
		Remove-SSHSession -Index 0
		Return $true
	}
	else {
		Log ("SSH connecting failed: {0}" -f $error[0].ToString())
		$filename = GetCredentialFilename "ssh"
		If ($filename -and (Test-Path $filename)) {
			Log "Delete credential file because of an error while testing SSH access. Please check your credential!"
			Remove-Item $filename
		}
		Return $false
	}
}

Function UploadToSSH($backupOutput)
{
	Log "Start SSH upload"
	
	If (!(CheckPoshSSHInstallation)) {
		Return $false
	}
	
	$credential = GetCredentialFromFile "ssh"
	If ($credential -eq $false) {
		Return $false
	}
	
	$backupFilename = GetBackupFilename $backupOutput
	$remotePath = $configuration["UploadToSSH"]["TargetDirectory"]
	$computerName = $configuration["UploadToSSH"]["ComputerName"]
	
	Try {
		Set-SCPFile -LocalFile $backupFilename -RemotePath $remotePath -ComputerName $computerName -Credential $credential
		If ($?) {
			Log "File successfully transfered"
			Remove-SSHSession -Index 0
			Return $true
		}
		else {
			$errorMessage = "SSH upload failed: {0}" -f $error[0].ToString()
			Log $errorMessage
			Return $errorMessage
		}
	}
	Catch {
		Write-Error $_.Exception
		Log $_.Exception.Message
		Return $_.Exception.Message
	}
}

Function DeleteLocalBackupFile($backupOutput)
{
	$backupFilename = GetBackupFilename $backupOutput
	If ($backupFilename -and (Test-Path $backupFilename)) {
		Log "Delete local backup file"
		Remove-Item $backupFilename
	}
}



Function RunBackup
{
	Log "Executing backup"

	$executable = PrepareBackupExecutableString
	Log ("Calling: " + $executable)	
		
	Try {
		$output = (Invoke-Expression $executable 2>&1) | Out-String
		$output = "Calling: " + $executable + "`n`n" + $output
	} Catch {
		Write-Error $_.Exception
		$output = "Exception: " + $_.Exception.Message
	}
	
	Log $output $false

	Return $output
}

Function PrepareBackupExecutableString
{
	$gogs = $configuration["Gogs"]
	$options = $gogs["Options"]
	
	$executable = "{0} backup" -f $gogs["Executable"]

	If ($options["Config"]) {
		$executable = "{0} --config ""{1}""" -f $executable, $options["Config"]
	}
	If ($options["Verbose"]) {
		$executable = $executable + " --verbose"
	}
	If ($options["TempDir"]) {
		$executable = "{0} --tempdir ""{1}""" -f $executable, $options["TempDir"]
	}
	If ($options["Target"]) {
		$executable = "{0} --target ""{1}""" -f $executable, $options["Target"]
	}
	If ($options["ArchiveName"]) {
		$executable = "{0} --archive-name ""{1}""" -f $executable, $options["ArchiveName"]
	}
	If ($options["DatabaseOnly"]) {
		$executable = $executable + " --database-only"
	}
	If ($options["ExcludeRepositories"]) {
		$executable = $executable + " --exclude-repos"
	}
	
	Return $executable
}



Function GetBackupFileSize($backupOutput)
{
	$filename = GetBackupFilename $backupOutput
	If (Test-Path $filename) {
		$fileSize = (Get-Item $filename).length # in KB
		Return FormatFileSize $fileSize
	}
	Return $false
}

Function FormatFileSize($size)
{
    If    ($size -gt 1TB) { Return "{0:0.00} TB" -f ($size / 1TB) }
    ElseIf ($size -gt 1GB) { Return "{0:0.00} GB" -f ($size / 1GB) }
    ElseIf ($size -gt 1MB) { Return "{0:0.00} MB" -f ($size / 1MB) }
    ElseIf ($size -gt 1KB) { Return "{0:0.00} kB" -f ($size / 1KB) }
    ElseIf ($size -gt 0)   { Return "{0:0.00} B" -f $size }
    Else                   { Return "" }
}

Function GetFreeDiskSpace($backupOutput)
{
	$filename = GetBackupFilename $backupOutput
	If ($filename -ne $false) {
		Try {
			$qualifier = split-path $filename -qualifier
			$filter = "name='{0}'" -f $qualifier
			$diskSpace = Get-WMIObject Win32_LogicalDisk -filter $filter | select freespace
			$freeDiskSpace = FormatFileSize $diskSpace.freespace
			Return $freeDiskSpace
		} Catch {
			Write-Error $_.Exception
			Log $_.Exception.Message
		}
	}
	Return $false
}

Function GetBackupFilename($backupOutput)
{
	$pattern = "Archive is located at: (.*?)\.zip"
	$regex = [regex] $pattern
	$match = $regex.Match($backupOutput)
	If ($match.Success -and ($match.Groups.Count -gt 1)) {
		$filename = "{0}.zip" -f $match.Groups[1]
		Return $filename
	}
	Return $false
}



###################################################################################################



$scriptStartedTimestamp = Get-Date
$today = Get-Date -UFormat "%Y%m%d"

$mailCredentialFilename = ".\credential.mail"
$sshCredentialFilename = ".\credential.ssh"

$currentDirectory = $(get-location)
$logDirectory = "{0}\log" -f $currentDirectory
$logFilename = "{0}\{1}.log" -f $logDirectory, $today


# Prepare log and mail/ssh configuration
EnsureLogDirectory

$newCredentialCreated = $false;
If ($configuration["SendMailBeforeBackup"] -or $configuration["SendMailAfterBackup"] -or $configuration["SendMailBeforeSSHUpload"] -or $configuration["SendMailAfterSSHUpload"]) {
	$result = EnsureCredentialFile "mail"
	If ($result -eq "false") {
		Exit 1
	}
	If ($result -eq "created") {
		If (!(TestMailCredential)) {
			Exit 1
		}
		$newCredentialCreated = $true
	}
}
If ($configuration["UploadToSSH"]) {
	$result = EnsureCredentialFile "ssh"
	If ($result -eq "false") {
		Exit 1
	}
	If ($result -eq "created") {
		If (!(TestSSHCredentials)) {
			Exit 1
		}
		$newCredentialCreated = $true
	}
}
If ($newCredentialCreated) {
	Log "New credential successfully created. Please execute script again to start backup."
	Exit 0
}


# Start backup, with before and after notifications
If ($configuration["SendMailBeforeBackup"]) {
	$sendResult = SendMail $configuration["Mail"]["Subject"]["Start"] " " $false
}

$backupOutput = RunBackup
$backupSuccessful = !($backupOutput -match " \[FATAL\] ")

If ($configuration["SendMailAfterBackup"]) {
	If ($backupOutput -match " \[FATAL\] ") {
		$subject = $configuration["Mail"]["Subject"]["Error"]
	} Else {
		$subject = $configuration["Mail"]["Subject"]["Success"]
	}

	$body = PrepareBackupMailBody $backupSuccessful $backupOutput
	$sendResult = SendMail $subject $body
}


# Upload backup file to other computer via SSH
If ($backupSuccessful -and $configuration["UploadToSSH"]) {
	If ($configuration["SendMailBeforeSSHUpload"]) {
		$sendResult = SendMail $configuration["Mail"]["Subject"]["SSHStart"] " " $false
	}
	
	$sshUploadOutput = UploadToSSH $backupOutput
	if ($sshUploadOutput -eq $true) {
		If ($configuration["UploadToSSH"]["DeleteAfterUpload"] -eq $true) {
			DeleteLocalBackupFile $backupOutput
		}
		
		If ($configuration["SendMailAfterSSHUpload"]) {
			$sshConfig = $configuration["UploadToSSH"]
			$message = "Copied backup to: {0}:{1}" -f $sshConfig["ComputerName"], $sshConfig["TargetDirectory"]
			If ($sshConfig["DeleteAfterUpload"]) {
				$message = $message + "`n... and deleted local backup."
			}
			$sendResult = SendMail $configuration["Mail"]["Subject"]["SSHSuccess"] $message $false
		}
	}
	Else {
		$errorMessage = ""
		if ($sshUploadOutput -ne $false) {
			Write-Error $sshUploadOutput
			Log $sshUploadOutput
			$errorMessage = $sshUploadOutput
		}
		
		If ($configuration["SendMailAfterSSHUpload"]) {
			$sendResult = SendMail $configuration["Mail"]["Subject"]["SSHError"] $sshUploadOutput $false
		}
		Exit 1
	}
}

Exit 0
