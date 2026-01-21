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

Write-Host -ForegroundColor Red "It is advisable to start this procedure in the client's Office365 folder created for this job"
Write-Host -ForegroundColor Red "In the last release of Chrome can appen that the webpage opened by oAuth2.0 get redirected to https"
Write-Host -ForegroundColor Red "Copy the link changing it to http on firefox for every request. Or use Firefox as the default browser"
Pause

# Variables
$NameApp = "TenantManagement_Test"
$REPO    = "PSGallery"

# Modules
function Install-Modules {
    param (
        [string]$Repo,
        [string]$ModuleName,
        [string]$Version
    )

    if (-not (Get-Module -Name $ModuleName -ListAvailable)) {
        # install the module
        Install-Module -Name $ModuleName -Force -AllowClobber -Scope CurrentUser -Repository $Repo $Version
    }
    else {
        Write-Host "$ModuleName is already installed"
        if ($Version) {
            Write-Host "Install version $Version"
            Update-Module -Name $ModuleName -Force -RequiredVersion $Version
        }
    }
}

Install-Modules -Repo $REPO -ModuleName "Microsoft.Graph"

# Connect to 365 
Write-Host -ForegroundColor Green "- Disconnect from Graph"
Disconnect-MgGraph
Start-Sleep -Seconds 5
Write-Host -ForegroundColor Green "- Connecting to 365 (Credentials will be requested multiple times)"
Connect-MgGraph -Scopes `
  "Application.ReadWrite.All", `
  "DelegatedPermissionGrant.ReadWrite.All", `
  "AppRoleAssignment.ReadWrite.All", `
  "Organization.Read.All" `
  -ContextScope Process

# TenantId: sempre disponibile dal contesto
$TenantId = (Get-MgContext).TenantId

$TenantDomain = $null
$TenantOnMicrosoftDomain = $null

try {
    $tenant = Get-MgOrganization | Select-Object -First 1
    if ($tenant) {
        $TenantDomain = ($tenant.VerifiedDomains | Where-Object { $_.IsDefault -eq $true }).Name
        $TenantOnMicrosoftDomain = ($tenant.VerifiedDomains | Where-Object { $_.Name -match 'onmicrosoft\.com$' }).Name
    }
} catch {
    Write-Warning "Insufficient persmissions to read domains from Get-MgOrganization. Proceed without TenantDomain/TenantOnMicrosoftCom."
}

Write-Host "Tenant (Directory) ID: $TenantId" -ForegroundColor Green

# Create the App
Write-Host -ForegroundColor Green "- Creation of the App $NameApp"

$appParams = @{
    DisplayName    = $NameApp
    Web            = @{ RedirectUris = @("http://localhost/") }
    SignInAudience = "AzureADMultipleOrgs"
}
$app = New-MgApplication @appParams

$appazureid   = $app.Id
$applicationId = $app.AppId

Write-Host "Azure AppID: $appazureid"
Write-Host "Application ID: $applicationId"

$appSp = Get-MgServicePrincipal -Filter "appId eq '$applicationId'"
if (-not $appSp) {
    $appSp = New-MgServicePrincipal -AppId $applicationId
}
$appServicePrincipalId = $appSp.Id

$graphSp = Get-MgServicePrincipal -Filter "DisplayName eq 'Microsoft Graph'" | Select-Object -First 1
$graphId    = $graphSp.Id
$graphResId = $graphSp.AppId

$O365OnlineSp = Get-MgServicePrincipal -Filter "DisplayName eq 'Office 365 Exchange Online'" | Select-Object -First 1
$O365OnlineId    = $O365OnlineSp.Id
$O365OnlineResId = $O365OnlineSp.AppId

Write-Host -ForegroundColor Green "Enable public streams support"
$body = @{
    publicClient = @{
        redirectUris = @("http://localhost/")
    }
    isFallbackPublicClient = $true
}

Update-MgApplication -ApplicationId $appazureid -BodyParameter $body
Start-Sleep -Seconds 5

Write-Host -ForegroundColor Green "Creating the secret"

$AppSecretDescription = "Secret01"
$AppYears = 1
$PasswordCred = @{
    displayName = $AppSecretDescription
    endDateTime = (Get-Date).AddYears($AppYears)
}

$Secret = Add-MgApplicationPassword -ApplicationId $appazureid -PasswordCredential $PasswordCred
$SecretText = $Secret.SecretText
Start-Sleep -Seconds 5

# Save details to a JSON file so that they can be used by other PowerShell scripts
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$NameOutput = "365APP_${NameApp}_$timestamp.json"

$appDetails = @{
    AzureAppID    = $appazureid
    ApplicationID = $applicationId
    TenantID      = $TenantId
    TenantDomain  = $TenantDomain
    TenantOnMicrosoftCom = $TenantOnMicrosoftDomain
    Secret        = $SecretText
    CreatedOn     = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
}

$appDetails | ConvertTo-Json -Depth 5 | Out-File -FilePath $NameOutput -Encoding UTF8
Write-Host -ForegroundColor Green "All the necessary data for ImapSync has been saved in the JSON file $NameOutput"

Write-Host -ForegroundColor Green "Set up the APIs for the app"

$msGraphPermissionsScope = @("EWS.AccessAsUser.All", "IMAP.AccessAsUser.All", "Mail.Send", "Mail.ReadWrite.Shared", "offline_access", "openid", "POP.AccessAsUser.All", "profile", "SMTP.Send", "User.Read", "Sites.ReadWrite.All", "Sites.Manage.All", "Files.ReadWrite.All")
$msGraphPermissionsRole  = @("Mail.Read", "Mail.ReadBasic", "Mail.ReadWrite", "Mail.Send", "Group.Create", "Group.Read.All", "Group.ReadWrite.All", "GroupMember.Read.All", "GroupMember.ReadWrite.All", "Directory.ReadWrite.All", "Sites.ReadWrite.All", "Sites.Manage.All", "Files.ReadWrite.All")

$msO365OnlinePermissionsScope = @("EWS.AccessAsUser.All")
$msO365OnlinePermissionsRole  = @("IMAP.AccessAsApp", "Mail.Read", "Mail.ReadWrite", "Mail.Send")

$resourceAccessArray = @()

Write-Host -ForegroundColor Green "Retrieve Graph Scope permissions IDs"
foreach ($permission in $msGraphPermissionsScope) {
    $permObj = $graphSp.Oauth2PermissionScopes | Where-Object { $_.Value -eq $permission }
    if ($permObj) {
        $resourceAccessArray += @{
            id   = $permObj.Id
            type = "Scope"
        }
    }
}

Write-Host -ForegroundColor Green "Retrieve Graph Role IDs"
foreach ($permission in $msGraphPermissionsRole) {
    $permObj = $graphSp.AppRoles | Where-Object { $_.Value -eq $permission }
    if ($permObj) {
        $resourceAccessArray += @{
            id   = $permObj.Id
            type = "Role"
        }
    }
}

$newResourceAccessGraph = @{
    ResourceAppId  = $graphResId
    ResourceAccess = $resourceAccessArray
}

$resourceAccessArray = @()

Write-Host -ForegroundColor Green "Retrieve the IDs of Office 365 Exchange Online Scope APIs"
foreach ($permission in $msO365OnlinePermissionsScope) {
    $permObj = $O365OnlineSp.Oauth2PermissionScopes | Where-Object { $_.Value -eq $permission }
    if ($permObj) {
        $resourceAccessArray += @{
            id   = $permObj.Id
            type = "Scope"
        }
    }
}

Write-Host -ForegroundColor Green "Retrieve the IDs of Office 365 Exchange Online Role permissions"
foreach ($permission in $msO365OnlinePermissionsRole) {
    $permObj = $O365OnlineSp.AppRoles | Where-Object { $_.Value -eq $permission }
    if ($permObj) {
        $resourceAccessArray += @{
            id   = $permObj.Id
            type = "Role"
        }
    }
}

$newResourceAccessO365Online = @{
    ResourceAppId  = $O365OnlineResId
    ResourceAccess = $resourceAccessArray
}

$resourceAccessArrayMain = @($newResourceAccessGraph, $newResourceAccessO365Online)

Write-Host -ForegroundColor Green "Applying permissions Scope/Role"
Update-MgApplication -ApplicationId $appazureid -RequiredResourceAccess $resourceAccessArrayMain
Start-Sleep -Seconds 5

Write-Host -ForegroundColor Green "Applying administrator consent for Graph Role APIs"
foreach ($permission in $msGraphPermissionsRole) {
    $permObj = $graphSp.AppRoles | Where-Object { $_.Value -eq $permission }
    if ($permObj) {
        $permissionId = $permObj.Id
        $aadSpObjectId = $graphId  # Service Principal di Microsoft Graph
        New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $appServicePrincipalId `
            -AppRoleId $permissionId -PrincipalId $appServicePrincipalId -ResourceId $aadSpObjectId
    }
}

Write-Host -ForegroundColor Green "Apply administrator consent for Office 365 Exchange Online Role APIs"
foreach ($permission in $msO365OnlinePermissionsRole) {
    $permObj = $O365OnlineSp.AppRoles | Where-Object { $_.Value -eq $permission }
    if ($permObj) {
        $permissionId = $permObj.Id
        $aadSpObjectId = $O365OnlineId
        New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $appServicePrincipalId `
            -AppRoleId $permissionId -PrincipalId $appServicePrincipalId -ResourceId $aadSpObjectId
    }
}

Write-Host -ForegroundColor Green "-----"
Write-Host -ForegroundColor Green "App creation $NameApp completed"
Write-Host -ForegroundColor Green "To view it, you can access Azure/Identity in the App Registrations section"
