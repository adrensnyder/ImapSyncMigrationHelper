# Print actual status
Write-Host "Actual status of mailbox plans:" -ForegroundColor Yellow
Get-MailboxPlan | ft Name, MaxSendSize, MaxReceiveSize, RetainDeletedItemsFor

# Parameters
$maxSize = 153600KB
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
