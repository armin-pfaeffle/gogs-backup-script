
$configuration = @{
	"Gogs" = @{
		"Executable" = "C:\gogs\gogs.exe";
		"Options" = @{		
			# "Config" = "custom/conf/app.ini";
			"Verbose" = $TRUE;
			# "TempDir" = "";
			"Target" = "C:\gogs\backup";
			# "ArchiveName" = "";
			#"DatabaseOnly" = $TRUE;
			#"ExcludeRepositories" = $TRUE;
		};
	};
	
	"SendMailBeforeBackup" = $TRUE;
	"SendMailAfterBackup" = $TRUE;
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
		};
		"AddLogToBody" = $TRUE;
	};
}
