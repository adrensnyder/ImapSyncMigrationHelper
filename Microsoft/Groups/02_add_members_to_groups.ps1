###################################################################
# Copyright (c) 2025 AdrenSnyder https://github.com/adrensnyder
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

###################################################################
# Add members to groups from CSV:
# CSV columns: Group,Account
#
# Group can be:
# - Mail-enabled security group (DistributionGroup in EXO)
# - Security group (Graph)
###################################################################

param(
    [Parameter(Mandatory=$true)]
    [string]$file_arg
)

Write-Host "Check that the file $file_arg has been saved in UTF-8 format"
Pause

$directory = Split-Path -Path $file_arg -Parent
if (-not $directory) {
    $file_arg = $PSScriptRoot + "\" + $file_arg
} elseif ($directory -eq ".") {
    $file_arg = $file_arg -replace '^\.\\', ''
    $file_arg = $PSScriptRoot + "\" + $file_arg
}

if (-not (Test-Path "$file_arg")) {
    Write-Host "The file $file_arg not exist. Must be in the same folder of this script. Use only the filename as parameter" -ForegroundColor Red
    exit
}

function Ensure-GraphConnection {
    try {
        $ctx = Get-MgContext -ErrorAction Stop
        if (-not $ctx) { throw "No MgContext" }
    } catch {
        Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
        Connect-MgGraph -Scopes "Group.ReadWrite.All","User.Read.All","Directory.Read.All" | Out-Null
    }
}

function Ensure-ExchangeConnection {
    try {
        Get-OrganizationConfig -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "Connecting to Exchange Online..." -ForegroundColor Yellow
        Connect-ExchangeOnline | Out-Null
    }
}

$rows = Import-Csv -Path $file_arg

foreach ($r in $rows) {
    $Group   = ($r.Group   | ForEach-Object { "$_".Trim() })
    $Account = ($r.Account | ForEach-Object { "$_".Trim() })

    if ([string]::IsNullOrWhiteSpace($Group) -or [string]::IsNullOrWhiteSpace($Account)) {
        Write-Host "Skipping row with empty Group or Account" -ForegroundColor Yellow
        continue
    }

    $dg = $null
    try {
        Ensure-ExchangeConnection
        $dg = Get-DistributionGroup -Identity $Group -ErrorAction Stop
    } catch {
        $dg = $null
    }

    if ($dg) {
        Write-Host "Adding member to mail-enabled group: $Group <= $Account" -ForegroundColor Green
        try {
            Add-DistributionGroupMember -Identity $Group -Member $Account -ErrorAction Stop | Out-Null
        } catch {
            Write-Host "Error (EXO) adding '$Account' to '$Group' : $($_.Exception.Message)" -ForegroundColor Red
        }
        continue
    }

    Ensure-GraphConnection

    $mgGroup = $null
    try {
        if ($Group -match '^[0-9a-fA-F-]{36}$') {
            $mgGroup = Get-MgGroup -GroupId $Group -ErrorAction Stop
        } else {
            $escaped = $Group.Replace("'","''")
            $mgGroup = (Get-MgGroup -Filter "displayName eq '$escaped'" -ConsistencyLevel eventual -CountVariable c -ErrorAction Stop | Select-Object -First 1)
        }
    } catch {
        $mgGroup = $null
    }

    if (-not $mgGroup) {
        Write-Host "Group not found (neither EXO nor Graph): $Group" -ForegroundColor Red
        continue
    }

    $mgUser = $null
    try {
        $mgUser = Get-MgUser -UserId $Account -ErrorAction Stop
    } catch {
        $mgUser = $null
    }

    if (-not $mgUser) {
        Write-Host "User not found in Graph: $Account" -ForegroundColor Red
        continue
    }

    Write-Host "Adding member to security group: $($mgGroup.DisplayName) <= $($mgUser.UserPrincipalName)" -ForegroundColor Green
    try {
        New-MgGroupMemberByRef -GroupId $mgGroup.Id -BodyParameter @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($mgUser.Id)"
        } | Out-Null
    } catch {
        Write-Host "Error (Graph) adding '$Account' to '$($mgGroup.DisplayName)' : $($_.Exception.Message)" -ForegroundColor Red
    }

    Start-Sleep -Seconds 1
}

Write-Host "Done." -ForegroundColor Green
