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

# Program

$file_arg = $args[0]

if ( [string]::IsNullOrEmpty($file_arg) )  {
    Write-Host "Insert the file with the rules as a parameter" -ForegroundColor Red
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

$account_prev = ""

Import-Csv -Path $file_arg | ForEach-Object {

    $account = $($_.Account)
    $delegate = $($_.Delegate)
    $permissions = $($_.Permissions)
    $automapping = [System.Convert]::ToBoolean($($_.AutoMapping))
	
    if ($account -ne $account_prev) {
        Write-Host ""
        Write-Host -ForegroundColor Green "- Adding delegate for account $account"
    }

    Write-Host "$delegate (Permissions:$permissions | AutoMapping:$automapping)"
    try{
        $setPermissions = Add-MailboxPermission -Identity $account -User $delegate -AccessRights $permissions -AutoMapping $automapping
    }catch{
        Write-Host "[$mailbox] Error applying permissions for $delegate " -ForegroundColor Red
    }
    
    try{
        $setPermissions = Add-RecipientPermission -Identity $account -Trustee $delegate -AccessRights SendAs -confirm:$false
    }catch{
        Write-Host "[$mailbox SendAs] Error applying permissions for $delegate " -ForegroundColor Red
    }

    $account_prev = $account
    
}