$configuration = @{
	# General settings
	"Gogs" = @{
		"Executable" = "C:\gogs\gogs.exe";
		"Options" = @{		
			# "Config" = "custom/conf/app.ini";
			"Verbose" = $true;
			# "TempDir" = "";
			"Target" = "C:\gogs\backup";
			# "ArchiveName" = "";
			# "DatabaseOnly" = $true;
			# "ExcludeRepositories" = $true;
		};
	};
	"SendMailBeforeBackup" = $true;
	"SendMailAfterBackup" = $true;
	
	# SSH configuration for SSH upload
	#"UploadToSSH" = @{
	#	"ComputerName" = "raspberrypi";
	#	"TargetDirectory" = "/media/usb/backups/gogs/";
	#	"DeleteAfterUpload" = $false;
	#};
	#"SendMailBeforeSSHUpload" = $true;
	#"SendMailAfterSSHUpload" = $true;
	
	# Mail configuration
	"Mail" = @{
		"From" = "from@example.com";
		"To" = "to@example.com";
		"Server" = "mail@example.com";

		"Subject" = @{
			"Prefix" = "[Gogs Backup]";

			"Test" = "Testing mail credential";
			"Start" = "Starting backup";
			"Success" = "Successful";
			"Error" = "Error";
			
			"SSHStart" = "Starting SSH upload";
			"SSHSuccess" = "SSH upload successful";
			"SSHError" = "SSH upload error";
		};
		"AddLogToBody" = $true;
	};
}
