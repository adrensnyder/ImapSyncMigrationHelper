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

[CmdletBinding()]
param(
    [switch]$ClearGraphTokenCache = $true,
    [switch]$UseDeviceCodeAuth = $false,
    [string[]]$GraphScopes = @(
        "User.ReadWrite.All",
        "Group.ReadWrite.All",
        "Directory.ReadWrite.All"
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Module {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [string]$MinimumVersion = ""
    )

    $mod = Get-Module -ListAvailable -Name $Name | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $mod) {
        Write-Host "$Name is not installed. Installing..."
        Install-Module $Name -Scope CurrentUser -Force -AllowClobber
    }
    elseif ($MinimumVersion -and ([version]$mod.Version -lt [version]$MinimumVersion)) {
        Write-Host "$Name is installed but version $($mod.Version) < $MinimumVersion. Updating..."
        Update-Module $Name -Force
    }
    else {
        Write-Host "$Name is already installed."
    }
}

function Clear-GraphTokenCache {
    Write-Host "Clearing Microsoft Graph token cache..."

    $mgPath = Join-Path $env:USERPROFILE ".mg"
    if (Test-Path $mgPath) {
        Remove-Item $mgPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    $identityRoot = Join-Path $env:LOCALAPPDATA ".IdentityService"
    if (Test-Path $identityRoot) {
        Get-ChildItem -Path $identityRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "mg*" } |
            ForEach-Object {
                Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
    }
}

try {
    Ensure-Module -Name "ExchangeOnlineManagement"
    Ensure-Module -Name "Microsoft.Graph.Authentication"

    try { Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null } catch {}
    try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } catch {}

    if ($ClearGraphTokenCache) {
        Clear-GraphTokenCache
    }

    Write-Host "Connecting to Exchange Online..."
    Connect-ExchangeOnline -ShowBanner:$false

    Write-Host "Connecting to Microsoft Graph..."
    $connectParams = @{
        Scopes       = $GraphScopes
        ContextScope = "Process"
        NoWelcome    = $true
    }

    if ($UseDeviceCodeAuth) {
        $connectParams["UseDeviceAuthentication"] = $true
    }

    Connect-MgGraph @connectParams

    $ctx = Get-MgContext
    $org = Get-MgOrganization | Select-Object -First 1

    Write-Host ""
    Write-Host "------------------ ACTIVE CONNECTIONS ------------------"
    Write-Host ("Graph Account      : {0}" -f $ctx.Account)
    Write-Host ("Graph TenantId     : {0}" -f $ctx.TenantId)
    Write-Host ("Graph Scopes       : {0}" -f ($ctx.Scopes -join ", "))
    Write-Host ("Organization Name  : {0}" -f $org.DisplayName)
    Write-Host ("Organization Id    : {0}" -f $org.Id)
    Write-Host "--------------------------------------------------------"
    Write-Host ""

}
catch {
    Write-Error $_
    throw
}
