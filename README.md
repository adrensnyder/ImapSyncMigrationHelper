# ImapSyncMigrationHelper
The purpose of these tools is to assist in migrating a mail system using ImapSync.

Migration has also been tested to and from Microsoft 365.
It has not been tested with GMAIL, and automation for creating the necessary App for access is also missing. 
The token creation procedures are likely the same, but creating the required app for OAuth2 access needs verification.

## Initial steps
On a Linux server with at least Python 3.8 (Tested Redhat, Centos and Rocky), install ImapSync and update it to the latest version.

Personally, I follow these steps:

```
yum -y install imapsync

cd /root

yum -y install perl-App-cpanminus \
 perl-Dist-CheckConflicts \
 perl-HTML-Parser \
 perl-libwww-perl \
 perl-Module-Implementation \
 perl-Module-ScanDeps \
 perl-Package-Stash \
 perl-Package-Stash-XS \
 perl-PAR-Packer \
 perl-Regexp-Common \
 perl-Sys-MemInfo \
 perl-Test-Fatal \
 perl-Test-Mock-Guard \
 perl-Test-Requires \
 perl-Test-Deep \
 perl-File-Tail \
 perl-Unicode-String \
 perl-Test-NoWarnings \
 perl-Test-Simple \
 perl-Test-Warn \
 perl-Sub-Uplevel 

cpanm JSON::PP
cpanm Encode::IMAPUTF7 
wget -N https://imapsync.lamiral.info/imapsync --no-check-certificate
chmod +x imapsync

mv -f /usr/bin/imapsync  /usr/bin/imapsync_old
cp ./imapsync /usr/bin/imapsync
imapsync --version
```

- Create a new path like /srv/data/migrations/[jobname]
- Copy all GIT files from Linux folder into it
- Open main.conf and configure the variables needed at imapsync to work
- Edit the file mail_list or the filename you chose in the main.conf and write in there all the structure of migration

Start migration in a screen session using ImapSyncMigrationHelper.sh :)

### ListFolders
Leaving LISTFOLDERS enabled will create a folder in the log with the \_listfolder tag. 
ImapSync will only provide the list of folders in the origin and destination.
It's useful to find if there are any problems in connection/login/configuration or if some folders are not correctly translated

### Check migration for errors
Using the script check_migration.sh, you can check for some errors, usually, I find, in my experience, providing a summary of the migration status. 
Use the last folder that contains the log of the current run.
```
./check_migration.sh logfolderfullpath
```

### Schedule incremental migration
You can schedule with cron an incremental migration.
```
01 22 * * * root /srv/data/migrations/jobname/ImapSyncMigrationHelper.sh > /dev/null 2>&1
```

If you want to be sure it start only after a renew of the token you can use atstart.sh
```
01 22 * * * root /srv/data/migrations/jobname/atstart.sh /srv/data/migrations/jobname/retoken_jobname.sh > /dev/null 2>&1
```

NOTE: I suggest to schedule the job only after a successful first migration 

## OAuth2
### Microsoft 365
It is possible to copy data by accessing Microsoft 365 mailboxes.\
For all the scripts i'm using **Powershell 5.1 Build 22621 Rev. 2506**. Not tested with other versions

Firstly, an administrator account with a license that includes the mailbox is required.
Afterwards, you will need to create the App in the tenant. There is an automated procedure in the Office365 section.

I suggest to create a dedicated folder for every single job, like done for the linux part, and copy the entire folder Office365 from GIT into it.

Open PowerShell, in a Windows PC/Server as an administrator, and run the file 00_CreateApp.ps1. You will need to enter the credentials of the mentioned account.
You can change the App Name editing the file

Now you have to assign delegate access to every mailbox. 
You can use the script 01_Add_Admin_To_All.ps1 editing the variables needed inside

Returning to Linux, you need to request the token. If you created the app with the script, it would have generated a file containing the Application ID and Secret; otherwise, you will need to retrieve them from the web.

The secret is not mandatory, but I recommend creating one for security purposes.

Edit the mutt_oauth2.py file, inserting the values mentioned earlier into client_id and client_secret for the Microsoft section.

Then, with at least Python 3.8, run the mutt_oauth2.py file with the authorization request.
```
 ./mutt_oauth2.py jobname_token_auth --authorize
```
Select: microsoft, localhostauthcode

When requested, insert the tenant administrator account used for the migration and the creation of the app. It will provide a URL. 

Log in to office.com with the tenant administrator account and paste it in the address bar of the browser. The next page will show an error because it will try to connect to a localhost URL

Copy it and open another terminal on the Linux server you've requested the token and type
```
curl "TheLocalhostUrl"
```
If successful you can close the secondary terminal. The Authorize procedure with Mutt will create the file jobname_token_auth. 
Inside it you will find the Token, the information you inserted and the expire date.

If any error occurs you have to delete the file jobname_token_auth, check the App, check the admin account used and restart the Mutt Authorize command

Now run
```
./create_next_schedule.sh
```

The files jobname_token_imapsync, retoken_jobname-job.txt, and retoken_jobname.sh will be created together with a scheduled renewal of the token using AT command. 
You can view the job with atq and at -c [ID] to see the details.

The file jobname_token_imapsync contains the token needed by ImapSync to log in to the 365 platform.

To stop the renew of the Token simply delete the at job with 
```
atrm [ID]
```

NOTE:
If you want to migrate from 365 to 365, you can:

- Try the functions included in the Exchange section for Tenant-to-Tenant migration. (I haven't had much luck, except with the Gmail Tenant to 365 function)
- Generate the app, create the token with another name using mutt, changing only the jobname in the filename when requesting authorization, and start `./create_next_schedule.sh newjobname_token_auth`. Now, in the main.conf file, change the variables TOKEN_ORIG and TOKEN_DEST.

The password in mail_list for the 365 account isn't needed but must maintain the structure, so write something like "pass".

#### Tenant and Structure Preparation 
In the folder Office365, you will find some useful scripts that can be helpful to reduce the time needed to create the structure
All the scripts, apart 00_CreateApp.ps1, request connection to the Tenant. You can use 01_Connection_Tenant.ps1 to do it done easy

- **00_CreateApp.ps1**\
This procedure will create the needed App that permit ImapSync to connect to 365. Only run it and use an account of the tenant with admin rights
- **01_Connection_Tenant.ps1**\
Run it to connect to 365 from a PowerShell console started with admin priviledges
- **02_Add_Admin_To_All.ps1**\
Edit the $admin variable to assign to it the delegation for all mailboxes existing in the tenant
- **02_Remove_Admin_From_All.ps1**\
Edit the $admin variable to remove the delegation from all mailboxes existing in the tenant
- **02_import_mailbox_nolicense.ps1**\
Populate the file 02_import_mailbox_nolicense.csv with data of new sharebox, room or equipment. Create new file for each type and rename the file like 02_import_mailbox_sharebox|room|equipment.csv
Start the script with the filename as parameter you want to import and it will create them with max attachments size, language selected, and SendAs|SendOnBehalf enabled\
Usage: .\02_import_mailbox_nolicense.ps1 filename.csv
- **02_user_settings.ps1**\
Populate the file 02_user_settings.csv
It will reset the password, change the attachments size and change the language\
Usage: .\02_user_settings.ps1 filename.csv
- **03_Change_Domain.ps1**\
Edit $orig_domain and $dest_domain variables. It will change the primary SMTP domain of all mailboxes
- **99_CheckMailGuid.ps1** and **99_RetrieveGUIDtoCSV.ps1**\
There scripts were created to cross check that the GUID used in some procedures match the email address
- **Alias**\
Add Aliases to a mailbox\
Usage (Single): .\00_add_alias.ps1 filename.csv
- **DistributionList**\
Create, if not exist, a Distribution List and add users to it\
Usage (Single): .\00_add_mail_lists.ps1 filename.csv
- **Permissions**\
Add delegated users to a mailbox\
Usage (Single): .\00_add_alias.ps1 filename.csv
- **Rules**\
Create a path in the mailbox and a simple rule\
NOTE: If using a system folder (Ex. Inbox) check that it exist in every account with the correct language or it will be created.
If this appen you can move the subfolders created from the webmail to the correct folder and the rule will adapt itself\
Usage: .\00_add_rule.ps1 filename.csv

### GMAIL
I have not tested this procedure with Gmail. You surely need to create an App and use mutt_oauth2 in a similar way as explained for 365. Probably the rest of the procedure will be the same.

## TODO
NOTE: I program in my spare time but i will try to update those scripts asap.
- Add more options to the Rules scripts (Like Subject)
- Add language option for single row and not the entire conversion in sharebox|users_settings\
- Verify and integration of token management https://imapsync.lamiral.info/oauth2/oauth2_office365/ 
- **[Done]** ~Convert Alias|DistributionList|Permissions to use a single file with all the operations like Rules script~

---
Thanks to:\
[@muttmua](https://github.com/muttmua/mutt/blob/master/contrib/mutt_oauth2.py) for the script mutt_oauth2.py\
[@imapsync](https://github.com/imapsync/imapsync) for the main program used in this project

All this project was created in another language and I've traslated it to english, mostly with ChatGpt to speed up the work. Some errors in traslation or in the scripts may occurs. 
I've tested all the scripts, apart 99_* and Externals, and they works.

Thank you for your patience
