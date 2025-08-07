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

# Main
$file_arg = $args[0]

if ([string]::IsNullOrEmpty($file_arg)) {
    Write-Host "The file $file_arg not exist. Must be in the same folder of this script. Use only the filename as parameter"
    exit
}

Write-Host "Check that the file $file_arg has been saved in UTF-8 format"
Pause

$directory = Split-Path -Path $args[0] -Parent
if (-not $directory) {
    $file_arg = $PSScriptRoot + "\" + $file_arg
} elseif ($directory -eq ".") {
    $file_arg = $file_arg -replace '^\.\\', ''
    $file_arg = $PSScriptRoot + "\" + $file_arg
}

if (-not (Test-Path "$file_arg")) {
    Write-Host "The file $file_arg does not exist. Must be in the same folder of this script. Use only the filename as parameter"
    exit
}

$list_users = Import-Csv -Path $file_arg

foreach ($user in $list_users) {
    $username = $user.Account
    $username_new = $user.NewAccount
    $move_to_alias = $user.MoveToAlias -eq "true"
    $name = $user.Name
    $lastname = $user.LastName
    $displayName = $user.DisplayName

    if ([string]::IsNullOrWhiteSpace($username)) {
        continue
    }

    Write-Host "`n - Processing user: $username" -ForegroundColor Yellow

    # Identity da usare in Set-Mailbox
    $currentIdentity = $username

    if (![string]::IsNullOrWhiteSpace($username_new)) {
        Write-Host "Modifying primary address for: $username" -ForegroundColor Red

        if ($move_to_alias) {
            Write-Host "Adding alias $username to $username_new" -ForegroundColor Green
            Set-Mailbox -Identity $username -EmailAddresses @{Add=$username_new}
        }

        Write-Host "Changing WindowsEmailAddress to $username_new" -ForegroundColor Green
        Set-Mailbox -Identity $username -WindowsEmailAddress $username_new

        Write-Host "Changing MicrosoftOnlineServicesID to $username_new" -ForegroundColor Green
        Set-Mailbox -Identity $username -MicrosoftOnlineServicesID $username_new

        Start-Sleep -Seconds 2

        $currentIdentity = $username_new

        if (-not $move_to_alias) {
            Write-Host "Removing old alias $username from $username_new" -ForegroundColor Magenta
            Set-Mailbox -Identity $currentIdentity -EmailAddresses @{Remove=$username}
        }
    } else {
        Write-Host "No NewAccount specified — skipping rename and alias" -ForegroundColor DarkGray
    }

    $userParams = @{}
    if (![string]::IsNullOrWhiteSpace($name)) {
        Write-Host "Changing Name to $name" -ForegroundColor Green
        $userParams["Name"] = $name
    }
    if (![string]::IsNullOrWhiteSpace($lastname)) {
        Write-Host "Changing Last Name to $lastname" -ForegroundColor Green
        $userParams["LastName"] = $lastname
    }
    if (![string]::IsNullOrWhiteSpace($displayName)) {
        Write-Host "Changing DisplayName to $displayName" -ForegroundColor Green
        $userParams["DisplayName"] = $displayName
    }

    if ($userParams.Count -gt 0) {
        Set-User -Confirm:$false -Identity $currentIdentity @userParams
    }
}

