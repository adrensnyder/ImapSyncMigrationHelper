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

# Variable
$JsonFilePath = "Path\App.Json"

# Check that the JSON file exists
if (-not (Test-Path $JsonFilePath)) {
    Write-Error "The file '$JsonFilePath' does not exist. You need to change JsonFilePath variabile with the App Json created with 00_CreateApp.ps1"
    exit 1
}

# Read and convert JSON file
try {
    $jsonContent = Get-Content -Path $JsonFilePath -Raw | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse JSON file: $_"
    exit 1
}

$secureSecret = ConvertTo-SecureString $jsonContent.Secret -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($jsonContent.ApplicationID, $secureSecret)

# Display retrieved values (do not print the secret for security reasons)
Write-Host "Using Tenant ID: $($jsonContent.TenantID)"
Write-Host "Using Application (Client) ID: $($jsonContent.ApplicationID)"

$REPO = "PSGallery"

function Install-Modules {
    param (
        [string]$Repo,
        [string]$ModuleName
    )

    $REPO="PSGallery"
    if (-not (Get-Module -Name $ModuleName -ListAvailable)) {
        # install the module
        Write-Host "Install $ModuleName"
        Install-Module -Name $ModuleName -Force -AllowClobber -Scope CurrentUser -Repository $Repo
    } else {
        Write-Host "$ModuleName is already installed."
    }
}

Install-Modules -Repo $REPO -ModuleName "ExchangeOnlineManagement"
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Install-Module -Repo $REPO -Name Microsoft.Graph -Force -AllowClobber
}

Import-Module ExchangeOnlineManagement

Connect-ExchangeOnline -ShowProgress $true
Disconnect-MgGraph
Start-Sleep -Seconds 5
Connect-MgGraph "User.ReadWrite" "User-PasswordProfile.ReadWrite.All" "User-Mail.ReadWrite.All" "Directory.ReadWrite.All" "DeviceManagementServiceConfig.ReadWrite.All" "DeviceManagementManagedDevices.ReadWrite.All" "DeviceManagementConfiguration.ReadWrite.All"

try {
    $org = Get-MgOrganization | Select-Object -First 1
    Write-Host "Organization Display Name: $($org.DisplayName)"
} catch {
    Write-Error "Failed to retrieve organization info: $_"
}
