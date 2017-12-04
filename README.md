
Gogs Backup Script
==========================

This simple script runs the CLI backup function of [Gogs](https://gogs.io/), accompanied by notification e-mails. Since version 0.2 successfully created backups can be uploaded to another computer via SSH.

## Contents

1. [Overview](#overview)
	1. [Features](#features)
	2. [What does this script exactly do?](#what-does-this-script-exactly-do)
2. [Installation](#installation)
	1. [General](#general)
	2. [Run as Windows task](#run-script-as-windows-task)
3. [FAQ](#faq)
4. [Changelog](https://github.com/armin-pfaeffle/gogs-backup-script/blob/master/CHANGELOG.md)
5. [Author & License](#author--license)


# Overview

## Features

* Configurable script for running Gogs backup command
* Send notification mail before starting and after finishing script/uploading backup via SSH
* Simple mail and SSH credential configuration
* Upload backup ZIP file to another computer via SSH after successful backup


## What does this script exactly do?

First of all the script loads the `configuration.ps1` file, so prepare that **before** using the script (see [installation](#installation)! After that it ensures that there is a `log` directory so the script can write log files ‒ one log file for each day.

Next step is to check for file existance of `credential.mail` resp. `credential.ssh` in which mail/SSH credential are saved. These files only exists, if at least `SendMailBeforeBackup` or `SendMailAfterBackup` resp. `SendMailBeforeSSHUpload` or `SendMailAfterSSHUpload` is set to `$true`, because only then e-mail notifications are sent. If files do not exist, the script asks for mail or SSH credential, saves the input (password is encrypted) and starts a test -- sends a test mail resp. tries SSH connection. If a test fails, credential file is deleted and you have to start script again to re-enter correct username and password. If everything is fine script quits, so you have to run it again to execute backup.

After the initialization the script sends a »Starting backup« mail -- if `SendMailBeforeBackup` is set to `$true` -- so you know that the backup is executed. After running the backup you will receive a success or error notification, depending on the result of the backup process. Furthermore the complete output is written to a daily log file. If you have enabled `UploadToSSH`, the upload process is startet, accompanied by notification e-mails. ■


# Installation

## General

1. Put the script files `run-backup.ps1` and `configuration.ps1` anywhere on your computer.
2. Ensure that it has write rights to the directory, because it writes log files.
3. Open `configuration.ps1` and modify it for you needs. If you don't want to receive notifications via e-mail set `SendMailBeforeBackup`, `SendMailAfterBackup`, `SendMailBeforeSSHUpload` and `SendMailAfterSSHUpload` to `$false` and you can ignore the `Mail`section.
4. If you setup configuration to receive notifications, you have to run the script via Windows PowerShell **before** you can use it as backup script because it asks you for mail/SSH credentail.
5. Now you can run the script manually by executing it via Windows PowerShell, or you can add a [Windows task](#run-script-as-windows-task).


## Run as Windows task

[This tutorial](http://www.sevenforums.com/tutorials/12444-task-scheduler-create-new-task.html) describes how to add a new Windows task . The important things are to set the right parameters as application ‒ please adjust the path!

```powershell
# Program/script:
C:\WINDOWS\system32\WindowsPowerShell\v1.0\powershell.exe

# Add arguments (optional):
-NoLogo -NonInteractive -File "C:\gogs\backup\run-backup.ps1"

# Start in (optional):
C:\gogs\backup
```


# FAQ

1. Can I send the notification mails to more than one e-mail address?

    Yes, you can! In the `configuration.ps1` you can see the option `To` in the `Mail` section. You can set this option to comma separated addresses, e.g.: `"To" = "first@example.com, second@example.com, third@example.com";`

2. Why do my entered credential do not work after update to version 0.2?

	I changed the filename for the mail credential file from `backup-client.mail-credential` to `credential.mail`, so it's better readable and because of consistence reasons. Rename your existant credentail or re-run script to generate a new credential file.

When you have any further questions, please contact me via E-Mail [mail@armin-pfaeffle.de](mailto:mail@armin-pfaeffle.de)!


# Author & License

Armin Pfäffle ‒ [www.armin-pfaeffle.de](http://www.armin-pfaeffle.de) ‒ [mail@armin-pfaeffle.de](mailto:mail@armin-pfaeffle.de)

Licensed under the [MIT License](https://github.com/armin-pfaeffle/gogs-backup-script/blob/master/LICENSE.md).

