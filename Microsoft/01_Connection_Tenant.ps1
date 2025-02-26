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

$REPO = "PSGallery"

$O365CREDS = Get-Credential

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

Install-Modules -Repo $REPO -ModuleName "AzureAD"
Install-Modules -Repo $REPO -ModuleName "MSOnline"
Install-Modules -Repo $REPO -ModuleName "ExchangeOnlineManagement"
Install-Modules -Repo $REPO -ModuleName "MicrosoftTeams"

Import-Module AzureAD
Import-Module MSOnline 
Import-Module ExchangeOnlineManagement
Import-Module MicrosoftTeams

Connect-MsolService -Credential $O365CREDS 
Connect-AzureAD -Credential $O365CREDS 
Connect-ExchangeOnline -ShowProgress $true -Credential $O365CREDS 