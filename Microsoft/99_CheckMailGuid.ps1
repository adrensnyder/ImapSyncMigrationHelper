###################################################################
# Copyright (c) 2023 AdrenSnyder https://github.com/adrensnyder
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# DISCLAIMER:
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
###################################################################

# IMPORTANT NOTES:
# The file to examine is the one we use for PST import, which has these columns by default:
# Workload,FilePath,Name,Mailbox,IsArchive,TargetRootFolder,ContentCodePage,SPFileContainer,SPManifestContainer,SPSiteUrl
#
# - Add a column named AccountMailTest and enter the emails to perform a check that the written GUIDs correspond to the mailbox on 365
#
# - Change the path of $csvFilePath

# Install module PSWriteColor
Write-Host "Install module PSWriteColor"
Install-Module -Name PSWriteColor -Force
Write-Host ""

# Path of the CSV
$csvFilePath = "Test\CopyPST_Guids.csv"

# Read CSV file
$csvData = Import-Csv -Path $csvFilePath

foreach ($row in $csvData) {
    # Obtain the mailbox object with the GUID specified
    if ( $row.Mailbox -ne "" ) {
    	$mailbox = Get-Mailbox -Identity $row.Mailbox
	
		if ($mailbox) {
		    # The email address corresponding to the GUID
		    $emailAddress = $mailbox.UserPrincipalName
		
		    # Compare the obtained email address with the one listed in the "Mailbox" column of the CSV file
		    if ($emailAddress -eq $row.AccountMailTest) {
		    	$text = "Match verified - MailboxOnline: $emailAddress, Mailbox: $($row.AccountMailTest), GUID: $($row.Mailbox)"
		        Write-Host $text -ForegroundColor Green
		    } else {
		    	$text = "ERR: Match not found - MailboxOnline: $emailAddress, Mailbox: $($row.AccountMailTest), GUID: $($row.Mailbox)"
		        Write-Host $text -ForegroundColor Red
		    }
		} else {
		    Write-Host "No mailbox exist with the GUID $($row.Mailbox)."
		}
    }

}