Bitbucket Server Client Script
==========================

This simple script runs a the internal backup function of [Gogs](https://gogs.io/) and can send notifications via email.

## Contents

1. [Overview](#overview)
	1. [Features](#features)
	2. [What does this script exactly do?](#what-does-this-script-exactly-do)
2. [Installation](#installation)
3. [Run script as Windows task](#run-script-as-windows-task)
1. [FAQ](#faq)
1. [Changelog](https://github.com/armin-pfaeffle/gogs-backup-script/blob/master/CHANGELOG.md)
1. [Author](#author)


# Overview

## Features

* Configurable script for running Gogs backup command
* Send notification mail before starting and after finishing script (with backup log, optional)
* Simple mail credential configuration with test mail


## What does this script exactly do?

First of all the script loads the `configuration.ps1` file, so prepare that **before** using the script! After that it ensures that there is a `log`directory so the script can wirte log files ‒ one log file for each day the script is executed.

In the next step it checks for file existance of `backup-client.mail-credential` where mail credential are saved to. This file only exists, if at least `SendMailBeforeBackup` or `SendMailAfterBackup` is set to `$TRUE` because only then an e-mail notifications are sent. If file does not exist, the script asks for mail credential, saves it and sends a test mail. If sending fails, credential file is deleted. If everything is fine script quits, so you have to run it again to execute backup.

After the initialization the script sends a "Starting backup" mail -- if `SendMailBeforeBackup` is set to `$TRUE` -- so you know that the backup is executed. After running the backup you will receive a success or error notification, depending on the result of the backup process. Furthermore the complete output is written to a daily log file.


# Installation

1. Put the script files `run-backup.ps1` and `configuration.ps1` anywhere on your computer.
2. Ensure that it has write rights to the directory because it writes log files.
3. Open `configuration.ps1` modify it for you needs. If you don't want to receive reports via E-Mail set `SendMailBeforeBackup` and `SendMailAfterBackup` to `$FALSE` and you can ignore the `Mail`section.
4. If you want to receive E-Mails you have to run the script via Windows PowerShell **before** you can use it as backup script. The reason for this is that it asks you for username and password for the mail server and stores this data to a file `backup-client.mail-credential`. So script can access mail credential and send mails automatically. After entering credential you receive a test mail and the script quits.
5. Now you can run the script manually by executing it via Windows PowerShell, or you can add a Windows task.

# Run script as Windows task
How you can add a new task [is described here](http://www.sevenforums.com/tutorials/12444-task-scheduler-create-new-task.html). The important things are to set the right parameters as application ‒ please adjust the pathes!

```
// Program/script:
C:\WINDOWS\system32\WindowsPowerShell\v1.0\powershell.exe

// Add arguments (optional):
-NoLogo -NonInteractive -File "C:\gogs\backup\run-backup.ps1"

// Start in (optional):
C:\gogs\backup
```


# FAQ

1. Can I send the notification mails to more than one e-mail address?

    Yes you can! In the `configuration.ps1` you can see the option `To` in the `Mail` group. There you can set at least one e-mail address or set more than one by separating them via a comma, e.g. the line can look like `"To" = "first@example.com, second@example.com, third@example.com";`.


When you habe any further questions, please contact me via E-Mail [mail@armin-pfaeffle.de](mailto:mail@armin-pfaeffle.de)!


### Author

Armin Pfäffle ‒ [www.armin-pfaeffle.de](http://www.armin-pfaeffle.de) ‒ [mail@armin-pfaeffle.de](mailto:mail@armin-pfaeffle.de)
