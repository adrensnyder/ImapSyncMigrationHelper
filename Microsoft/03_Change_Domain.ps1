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

param(
    [string]$orig_domain = "domain.orig",
    [string]$dest_domain = "domain.dest",
	# Set to default the destination domain
    [int]$default = 1
)

$list_users = Get-Mailbox -ResultSize Unlimited |
    Select-Object Identity, DisplayName, WindowsLiveID

foreach ($user in $list_users) {

    $username = $user.WindowsLiveID

    if ([string]::IsNullOrWhiteSpace($username)) {
        continue
    }

    if ($username -notlike "*$orig_domain*") {
        continue
    }

    Write-Host " - Starting the variations for $username" -ForegroundColor Red
    $username_new = $username.Replace($orig_domain, $dest_domain)

    Write-Host "Added alias $username_new on the account $username" -ForegroundColor Green
    Set-Mailbox -Identity $user.Identity -EmailAddresses @{ Add = $username_new }

    Write-Host "Change in $username_new the WindowsEmailAddress value" -ForegroundColor Green
    Set-Mailbox -Identity $user.Identity -WindowsEmailAddress $username_new

    Write-Host "Change in $username_new the MicrosoftOnlineServicesID value" -ForegroundColor Green
    Set-Mailbox -Identity $user.Identity -MicrosoftOnlineServicesID $username_new

    if ($default -eq 1) {

        $mbx = Get-Mailbox -Identity $user.Identity
        $newPrimary = "SMTP:$username_new"
        $otherAddresses = @()

        foreach ($addr in $mbx.EmailAddresses) {
            $addrString = $addr.ToString()

            if ($addrString.ToLower().EndsWith($username_new.ToLower())) {
                continue
            }

            $otherAddresses += $addrString
        }

        $allAddresses = @($newPrimary) + $otherAddresses

        Write-Host "Set $username_new as PrimarySmtpAddress for $($user.Identity)" -ForegroundColor Yellow
        Set-Mailbox -Identity $user.Identity -EmailAddresses $allAddresses
    }
}





