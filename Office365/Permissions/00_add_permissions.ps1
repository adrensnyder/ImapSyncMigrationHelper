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

$mailbox_arg = $args[0]
$file_arg = $args[1]
$access = "FullAccess"
$mailbox = Get-Mailbox -Identity $mailbox_arg
$identity = $mailbox.UserPrincipalName
$permissions = Get-MailboxPermission -identity $identity

Import-Csv -Path $file_arg | ForEach-Object {
	
    Write-Host "Applying permissions for $($_.Delegate) (AutoMapping $($_.AutoMapping))"
    try{
        $setPermissions = Add-MailboxPermission -Identity $identity -User $($_.Delegate) -AccessRights $access -AutoMapping $($_.AutoMapping)
    }catch{
        Write-Host "[$mailbox] Error applying permissions for $($_.Delegate) " -ForegroundColor Red
    }
    
    try{
        $setPermissions = Add-RecipientPermission -Identity $identity -Trustee $($_.Delegate) -AccessRights SendAs -confirm:$false
    }catch{
        Write-Host "[$mailbox SendAs] Error applying permissions for $($_.Delegate) " -ForegroundColor Red
    }
    
}