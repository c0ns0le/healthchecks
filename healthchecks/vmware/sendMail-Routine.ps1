param(	[string] $smtpServer,  
		[string] $from, 
		[string] $replyTo, 
		[string] $toAddress,
		[string] $subject, 
		[string] $body,
		[object] $attachments # An array of filenames with their full path locations
		)  

#Write-Host "[$attachments]" -ForegroundColor Blue
if (!$smtpServer -or !$from -or !$replyTo -or !$toAddress -or !$subject -or !$body)
{
	Write-Host "Cannot Send email. Missing parameters for this function. Note that All fields must be specified" -BackgroundColor Red -ForegroundColor Yellow
	Write-Host "smtpServer = $smtpServer"
	Write-Host "from = $from"
	Write-Host "replyTo = $replyTo"
	Write-Host "toAddress = $toAddress"
	Write-Host "subject = $subject"
	Write-Host "body = $body"
} else {
	#Creating a Mail object
	$msg = new-object Net.Mail.MailMessage
	#Creating SMTP server object
	$smtp = new-object Net.Mail.SmtpClient($smtpServer)
	#Email structure
	$msg.From = $from
	$msg.ReplyTo = $replyTo
	$msg.To.Add($toAddress)
	$msg.subject = $subject
	$msg.IsBodyHtml = $true
	$msg.body = $body.ToString();
	$msg.DeliveryNotificationOptions = "OnFailure"
	
	if ($attachments)
	{
		$attachments | %{
			Write-Host "Attachment from within the routine: $_"
			Write-Host $_ -ForegroundColor Blue
			$attachment = new-object System.Net.Mail.Attachment($_, ‘Application/Octet’)
			$msg.Attachments.Add($attachment)
		}
	} else {
		Write-Host "No attachments found"
	}
	
	Write-Host "Sending email from within this routine"
	$smtp.Send($msg)
}


