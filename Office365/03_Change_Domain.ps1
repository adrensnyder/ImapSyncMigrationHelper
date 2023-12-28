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

$orig_domain = "domain.orig"
$dest_domain = "domain.dest"
$list_users = get-mailbox |select-object WindowsLiveID
$username = ""

foreach ($username_obj in $list_users) { 
	if ($username_obj -ne $null) {
		Write-Host " - Starting the variations for $username" -ForegroundColor Red
		$username = $($username_obj.WindowsLiveID)
		$username_new = $username.replace($orig_domain,$dest_domain)
		Write-Host "Added alias $username_new on the account $username" -ForegroundColor Green
		Set-Mailbox -identity $username -EmailAddresses @{Add=$username_new}
		Write-Host "Change in $username_new the WindowsEmailAddress value" -ForegroundColor Green
		Set-Mailbox -Identity $username -WindowsEmailAddress $username_new
		Write-Host "Change in $username_new the MicrosoftOnlineServicesID value" -ForegroundColor Green
		Set-Mailbox -Identity $username -MicrosoftOnlineServicesID $username_new
	}
}




