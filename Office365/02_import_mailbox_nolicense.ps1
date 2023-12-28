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
    Write-Host -ForegroundColor Red "The file $file_arg not exist. Must be in the same folder of this script. Use only the filename as parameter"
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
    Write-Host -ForegroundColor Red "The file $file_arg not exist. Must be in the same folder of this script. Use only the filename as parameter"
    exit
}

Write-Host "Check that the file $file_arg has been saved in UTF-8 format"
Pause

$type = ""
$controllo = 0
$Risposta = Read-Host -Prompt "Select the type:`r`n 1-shared`r`n 2-room`r`n 3-equipment`r`n"

if ($Risposta -eq 1) {
    $type = "shared"
    $controllo = 1
}

if ($Risposta -eq 2) {
    $type = "room"
    $controllo = 1
}

if ($Risposta -eq 3) {
    $type = "equipment"
    $controllo = 1
}

$Language = Read-Host -Prompt "Insert the language desidered for the mailboxes (Default: en-us):"
$DateFormat = Read-Host -Prompt "Insert the Date format (Default: dd/MM/yyyy):"
$TimeFormat = Read-Host -Prompt "Insert the Time format (Default: HH:mm):"
$TimeZone = Read-Host -Prompt "Insert the Time Zone (Default: W. Europe Standard Time):"

if (-not $Language) {
    $Language = "en-us"
}

if (-not $DateFormat) {
    $DateFormat = "dd/MM/yyyy"
}

if (-not $TimeFormat) {
    $TimeFormat = "HH:mm"
}

if (-not $TimeZone) {
    $TimeZone = "W. Europe Standard Time"
}

if ($controllo -eq 1) {

    Import-Csv $file_arg | foreach-object {
        Write-Host "Creazione mailbox $($_.Mail) con alias $($_.Alias)" -ForegroundColor Green
        echo "New-Mailbox -Name ""$($_.Name)"" -Alias $($_.Alias) -MicrosoftOnlineServicesID $($_.Mail)" > tmp_newmail.ps1
        ./tmp_newmail.ps1
        Start-Sleep -s 5
    }

    Write-Host "-- Waiting before starting the second conversion procedure and various changes --" -ForegroundColor Red
    Start-Sleep -s 10
    
    Import-Csv $file_arg | foreach-object { 
        Write-Host "- Start mailbox variations $type $($_.Alias)" -ForegroundColor Green
        Write-Host "Conversion to $type $($_.Alias)"    
        Set-Mailbox $($_.Alias) -Type $type
        Start-Sleep -s 2
        if ( $type -eq "shared" ) {
            Write-Host "Changing the language of $type $($_.Alias)"    
            Get-Mailbox $($_.Alias) | Get-MailboxRegionalConfiguration | Set-MailboxRegionalConfiguration -Language $Language -DateFormat $DateFormat -TimeFormat $TimeFormat -TimeZone $TimeZone -LocalizeDefaultFolderName:$true
            Start-Sleep -s 2
            Write-Host "Changing the size limit of $type $($_.Alias)"
            Set-Mailbox -Identity $($_.Alias) -MaxReceiveSize 150MB -MaxSendSize 150MB
            Start-Sleep -s 2
            Write-Host "Changing SentAs mailbox $type $($_.Alias)"
            set-mailbox $($_.Alias) -MessageCopyForSentAsEnabled $True
            Start-Sleep -s 2
            Write-Host "Changing SendOnBehalf mailbox $type $($_.Alias)"
            set-mailbox $($_.Alias) -MessageCopyForSendOnBehalfEnabled $True
            Start-Sleep -s 2
        }
    }
} else {
    Write-Host "Incorrect value inserted" -ForegroundColor Red
    exit
}
