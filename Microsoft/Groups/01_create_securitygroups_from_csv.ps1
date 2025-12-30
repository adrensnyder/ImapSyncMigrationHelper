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
# Create groups from CSV:
# - Name is mandatory
# - Owner is mandatory (one or more owners supported via separator)
# - If Email is empty => Security Group (Microsoft Graph)
# - If Email is present => Mail-enabled Security Group (Exchange Online)
#
# CSV columns: Name,Owner,Email
# Owner can contain multiple values separated by -owner_sep (default ";")
# Email is optional
###################################################################

param(
    [Parameter(Mandatory=$true)]
    [string]$file_arg,

    [Parameter(Mandatory=$false)]
    [string]$owner_sep = "|"
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

function New-SafeMailNickname {
    param([string]$Name)
    $nick = $Name.Trim()
    $nick = $nick -replace '\s+', '-'
    $nick = $nick -replace '[^a-zA-Z0-9\-]', ''
    if ([string]::IsNullOrWhiteSpace($nick)) { $nick = "group" }
    if ($nick.Length -gt 64) { $nick = $nick.Substring(0,64) }
    return $nick.ToLower()
}

function Ensure-GraphConnection {
    try {
        $ctx = Get-MgContext -ErrorAction Stop
        if (-not $ctx) { throw "No MgContext" }
    } catch {
        Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
        Connect-MgGraph -Scopes "Group.ReadWrite.All","Directory.Read.All","User.Read.All" | Out-Null
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

function Resolve-OwnerUser {
    param(
        [Parameter(Mandatory=$true)][string]$Owner
    )
    Ensure-GraphConnection
    try {
        return Get-MgUser -UserId $Owner -ErrorAction Stop
    } catch {
        try {
            $escaped = $Owner.Replace("'","''")
            $u = Get-MgUser -Filter "userPrincipalName eq '$escaped' or mail eq '$escaped'" -ConsistencyLevel eventual -ErrorAction Stop | Select-Object -First 1
            return $u
        } catch {
            return $null
        }
    }
}

function Add-GraphGroupOwner {
    param(
        [Parameter(Mandatory=$true)][string]$GroupId,
        [Parameter(Mandatory=$true)][string]$OwnerObjectId
    )
    try {
        New-MgGroupOwnerByRef -GroupId $GroupId -BodyParameter @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$OwnerObjectId"
        } | Out-Null
        return $true
    } catch {
        Write-Host "Warning: cannot set Graph owner for groupId $GroupId : $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

$rows = Import-Csv -Path $file_arg

foreach ($r in $rows) {

    $Name     = ($r.Name  | ForEach-Object { "$_".Trim() })
    $OwnerRaw = ($r.Owner | ForEach-Object { "$_".Trim() })
    $Email    = ($r.Email | ForEach-Object { "$_".Trim() })

    $Owners = @()
    if (-not [string]::IsNullOrWhiteSpace($OwnerRaw)) {
        $Owners = @(
            ($OwnerRaw -split [regex]::Escape($owner_sep)) |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -ne "" }
        )
    }

    if ([string]::IsNullOrWhiteSpace($Name) -or $Owners.Length -eq 0) {
        Write-Host "Skipping row: Name and Owner are mandatory (at least one owner required)." -ForegroundColor Yellow
        continue
    }

    $ownerUsers = @()
    $invalid = $false
    foreach ($o in $Owners) {
        $u = Resolve-OwnerUser -Owner $o
        if (-not $u) {
            Write-Host "Skipping '$Name' : Owner not found in tenant -> $o" -ForegroundColor Red
            $invalid = $true
            break
        }
        $ownerUsers += $u
    }

    if ($invalid -or $ownerUsers.Length -eq 0) { continue }

    $ownersText = ($ownerUsers | Select-Object -ExpandProperty UserPrincipalName) -join $owner_sep

    if ([string]::IsNullOrWhiteSpace($Email)) {

        Ensure-GraphConnection

        $escapedName = $Name.Replace("'","''")
        $existing = Get-MgGroup -Filter "displayName eq '$escapedName'" -ConsistencyLevel eventual -CountVariable c -ErrorAction SilentlyContinue

        if ($existing) {
            Write-Host "Security group already exists: $Name" -ForegroundColor Yellow
            continue
        }

        $nick = New-SafeMailNickname -Name $Name

        Write-Host "Creating Security Group (non mail-enabled): $Name | Owners: $ownersText" -ForegroundColor Green
        try {
            $newGroup = New-MgGroup -DisplayName $Name -MailEnabled:$false -SecurityEnabled:$true -MailNickname $nick -ErrorAction Stop
            foreach ($ou in $ownerUsers) {
                Add-GraphGroupOwner -GroupId $newGroup.Id -OwnerObjectId $ou.Id | Out-Null
            }
        } catch {
            Write-Host "Error creating Security Group '$Name' : $($_.Exception.Message)" -ForegroundColor Red
        }

    } else {

        Ensure-ExchangeConnection

        $dg = $null
        try { $dg = Get-DistributionGroup -Identity $Email -ErrorAction Stop } catch { }
        if (-not $dg) {
            try { $dg = Get-DistributionGroup -Identity $Name -ErrorAction Stop } catch { }
        }

        if ($dg) {
            Write-Host "Mail-enabled security group already exists: $Name ($Email)" -ForegroundColor Yellow
            continue
        }

        $alias = $Email.Split("@")[0].Trim()
        if ([string]::IsNullOrWhiteSpace($alias)) {
            $alias = New-SafeMailNickname -Name $Name
        }

        Write-Host "Creating Mail-enabled Security Group: $Name ($Email) | Owners: $ownersText" -ForegroundColor Green
        try {
            New-DistributionGroup `
                -Type Security `
                -Name $Name `
                -Alias $alias `
                -PrimarySmtpAddress $Email `
                -ErrorAction Stop | Out-Null

            Set-DistributionGroup `
                -Identity $Email `
                -ManagedBy ($ownerUsers | Select-Object -ExpandProperty Id) `
                -BypassSecurityGroupManagerCheck:$true `
                -ErrorAction Stop | Out-Null

        } catch {
            Write-Host "Error creating Mail-enabled Security Group '$Name' : $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    Start-Sleep -Seconds 1
}

Write-Host "Done." -ForegroundColor Green
