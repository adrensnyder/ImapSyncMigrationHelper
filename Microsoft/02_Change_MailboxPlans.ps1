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

# Print actual status
Write-Host "Actual status of mailbox plans:" -ForegroundColor Yellow
Get-MailboxPlan | ft Name, MaxSendSize, MaxReceiveSize, RetainDeletedItemsFor

# Parameters
$maxSize = 150MB
$retention_days = 30

# Main
$retention = [TimeSpan]::FromDays($retention_days)
$mailboxPlans = Get-MailboxPlan

# Ciclo su ogni mailbox plan
foreach ($plan in $mailboxPlans) {
    Write-Host "Editing mailbox plan: $($plan.Name)" -ForegroundColor Cyan

    try {
        Set-MailboxPlan -Identity $plan.Identity `
            -MaxSendSize $maxSize `
            -MaxReceiveSize $maxSize `
            -RetainDeletedItemsFor $retention

        Write-Host "$($plan.Name) updated.`n" -ForegroundColor Green
    }
    catch {
        Write-Host "$($plan.Name) not updated.`n" -ForegroundColor Red
    }

    
}

# Print result status
Write-Host "Result status of mailbox plans:" -ForegroundColor Yellow
Get-MailboxPlan | ft Name, MaxSendSize, MaxReceiveSize, RetainDeletedItemsFor
