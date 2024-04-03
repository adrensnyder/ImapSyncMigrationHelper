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

# List all available time zones
#$allTimeZones = [System.TimeZoneInfo]::GetSystemTimeZones()
#
#foreach ($timeZone in $allTimeZones) {
#    Write-Host "Id: $($timeZone.Id), Display Name: $($timeZone.DisplayName), Standard Name: $($timeZone.StandardName)"
#}

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


Import-Csv $file_arg | foreach-object {
    $Account = $_.Account
    $Name = $_.Name
    $Alias = $_.Alias

    Write-Host "Creazione mailbox $Account con alias $Alias" -ForegroundColor Green
    echo "New-Mailbox -Name ""$Name"" -Alias $Alias -MicrosoftOnlineServicesID $Account" > tmp_newmail.ps1
    ./tmp_newmail.ps1
    Start-Sleep -s 5
}

Write-Host "-- Waiting before starting the second conversion procedure and various changes --" -ForegroundColor Red
Start-Sleep -s 10

Import-Csv $file_arg | foreach-object { 
    $Account = $_.Account
    $Type = $_.Type #Can be shared, room or equipment
    $Name = $_.Name
    $Alias = $_.Alias
    $Language = $_.Language
    $DateFormat = $_.DateFormat
    $TimeFormat = $_.TimeFormat
    $TimeZone = $_.TimeZone

    Write-Host "- Start mailbox variations $Type $Alias" -ForegroundColor Green
    Write-Host "Conversion to $type $Alias"    
    Set-Mailbox $Alias -Type $Type
    Start-Sleep -s 2
    if ( $Type -eq "shared" ) {
        Write-Host "Changing the language of $Type $Alias"    
        Get-Mailbox $Alias | Get-MailboxRegionalConfiguration | Set-MailboxRegionalConfiguration -Language $Language -DateFormat $DateFormat -TimeFormat $TimeFormat -TimeZone $TimeZone -LocalizeDefaultFolderName:$true
        Start-Sleep -s 2
        Write-Host "Changing attachments size for $Type $Alias"
        Set-Mailbox -Identity $Alias -MaxReceiveSize 150MB -MaxSendSize 150MB
        Start-Sleep -s 2
        Write-Host "Changing SentAs mailbox $Type $Alias"
        set-mailbox $Alias -MessageCopyForSentAsEnabled $True
        Start-Sleep -s 2
        Write-Host "Changing SendOnBehalf mailbox $Type $Alias"
        set-mailbox $Alias -MessageCopyForSendOnBehalfEnabled $True
        Start-Sleep -s 2
    }
}

