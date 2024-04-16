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

Write-Host "It is advisable to start this procedure in the client's Office365 folder created for this job"
Write-Host "In the last release of Chrome can appen that the webpage opened by oAuth2.0 get redirected to https"
Write-Host "Copy the link changing it to http on firefox for every request. Or use Firefox as the default browser"
Pause

# Variables
$NomeApp = "MailMigration"
$REPO = "PSGallery"

#Write-Host "- Credential request"
#$O365CREDS = Get-Credential
#$O365CREDS = New-Object System.Management.Automation.PSCredential $O365CREDS.UserName, $O365CREDS.Password


Write-Host "- Installation prerequisites"

function Install-Modules {
    param (
        [string]$Repo,
        [string]$ModuleName,
        [string]$Version
    )

    if (-not (Get-Module -Name $ModuleName -ListAvailable)) {
        # install the module
        Install-Module -Name $ModuleName -Force -AllowClobber -Scope CurrentUser -Repository $Repo $Version
    } else {
        Write-Host "$ModuleName is already installed"
        if ($Version) {
            Write-Host "Install version $Version"
            Update-Module -Name $ModuleName -Force -RequiredVersion $Version
        }
    }
}

Install-Modules -Repo $REPO -ModuleName "AzureAD" 
Install-Modules -Repo $REPO -ModuleName "Az.*"
Install-Modules -Repo $REPO -ModuleName "Microsoft.PowerApps.Administration.PowerShell"
Install-Modules -Repo $REPO -ModuleName "Microsoft.Graph"
Install-Modules -Repo $REPO -ModuleName "Az.Accounts" -Version "2.12.1"
Install-Modules -Repo $REPO -ModuleName "Az.Resources" -Version "6.6.0"

# Downgreade needed modules
Install-Module -Repository $REPO -Name Az.Accounts -RequiredVersion 2.12.1 -Force 
Install-Module -Repository $REPO -Name Az.Resources -RequiredVersion 6.6.0 -Force

Write-Host "- Importing modules (This may take some time. Ignore any errors if encountered)"

Import-Module Microsoft.PowerApps.Administration.PowerShell
Import-Module AzureAD

Start-Sleep -s 10

# Connect to 365 
Write-Host "- Connecting to 365 (Credentials will be requested multiple times)"

Connect-AzAccount   #-Credential $O365CREDS
Connect-AzureAD     #-Credential $O365CREDS
Connect-MgGraph -Scopes 'Application.ReadWrite.All'

# Create the App
Write-Host "- Creation of the App $NomeApp"

$application = New-AzADApplication -DisplayName $NomeApp -ReplyUrls "http://localhost/" -AvailableToOtherTenants $true

# Obtain the App ID and the Tenant ID
$appazureid = (Get-AzADApplication -DisplayName $NomeApp).Id
$applicationId = (Get-AzADApplication -DisplayName $NomeApp).AppId
$tenantId = (Get-AzContext).Tenant.Id
$graphId = Get-MgServicePrincipal -Filter "DisplayName eq 'Microsoft Graph'" | Select-Object -ExpandProperty Id
$graphResId = Get-MgServicePrincipal -Filter "DisplayName eq 'Microsoft Graph'" | Select-Object -ExpandProperty AppId
$O365OnlineId = Get-MgServicePrincipal -Filter "DisplayName eq 'Office 365 Exchange Online'" | Select-Object -ExpandProperty Id
$O365OnlineResId = Get-MgServicePrincipal -Filter "DisplayName eq 'Office 365 Exchange Online'" | Select-Object -ExpandProperty AppId

# Enable support for public client flows
Write-Host "Enable public streams support"

$azureAdMsApps = Get-AzureADMSApplication
$azureAdMsApp = $azureAdMsApps | Where-Object { $_.AppId -eq $applicationId }
Set-AzureADMSApplication -ObjectId $azureAdMsApp.Id -IsFallbackPublicClient $true

Start-Sleep -s 10

# Create the Secret

Write-Host "Creating the secret"

$AppSecretDescription = "Secret01"
$AppYears = "1"

$PasswordCred = @{
    displayName = $AppSecretDescription
    endDateTime = (Get-Date).AddYears($AppYears)
}

$Secret = Add-MgApplicationPassword -ApplicationId $appazureid -PasswordCredential $PasswordCred
$SecretText = $Secret | Select-Object -ExpandProperty SecretText

Start-Sleep -s 5

# Print the details of the application

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$NomeOutput = "365APP_" + "$NomeApp" + "_" + "$timestamp.txt"

Write-Output  "Details $NomeApp" > .\$NomeOutput
Write-Output  "NOTA: Data needed for IMAP migration" >> .\$NomeOutput
Write-Output  "" >> .\$NomeOutput
Write-Output  "Azure AppID: $appazureid" >> .\$NomeOutput
Write-Output  "Application ID: $applicationId" >> .\$NomeOutput
Write-Output  "Directory (Tenant) ID: $tenantId" >> .\$NomeOutput
Write-Output  "Secret: $SecretText" >> .\$NomeOutput
Write-Host "All the necessary data for ImapSync has been saved in the file $NomeOutput"

Write-Host "- Set up the APIs for the app"

$graphServicePrincipalId = (Get-AzureADServicePrincipal -Filter "AppId eq '$graphId'").ObjectId 
$appServicePrincipalId = (Get-AzureADServicePrincipal -Filter "AppId eq '$applicationId'").ObjectId 
if ($appServicePrincipalId -eq $null) {
    # create a service principal for the app if it does not exist
    $appServicePrincipalId = (New-AzureADServicePrincipal -AppId $applicationId).ObjectId
}

$msGraphPermissions = @("Mail.Read", "Mail.ReadBasic", "Mail.ReadBasic.All", "Mail.ReadWrite", "Mail.Send", "EWS.AccessAsUser.All", "IMAP.AccessAsUser.All", "Mail.Send", "offline_access", "openid", "POP.AccessAsUser.All", "profile", "SMTP.Send", "User.Read")

# Definisci i permessi di Microsoft Graph
$msGraphPermissionsScope = @("EWS.AccessAsUser.All", "IMAP.AccessAsUser.All", "Mail.Send", "Mail.ReadWrite.Shared", "offline_access", "openid", "POP.AccessAsUser.All", "profile", "SMTP.Send", "User.Read")
$msGraphPermissionsRole = @("Mail.Read", "Mail.ReadBasic", "Mail.ReadWrite", "Mail.Send")

$msO365OnlinePermissionsScope = @("EWS.AccessAsUser.All")
$msO365OnlinePermissionsRole = @("IMAP.AccessAsApp","Mail.Read","Mail.ReadWrite","Mail.Send")

# Initialize a main array
$resourceAccessArrayMain = @()

# Initialize an array for the authorizations
$resourceAccessArray = @()

Write-Host "Retrieve Graph Scope permissions IDs"

# Populate the array with permissions from $msGraphPermissions
foreach ($permission in $msGraphPermissionsScope) {
    $permissionId = (Get-AzureADServicePrincipal -ObjectId $graphId).Oauth2Permissions | Where-Object {$_.Value -eq $permission} | Select-Object -ExpandProperty Id

    if ($permissionId -ne $null) {
        $resourceAccessArray += @{
            id   = $permissionId
            type = "Scope"
            #name = $permission
        }
    }
}

Write-Host "Retrieve Graph Role IDs"

foreach ($permission in $msGraphPermissionsRole) {
    $permissionId = (Get-AzureADServicePrincipal -ObjectId $graphId).appRoles | Where-Object {$_.Value -eq $permission} | Select-Object -ExpandProperty Id

    if ($permissionId -ne $null) {
        $resourceAccessArray += @{
            id   = $permissionId
            type = "Role"
            #name = $permission
        }
    }
}

# Create the object $newResourceAccess
$newResourceAccessGraph = @{
    ResourceAppId  = $graphResId
    ResourceAccess = $resourceAccessArray
}

# DEBUG: Print the item RecourceAccess
# $newResourceAccessGraph.ResourceAccess

$resourceAccessArrayMain += $newResourceAccessGraph

# Initialize an array for the authorizations
$resourceAccessArray = @()

Write-Host "Retrieve the IDs of Office 365 Exchange Online Scope APIs"

foreach ($permission in $msO365OnlinePermissionsScope) {
    $permissionId = (Get-AzureADServicePrincipal -ObjectId $O365OnlineId).Oauth2Permissions | Where-Object {$_.Value -eq $permission} | Select-Object -ExpandProperty Id

    if ($permissionId -ne $null) {
        $resourceAccessArray += @{
            id   = $permissionId
            type = "Scope"
            #name = $permission
        }
    }
}

Write-Host "Retrieve the IDs of Office 365 Exchange Online Role permissions"

foreach ($permission in $msO365OnlinePermissionsRole) {
    $permissionId = (Get-AzureADServicePrincipal -ObjectId $O365OnlineId).appRoles | Where-Object {$_.Value -eq $permission} | Select-Object -ExpandProperty Id

    if ($permissionId -ne $null) {
        $resourceAccessArray += @{
            id   = $permissionId
            type = "Role"
            #name = $permission
        }
    }
}

# Create the object $newResourceAccess
$newResourceAccessO365Online = @{
    ResourceAppId  = $O365OnlineResId
    ResourceAccess = $resourceAccessArray
}

# DEBUG: Print the item RecourceAccess 
# $newResourceAccessO365Online.ResourceAccess

$resourceAccessArrayMain += $newResourceAccessO365Online

Write-Host "Applying permissions Scope/Role"

$app = Get-MgApplication -ApplicationId $appazureId

$existingResourceAccess = $app.RequiredResourceAccess

$existingResourceAccess += $resourceAccessArrayMain
Update-MgApplication -ApplicationId $appazureId -RequiredResourceAccess $resourceAccessArrayMain

Start-Sleep -s 10

Write-Host "Applying administrator consent for Graph Role APIs"

foreach ($permission in $msGraphPermissionsRole) {
    # Id of the application permission (role)
    $permissionId = (Get-AzureADServicePrincipal -ObjectId $graphId).appRoles | Where-Object {$_.Value -eq $permission} | Select-Object -ExpandProperty Id

    # Object Id of the concerned Service Principal (could be Graph or SharePoint for example)
    # (Not the Application Id like "00000003-0000-0ff1-ce00-000000000000" for SharePoint)
    $aadSpObjectId = $graphId

    #write-host $permission 
    #write-host $permissionId
    #write-host $aadSpObjectId

    # Register the application permission
    New-AzureADServiceAppRoleAssignment -ObjectId $appServicePrincipalId -Id $permissionId -PrincipalId $appServicePrincipalId -ResourceId $aadSpObjectId
}

Write-Host "Apply administrator consent for Office 365 Exchange Online Role APIs"

foreach ($permission in $msO365OnlinePermissionsRole) {
    # Id of the application permission (role)
    $permissionId = (Get-AzureADServicePrincipal -ObjectId $O365OnlineId).appRoles | Where-Object {$_.Value -eq $permission} | Select-Object -ExpandProperty Id

    # Object Id of the concerned Service Principal (could be Graph or SharePoint for example)
    # (Not the Application Id like "00000003-0000-0ff1-ce00-000000000000" for SharePoint)
    $aadSpObjectId = $O365OnlineId

    #write-host $permission 
    #write-host $permissionId
    #write-host $aadSpObjectId

    # Register the application permission
    New-AzureADServiceAppRoleAssignment -ObjectId $appServicePrincipalId -Id $permissionId -PrincipalId $appServicePrincipalId -ResourceId $aadSpObjectId
}

Write-Host "-----"
Write-Host "App creation $NomeApp completed"
Write-Host "To view it, you can access Azure/Identity in the App Registrations section"
