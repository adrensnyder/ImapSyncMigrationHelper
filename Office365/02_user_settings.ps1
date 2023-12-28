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

$file_arg = $args[0]

if ( [string]::IsNullOrEmpty($file_arg) )  {
    Write-Host "The file $file_arg not exist. Must be in the same folder of this script. Use only the filename as parameter"
    exit
}

$directory = Split-Path -Path $args[0] -Parent
if (-not $directory ) {
        $file_arg = $PSScriptRoot + "\" + $file_arg
} elseif ( $directory -eq "." ) {
    $file_arg = $file_arg -replace '^\.\\', ''
    $file_arg = $PSScriptRoot + "\" + $file_arg
}

if (-not (Test-Path "$file_arg")) {
    Write-Host "The file $file_arg not exist. Must be in the same folder of this script. Use only the filename as parameter"
    exit
}

Write-Host "Check that the file $file_arg has been saved in UTF-8 format"
Pause

$Language = "en-us"
$DateFormat = "yyyy-MM-dd"
$TimeFormat = "HH:mm"
$TimeZone = "Eastern Standard Time"

$LanguageRequest = Read-Host -Prompt "Insert the language desidered for the mailboxes (Default: $Language):"
$DateFormatRequest = Read-Host -Prompt "Insert the Date format (Default: $DateFormat):"
$TimeFormatRequest = Read-Host -Prompt "Insert the Time format (Default: $TimeFormat):"
$TimeZoneRequest = Read-Host -Prompt "Insert the Time Zone (Default: $TimeZone):"

if ($LanguageRequest) {
    $Language = $LanguageRequest
}

if ($DateFormatRequest) {
    $DateFormat = $DateFormatRequest
}

if ($TimeFormatRequest) {
    $TimeFormat = $TimeFormatRequest
}

if ($TimeZoneRequest) {
    $TimeZone = $TimeZoneRequest
}

Import-Csv $file_arg | foreach-object {
    $mailbox = $_.Username
    $password = $_.Password
    $mailbox_exist = $Null

    Write-Host -Foreground Green "- Start changing settings for $mailbox"

    $mailbox_exist = get-mailbox -identity $mailbox -ErrorAction SilentlyContinue
    
    if ($mailbox_exist) {
        if ($password) {
            Write-Host "Changing password for $mailbox" -ForegroundColor Green
            Set-MsolUserPassword -UserPrincipalName $mailbox -NewPassword $password -ForceChangePassword $false
        } else {            
            Write-Host "Password not changed"
        }
        Write-Host "Changing the language for $mailbox"
        Get-Mailbox $mailbox | Get-MailboxRegionalConfiguration | Set-MailboxRegionalConfiguration -Language $Language -DateFormat $DateFormat -TimeFormat $TimeFormat -TimeZone $TimeZone -LocalizeDefaultFolderName:$true
        Write-Host "Changing attachments size for $mailbox"
        Set-Mailbox -Identity $mailbox -MaxReceiveSize 150MB -MaxSendSize 150MB
    } else {
        Write-Host -Foreground Red "The account $mailbox not have a mailbox"
    }
}
