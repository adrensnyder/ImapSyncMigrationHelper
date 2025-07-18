﻿###################################################################
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

# List all available time zones
#$allTimeZones = [System.TimeZoneInfo]::GetSystemTimeZones()
#
#foreach ($timeZone in $allTimeZones) {
#    Write-Host "Id: $($timeZone.Id), Display Name: $($timeZone.DisplayName), Standard Name: $($timeZone.StandardName)"
#}

# Variables
$maxSize = 150MB
$retention_days = 30

# Main

$file_arg = $args[0]

if ( [string]::IsNullOrEmpty($file_arg) )  {
    Write-Host "The file $file_arg not exist. Must be in the same folder of this script. Use only the filename as parameter"
    exit
}

Write-Host "Check that the file $file_arg has been saved in UTF-8 format"
Pause

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

$retention = [TimeSpan]::FromDays($retention_days)

Import-Csv $file_arg | foreach-object {
    $mailbox = $_.Account
    $password = ""
    if ($_.Password) {
        $password = ConvertTo-SecureString $_.Password -AsPlainText -Force
    }
    $Language = $_.Language
    $DateFormat = $_.DateFormat
    $TimeFormat = $_.TimeFormat
    $TimeZone = $_.TimeZone

    $mailbox_exist = $Null

    Write-Host -Foreground Green "- Start changing settings for $mailbox"

    $mailbox_exist = get-mailbox -identity $mailbox -ErrorAction SilentlyContinue
    
    if ($mailbox_exist) {
        if ($password) {
            Write-Host "Changing password for $mailbox"
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
            $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

            $passwordProfile = @{
                password = $plainPassword
                forceChangePasswordNextSignIn = $false
            }

            Update-MgUser -UserId $mailbox -PasswordProfile $passwordProfile
            
        } else {            
            Write-Host "Password not changed"
        }
        Write-Host "Changing the language for $mailbox"
        Get-Mailbox $mailbox | Get-MailboxRegionalConfiguration | Set-MailboxRegionalConfiguration -Language $Language -DateFormat $DateFormat -TimeFormat $TimeFormat -TimeZone $TimeZone -LocalizeDefaultFolderName:$true
        Write-Host "Changing attachments size for $mailbox"
        Set-Mailbox -Identity $mailbox -MaxReceiveSize $maxSize -MaxSendSize $maxSize
        Write-Host "Changing Retain Deleted Item for $mailbox"
        Set-Mailbox -Identity $mailbox -RetainDeletedItemsFor $retention
    } else {
        Write-Host -Foreground Red "The account $mailbox not have a mailbox"
    }
}
