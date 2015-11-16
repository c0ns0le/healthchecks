#region Core Utility Functions

function global:Get-PSResourceString {
	param(
		[string]$BaseName = $null,
		[string]$ResourceId = $null,
		[string]$DefaultValue = $null,
		[System.Globalization.CultureInfo]$Culture = $host.CurrentCulture,
		[Switch]$List
	)

	if ($List -and ($ResourceId -or $DefaultValue)) {
		throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'AmbiguousParameterSet')
	}

	if ($List) {
		$engineAssembly = [System.Reflection.Assembly]::GetExecutingAssembly()
		$hostAssembly = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.PowerShell.ConsoleHost')
		if ($BaseName) {
			$engineAssembly.GetManifestResourceNames() | Where-Object { $_ -eq "$BaseName.resources" } | ForEach-Object {
				$resourceManager = New-Object -TypeName System.Resources.ResourceManager($BaseName, $engineAssembly)
				$resourceManager.GetResourceSet($host.CurrentCulture,$true,$true) | Add-Member -Name BaseName -MemberType NoteProperty -Value $BaseName -Force -PassThru | ForEach-Object {
					$_.PSObject.TypeNames.Clear()
					$_.PSObject.TypeNames.Add('ResourceString')
					$_ | Write-Output
				}
			}
			$hostAssembly.GetManifestResourceNames() | Where-Object { $_ -eq "$BaseName.resources" } | ForEach-Object {
				$resourceManager = New-Object -TypeName System.Resources.ResourceManager($BaseName, $hostAssembly)
				$resourceManager.GetResourceSet($host.CurrentCulture,$true,$true) | Add-Member -Name BaseName -MemberType NoteProperty -Value $BaseName -Force -PassThru | ForEach-Object {
					$_.PSObject.TypeNames.Clear()
					$_.PSObject.TypeNames.Add('ResourceString')
					$_ | Write-Output
				}
			}
		} else {
			$engineAssembly.GetManifestResourceNames() | Where-Object { $_ -match '\.resources$' } | ForEach-Object { $_.Replace('.resources','') }
			$hostAssembly.GetManifestResourceNames() | Where-Object { $_ -match '\.resources$' } | ForEach-Object { $_.Replace('.resources','') }
		}
	} else {
		if (-not $BaseName) {
			throw $($(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'ParameterArgumentValidationErrorNullNotAllowed') -f $null,'BaseName')
		}
		if (-not $ResourceId) {
			throw $($(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'ParameterArgumentValidationErrorNullNotAllowed') -f $null,'ResourceId')
		}
		if (-not $global:PSResourceStringTable) {
			$engineAssembly = [System.Reflection.Assembly]::GetExecutingAssembly()
			$hostAssembly = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.PowerShell.ConsoleHost')
			if ($engineAssembly.GetManifestResourceNames() -contains "$BaseName.resources") {
				New-Variable -Scope Global -Name PSResourceStringTable -Value @{} -Description 'A cache of PowerShell resource strings. To access data in this table, use Get-ResourceString.'
				$global:PSResourceStringTable['EngineAssembly'] = @{'Assembly'=$engineAssembly;'Cultures'=@{}}
				$global:PSResourceStringTable['HostAssembly'] = @{'Assembly'=$hostAssembly;'Cultures'=@{}}
				$resourceManager = (New-Object -TypeName System.Resources.ResourceManager($BaseName, $global:PSResourceStringTable.EngineAssembly.Assembly));
				$global:PSResourceStringTable.EngineAssembly.Cultures[$Culture.Name] = @{$BaseName=@{'ResourceManager'=$resourceManager;'Strings'=$resourceManager.GetResourceSet($Culture,$true,$true)}};
			} elseif ($hostAssembly.GetManifestResourceNames() -contains "$BaseName.resources") {
				New-Variable -Scope Global -Name PSResourceStringTable -Value @{} -Description 'A cache of PowerShell resource strings. To access data in this table, use Get-ResourceString.'
				$global:PSResourceStringTable['EngineAssembly'] = @{'Assembly'=$engineAssembly;'Cultures'=@{}}
				$global:PSResourceStringTable['HostAssembly'] = @{'Assembly'=$hostAssembly;'Cultures'=@{}}
				$resourceManager = (New-Object -TypeName System.Resources.ResourceManager($BaseName, $global:PSResourceStringTable.HostAssembly.Assembly));
				$global:PSResourceStringTable.HostAssembly.Cultures[$Culture.Name] = @{$BaseName=@{'ResourceManager'=$resourceManager;'Strings'=$resourceManager.GetResourceSet($Culture,$true,$true)}};
			}
		} elseif ($global:PSResourceStringTable.EngineAssembly.Assembly.GetManifestResourceNames() -contains "$BaseName.resources") {
			if (-not $global:PSResourceStringTable.EngineAssembly.Cultures.ContainsKey($Culture.Name)) {
				$resourceManager = (New-Object -TypeName System.Resources.ResourceManager($BaseName, $global:PSResourceStringTable.EngineAssembly.Assembly));
				$global:PSResourceStringTable.EngineAssembly.Cultures[$Culture.Name] = @{$BaseName=@{'ResourceManager'=$resourceManager;'Strings'=$resourceManager.GetResourceSet($Culture,$true,$true)}};
			} elseif (-not $global:PSResourceStringTable.EngineAssembly.Cultures[$Culture.Name].ContainsKey($BaseName)) {
				$resourceManager = (New-Object -TypeName System.Resources.ResourceManager($BaseName, $global:PSResourceStringTable.EngineAssembly.Assembly));
				$global:PSResourceStringTable.EngineAssembly.Cultures[$Culture.Name][$BaseName] = @{'ResourceManager'=$resourceManager;'Strings'=$resourceManager.GetResourceSet($Culture,$true,$true)};
			}
		} elseif ($global:PSResourceStringTable.HostAssembly.Assembly.GetManifestResourceNames() -contains "$BaseName.resources") {
			if (-not $global:PSResourceStringTable.HostAssembly.Cultures.ContainsKey($Culture.Name)) {
				$resourceManager = (New-Object -TypeName System.Resources.ResourceManager($BaseName, $global:PSResourceStringTable.HostAssembly.Assembly));
				$global:PSResourceStringTable.HostAssembly.Cultures[$Culture.Name] = @{$BaseName=@{'ResourceManager'=$resourceManager;'Strings'=$resourceManager.GetResourceSet($Culture,$true,$true)}};
			} elseif (-not $global:PSResourceStringTable.HostAssembly.Cultures[$Culture.Name].ContainsKey($BaseName)) {
				$resourceManager = (New-Object -TypeName System.Resources.ResourceManager($BaseName, $global:PSResourceStringTable.HostAssembly.Assembly));
				$global:PSResourceStringTable.HostAssembly.Cultures[$Culture.Name][$BaseName] = @{'ResourceManager'=$resourceManager;'Strings'=$resourceManager.GetResourceSet($Culture,$true,$true)};
			}
		}

		$resourceString = $null
		if ($global:PSResourceStringTable) {
			if ($global:PSResourceStringTable.EngineAssembly.Cultures -and $global:PSResourceStringTable.EngineAssembly.Cultures.ContainsKey($Culture.Name) -and $global:PSResourceStringTable.EngineAssembly.Cultures[$Culture.Name].ContainsKey($BaseName)) {
				$resourceString = ($global:PSResourceStringTable.EngineAssembly.Cultures[$Culture.Name][$BaseName].Strings | Where-Object { $_.Name -eq $ResourceId }).Value
			} elseif ($global:PSResourceStringTable.HostAssembly.Cultures -and $global:PSResourceStringTable.HostAssembly.Cultures.ContainsKey($Culture.Name) -and $global:PSResourceStringTable.HostAssembly.Cultures[$Culture.Name].ContainsKey($BaseName)) {
				$resourceString = ($global:PSResourceStringTable.HostAssembly.Cultures[$Culture.Name][$BaseName].Strings | Where-Object { $_.Name -eq $ResourceId }).Value
			}
		}
		if (-not $resourceString) {
			$resourceString = $DefaultValue
		}
		
		return $resourceString
	}
}

function global:New-Enum {
	param(
		[string]$Name = $null,
		[string]$AssemblyName = $null,
		[System.Management.Automation.PSObject]$Values = $null
	)

	$internalScript = {
		param(
			[string]$Name = $null,
			[string]$AssemblyName = $null,
			[System.Management.Automation.PSObject]$Values = $null
		)

		$promptedForRequiredParameters = $false
		if ((-not $promptedForRequiredParameters) -and ((-not $Name) -or ((-not $Values) -and (-not $Values.Count) -and (-not $Values.Keys.Count)))) {
			$promptedForRequiredParameters = $true
			Write-Host -ForegroundColor White -Object ((Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptCaption) -f 'New-Enum',$MyInvocation.PipelinePosition)
			Write-Host (Get-PSResourceString -BaseName -ResourceId PromptMessage)
			if (-not $Name) {
				if ($result = Read-Host -Prompt 'Name') {
					$Name = $result
				} else {
					return
				}
			}
			if (-not $Values) {
				$index = 0
				$Values = @()
				while ($result = Read-Host -Prompt "Values[$index]") {
					$index++
					$Values += $result
				}
				if (-not $Values) {
					return
				}
			}
		}

		$appdomain = [System.Threading.Thread]::GetDomain()
		$assembly = New-Object -TypeName System.Reflection.AssemblyName
		if ($AssemblyName) {
			$assembly.Name = $AssemblyName
			$Name = "$AssemblyName.$Name"
		} else {
			$assembly.Name = 'DynamicallyCreatedEnum'
		}

		$assemblyBuilder = $appdomain.DefineDynamicAssembly(
			$assembly,
			[System.Reflection.Emit.AssemblyBuilderAccess]::Save -bor [System.Reflection.Emit.AssemblyBuilderAccess]::Run
		)

		$moduleBuilder = $assemblyBuilder.DefineDynamicModule("DynamicModule", "DynamicModule.mod")

		$enumBuilder = $moduleBuilder.DefineEnum($Name, [System.Reflection.TypeAttributes]::Public, [int32])

		if (($Values -is [string]) -or ($Values -is [array])) {
			$Values = @($Values) + $args
			for ($i = 0; $i -lt $Values.Length; $i++) {
				$enumBuilder.DefineLiteral($Values[$i],$i) | Out-Null
			}
		} elseif ($Values -is [System.Collections.Hashtable]) {
			foreach ($key in $Values.Keys) {
				$enumBuilder.DefineLiteral($key,$Values[$key]) | Out-Null
			}
		}

		$enumBuilder.CreateType()
	}

	$passThruArgs = $args
	$trailingArguments = ''
	for ($index = 0; $index -lt $passThruArgs.Count; $index++) {
		$trailingArguments += " `$passThruArgs[$index]"
	}
	#region Extra script to workaround PowerShell v2 defect.
	if (-not ('DynamicEnum.Initializer' -as [System.Type])) {
		Invoke-Expression "& `$internalScript -Name 'Initializer' -AssemblyName 'DynamicEnum' -Values 'Initialized' | Out-Null"
		Invoke-Expression "& `$internalScript -Name 'Initializer' -AssemblyName 'DynamicEnum' -Values 'Initialized' | Out-Null"
	}
	#endregion
	Invoke-Expression "& `$internalScript -Name `$Name -AssemblyName `$AssemblyName -Values `$Values$trailingArguments"
}

#endregion
#region Read Input Functions

function global:New-ChoiceDescription {
	param(
		[string]$Name,
		[string]$HelpMessage = $null
	)

	$choiceDescription = [System.Management.Automation.Host.ChoiceDescription]$Name
	$choiceDescription.HelpMessage = $HelpMessage

	$choiceDescription
}

function global:Read-Choice {
	param(
		[string]$Caption,
		[string]$Message,
		[System.Management.Automation.Host.ChoiceDescription[]]$ChoiceDescription,
		[int]$DefaultChoice = 0
	)

	$host.ui.PromptForChoice($Caption,$Message,$ChoiceDescription,$DefaultChoice)
}

function global:New-FieldDescription {
	param(
		[string]$Name,
		[string]$HelpMessage = $null,
		[Type]$Type = [Type]'System.String',
		[PSObject]$DefaultValue = $null,
		[bool]$IsMandatory = $false
	)

	$fieldDescription = [System.Management.Automation.Host.FieldDescription]$Name
	$fieldDescription.SetParameterType($Type)
	$fieldDescription.DefaultValue = $DefaultValue
	$fieldDescription.HelpMessage = $HelpMessage
	$fieldDescription.IsMandatory = $IsMandatory

	$fieldDescription
}

function global:Read-Input {
	param(
		[string]$Caption,
		[string]$Message,
		[System.Management.Automation.Host.FieldDescription[]]$FieldDescription
	)

	$host.ui.Prompt($Caption,$Message,$FieldDescription)
}

function global:New-Credential {
	param(
		[string]$Username,
		[System.Security.SecureString]$Password
	)
	
	New-Object System.Management.Automation.PSCredential($Username,$Password)
}

function global:Read-Credential {
	param(
		$Credential = $null
	)

	if ($Credential -is [System.Management.Automation.PSCredential]) {
		$Credential
	} else {
		$result = Read-Input 'Enter your credentials' 'Please enter your authentication credentials in the fields provided' @((New-FieldDescription 'Username' 'Your account username' 'System.String' $Credential $true),(New-FieldDescription 'Password' 'Your account password' 'System.Security.SecureString' $null $true))
		if ($result.Count) {
			New-Credential -Username $result['Username'] -Password $result['Password']
		}
	}
}

function global:Read-AdminConsoleCmdletInput {
	param(
		[string]   $AdminConsoleCommandName,
		[string]   $CmdletName,
		[String[]] $PromptParameterNames
	)
	#region Initialize local variables.
	[System.Management.Automation.CmdletInfo]              $cmdlet            = $null
	[System.Management.Automation.CommandParameterInfo[]]  $allParameters     = $null
	[System.Management.Automation.CommandParameterInfo[]]  $promptParameters  = $null
	[PSObject]                                             $item              = $null
	[System.Management.Automation.Host.FieldDescription[]] $fieldDescriptions = $null
	[PSObject]                                             $result            = $null
	#endregion

	#region Prompt for input if there are missing parameters.
	#endregion

	#region Get the cmdlet information.
	$cmdlet = Get-Command -CommandType Cmdlet -Name $CmdletName
	$allParameters = @($cmdlet | Select-Object -ExpandProperty ParameterSets | Select-Object -ExpandProperty Parameters)
	#endregion

	#region Build the list of prompt parameters.
	$item = $null
	$promptParameters = @()
	foreach ($item in $PromptParameterNames) {
		$promptParameters += $allParameters `
			| Where-Object {$_.Name -eq $item} `
			| Select-Object -First 1
	}
	#endregion

	#region Build the field description objects.
	$fieldDescriptions = @()
	$item = $null
	foreach ($item in $promptParameters) {
		$fieldDescriptions += New-FieldDescription -Name $item.Name -HelpMessage ([System.String]::Join("`n",@(Get-Help -Name $CmdletName -Parameter $item.Name | Select-Object -ExpandProperty Description | ForEach-Object {$_.Text}))) -Type $item.ParameterType -DefaultValue $null -IsMandatory $true
	}
	#endregion

	#region Prompt the user for input.
	$result = Read-Input -Caption "$AdminConsoleCommandName Parameters" -Message 'Please supply parameters for this action.' -FieldDescription $FieldDescriptions
	#endregion

	#region If the user cancelled, return.
	if (-not $result.Count) {
		return
	}
	#endregion

	#region Return the results to the client.
	$result
	#endregion
}

#endregion
#region Password Management Functions

function global:Get-Password {
	param(
		$InputObject = $null,
		[Switch]$AsPlainText,
		[Switch]$Force
	)

	begin {
		if ($AsPlainText -and (-not $Force)) {
			throw 'Get-Password: The system cannot protect plain text output.  To suppress this warning and get the password as plain text, reissue the command specifying the Force parameter.'
		}
	}
	process {
		if ((-not $InputObject) -and (-not $_)) {
			$InputObject = Read-Host -AsSecureString -Prompt 'Password'
		}
		if ($InputObject -and $_) {
			throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
		} elseif ($InputObject -or $_) {
			$processObject = $(if ($InputObject) {$InputObject} else {$_})
			if ($processObject -is [System.Security.SecureString]) {
				$secureStringPassword = $processObject
			} elseif ($processObject.Password -is [System.Security.SecureString]) {
				$secureStringPassword = $processObject.Password
			} elseif ($processObject.Credential.Password -is [System.Security.SecureString]) {
				$secureStringPassword = $processObject.Credential.Password
			} else {
				throw $((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'CannotConvertArgumentNoMessage') -f $null,'InputObject',$null,$null,$null,$null,((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'CannotConvertArgument') -f $null,'InputObject','System.Management.Automation.PSCredential',$null,$null,$null,$_.ToString(),$null))
			}
			if ($AsPlainText -and $Force) {
				$bstrPassword = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureStringPassword)
				$plainTextPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstrPassword)
				[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstrPassword)
				$plainTextPassword
			} else {
				$secureStringPassword
			}
		}
	}
}

function global:Compare-Password {
	param (
		[System.Security.SecureString]$ReferencePassword,
		[System.Security.SecureString]$DifferencePassword
	)

	begin {
		if (-not $ReferencePassword) {
			Write-Host -ForegroundColor White -Object "function Compare-Password at command pipeline position $($MyInvocation.PipelinePosition)"
			Write-Host 'Supply values for the following parameters:'
			if ($result = Read-Host -AsSecureString -Prompt 'ReferencePassword') {
				$ReferencePassword = $result
			} else {
				return
			}
		}
	}

	process {
		if ($DifferencePassword -and $_) {
			throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'AmbiguousParameterSet')
		}
		if (-not $DifferencePassword -and -not $_) {
			if ($result = Read-Host -AsSecureString -Prompt 'DifferencePassword') {
				$DifferencePassword = $result
			} else {
				return
			}
		}
		$processObject = $(if ($DifferencePassword) {$DifferencePassword} else {$_})
		if ($processObject -is [System.Security.SecureString]) {
			$secureStringPassword = $processObject
		} elseif ($processObject.Password -is [System.Security.SecureString]) {
			$secureStringPassword = $processObject.Password
		} elseif ($processObject.Credential.Password -is [System.Security.SecureString]) {
			$secureStringPassword = $processObject.Credential.Password
		} else {
			throw $((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'CannotConvertArgumentNoMessage') -f $null,'DifferencePassword',$null,$null,$null,$null,((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'CannotConvertArgument') -f $null,'DifferencePassword','System.Security.SecureString',$null,$null,$null,$_.ToString(),$null))
		}
		(Get-Password $ReferencePassword -AsPlainText -Force) -eq (Get-Password $processObject -AsPlainText -Force)
	}
}

function global:Read-Password {
	param (
		[switch]$Confirm
	)

	[System.Security.SecureString]$password
	[System.Security.SecureString]$confirmPassword
	if ($result = Read-Host -AsSecureString -Prompt 'Password') {
		$password = $result
	} else {
		return
	}
	if ($Confirm) {
		if ($result = (Read-Host -AsSecureString -Prompt 'Confirm password')) {
			$confirmPassword = $result
		} else {
			return
		}
		if (Compare-Password -ReferencePassword $password -DifferencePassword $confirmPassword) {
			$password
		} else {
			Write-Error 'The passwords you entered did not match.'
		}
	} else {
		$password
	}
}

#endregion
#region Credential Caching Functions

#region CredentialCache functions

# Syntax:
#     Get-CredentialCache
function global:Get-CredentialCache {
	process {
		if ($_) {
			throw (Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
		} else {
			if (-not (Get-Variable -Scope Global -Name CredentialCache -ErrorAction SilentlyContinue)) {
				$global:CredentialCache = New-Object System.Management.Automation.PSObject `
					| Add-Member -MemberType NoteProperty -Name Enabled -Value $true -PassThru `
					| Add-Member -MemberType NoteProperty -Name CredentialStore -Value @{} -PassThru `
					| Add-Member -MemberType NoteProperty -Name ObjectAssociations -Value @{} -PassThru
				$global:CredentialCache.PSObject.TypeNames[0] = 'CredentialCache'
			}
			$global:CredentialCache
		}
	}
}

# Syntax:
#     Enable-CredentialCache [-PassThru <Switch>]
function global:Enable-CredentialCache {
	param(
		[Switch]$PassThru
	)
	process {
		if ($_) {
			if ($_.PSObject.TypeNames[0] -eq 'CredentialCache') {
				$_.Enabled = $true
				if ($PassThru) {$_}
			} else {
				throw (Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
			}
		} else {
			$credentialCache = Get-CredentialCache
			$credentialCache.Enabled = $true
			if ($PassThru) {$credentialCache}
		}
	}
}

# Syntax:
#     Disable-CredentialCache [-PassThru <Switch>]
function global:Disable-CredentialCache {
	param(
		[Switch]$PassThru
	)
	process {
		if ($_) {
			if ($_.PSObject.TypeNames[0] -eq 'CredentialCache') {
				$_.Enabled = $false
				if ($PassThru) {$_}
			} else {
				throw (Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
			}
		} else {
			$credentialCache = Get-CredentialCache
			$credentialCache.Enabled = $false
			if ($PassThru) {$credentialCache}
		}
	}
}

# Syntax:
#     Remove-CredentialCache
function global:Remove-CredentialCache {
	process {
		if ($_) {
			throw (Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
		} else {
			Remove-Variable -Scope Global -Name CredentialCache -ErrorAction SilentlyContinue
		}
	}
}

#endregion
#region CachedCredential functions

# Syntax:
#     Add-CachedCredential [-Credential] <System.Management.Automation.PSObject> [[-AssociatedObjectId] <string[]>] [-Force <Switch>]
function global:Add-CachedCredential {
	param(
		$Credential = $(throw ((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'ParameterArgumentValidationErrorNullNotAllowed') -f $null,'Credential')),
		[string[]]$AssociatedObjectId = $null,
		[Switch]$Force
	)
	$credentialCache = Get-CredentialCache
	if (-not $credentialCache.Enabled) {
		Write-Warning 'Credential caching is not enabled.'
		return
	}
	[string]$userName = $null
	if ($Credential -is [System.Management.Automation.PSCredential]) {
		if (($credentialCache.CredentialStore.Keys -contains $Credential.UserName.TrimStart('\')) -and (-not $Force)) {
			throw "Cannot add credential for '$($Credential.UserName.TrimStart('\'))' because credentials for that user are already stored. Use the -Force to overwrite the stored credentials for '$($Credential.UserName.TrimStart('\'))'."
		}
		if (($credentialCache.CredentialStore.Keys -notcontains $Credential.UserName.TrimStart('\')) -or (($cachedCredential = $credentialCache.CredentialStore[$Credential.UserName.TrimStart('\')]) -and (-not (Compare-Password -ReferencePassword $cachedCredential.Credential.Password -DifferencePassword $credential.Password)))) {
			$credentialCache.CredentialStore[$Credential.UserName.TrimStart('\')] = @{'Credential'=$Credential;'DateStored'=Get-Date;'LastAccessDate'=$null}
		}
		$credentialCache.CredentialStore[$Credential.UserName.TrimStart('\')].LastAccessDate = Get-Date
		$userName = $Credential.UserName.TrimStart('\')
	} else {
		$userName = $Credential.TrimStart('\')
	}
	Add-CacheAssociation -AssociatedObjectId $AssociatedObjectId -UserName $userName -Force:$Force
}

# Syntax:
#     Refresh-CachedCredential [[-UserName] <string>]
function global:Refresh-CachedCredential {
	param(
		[string]$UserName = $null
	)
	$credentialCache = Get-CredentialCache
	if ($keysToRefresh = $(if ($UserName) {$credentialCache.CredentialStore.Keys -like $UserName.TrimStart('\')} else {$credentialCache.CredentialStore.Keys})) {
		foreach ($item in $keysToRefresh) {
			$credentialCache.CredentialStore[$item].Credential = New-Credential -UserName $credentialCache.CredentialStore[$item].Credential.UserName -Password $credentialCache.CredentialStore[$item].Credential.Password
		}
	}
}

# Syntax:
#     Get-CachedCredential [-Credential] <System.Management.Automation.PSObject> [-EntireRecord <Switch>]
#     Get-CachedCredential [-AssociatedObjectId] <string> [-EntireRecord <Switch>]
#     Get-CachedCredential -List <switch> [-EntireRecord <Switch>]
function global:Get-CachedCredential {
	param(
		$Credential = $null,
		[string]$AssociatedObjectId = $null,
		[Switch]$List,
		[Switch]$EntireRecord
	)
	if (($Credential -and $AssociatedObjectId) -or (($Credential -or $AssociatedObjectId) -and $List)) {
		throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'AmbiguousParameterSet')
	} elseif ($Credential -and ($Credential -is [string]) -and ($credentialCache = Get-CredentialCache) -and $credentialCache.Enabled) {
		$cachedCredential = $Credential.TrimStart('\')
		Refresh-CachedCredential -UserName $cachedCredential
		if ($EntireRecord) {
			if (($credentialCache.CredentialStore.Keys -notcontains $cachedCredential) -and ($credentialCache.ObjectAssociations.Values -notcontains $cachedCredential)) {
				return
			}
			$credentialCacheRecord = New-Object System.Management.Automation.PSObject `
				| Add-Member -MemberType NoteProperty -Name UserName -Value $cachedCredential -PassThru `
				| Add-Member -MemberType NoteProperty -Name Credential -Value $null -PassThru `
				| Add-Member -MemberType NoteProperty -Name DateStored -Value $null -PassThru `
				| Add-Member -MemberType NoteProperty -Name LastAccessDate -Value $null -PassThru
			$credentialCacheRecord.PSObject.TypeNames[0] = 'CredentialCacheRecord'
			if ($credentialCache.CredentialStore.Keys -contains $cachedCredential) {
				$credentialCacheRecord.Credential = $credentialCache.CredentialStore[$cachedCredential].Credential
				$credentialCacheRecord.DateStored = $credentialCache.CredentialStore[$cachedCredential].DateStored
				$credentialCacheRecord.LastAccessDate = $credentialCache.CredentialStore[$cachedCredential].LastAccessDate
			}
			$credentialCacheRecord
		} else {
			if ($credentialCache.CredentialStore.Keys -notcontains $cachedCredential) {
				& {
					if ($errorActionPreference -ne [System.Management.Automation.ActionPreference]::Stop) {
						$errorActionPreference = 'SilentlyContinue'
					}
					$newCredential = Microsoft.PowerShell.Security\Get-Credential -Credential $cachedCredential
					if ($newCredential) {
						$cachedCredential = $newCredential.UserName.TrimStart('\')
						$credentialCache.CredentialStore[$cachedCredential] = @{'Credential'=$newCredential;'DateStored'=Get-Date;'LastAccessDate'=$null}
						$credentialCache.CredentialStore[$cachedCredential].LastAccessDate = Get-Date
						$credentialCache.CredentialStore[$cachedCredential].Credential
					} else {
						return
					}
				}
			} else {
				$credentialCache.CredentialStore[$cachedCredential].LastAccessDate = Get-Date
				$credentialCache.CredentialStore[$cachedCredential].Credential
			}
		}
	} elseif ($AssociatedObjectId) {
		if (($credentialCache = Get-CredentialCache) -and ($credentialCache.Enabled)) {
			if ($credentialCache.ObjectAssociations.Keys -contains $AssociatedObjectId) {
				Get-CachedCredential -Credential $credentialCache.ObjectAssociations[$AssociatedObjectId] -EntireRecord:$EntireRecord
			}
		}
	} elseif ($List) {
		if ($credentialCache = Get-CredentialCache) {
			Refresh-CachedCredential
			foreach ($item in $credentialCache.CredentialStore.Keys) {
				if ($EntireRecord) {
					$credentialCacheRecord = New-Object System.Management.Automation.PSObject
					$credentialCacheRecord.PSObject.TypeNames[0] = 'CredentialCacheRecord'
					$credentialCacheRecord `
						| Add-Member -MemberType NoteProperty -Name UserName -Value $item -PassThru `
						| Add-Member -MemberType NoteProperty -Name Credential -Value $credentialCache.CredentialStore[$item].Credential -PassThru `
						| Add-Member -MemberType NoteProperty -Name DateStored -Value $credentialCache.CredentialStore[$item].DateStored -PassThru `
						| Add-Member -MemberType NoteProperty -Name LastAccessDate -Value $credentialCache.CredentialStore[$item].LastAccessDate -PassThru
				} else {
					$credentialCache.CredentialStore[$item].Credential
				}
			}
		}
	} else {
		& {
			if ($errorActionPreference -ne [System.Management.Automation.ActionPreference]::Stop) {
				$errorActionPreference = 'SilentlyContinue'
			}
			$newCredential = Microsoft.PowerShell.Security\Get-Credential -Credential $Credential
			if ($newCredential) {
				if (($credentialCache = Get-CredentialCache) -and $credentialCache.Enabled) {
					Set-CachedCredential -Credential $newCredential
				}
				if ($EntireRecord) {
					$credentialCacheRecord = New-Object System.Management.Automation.PSObject `
						| Add-Member -MemberType NoteProperty -Name UserName -Value $newCredential.UserName.TrimStart('\') -PassThru `
						| Add-Member -MemberType NoteProperty -Name Credential -Value $newCredential -PassThru `
						| Add-Member -MemberType NoteProperty -Name DateStored -Value $null -PassThru `
						| Add-Member -MemberType NoteProperty -Name LastAccessDate -Value $null -PassThru
					$credentialCacheRecord.PSObject.TypeNames[0] = 'CredentialCacheRecord'
					$credentialCacheRecord
				} else {
					$newCredential
				}
			}
		}
	}
}

# Syntax:
#     Set-CachedCredential [-Credential] <System.Management.Automation.PSObject> [[-AssociatedObjectId] <string[]>]
function global:Set-CachedCredential {
	param(
		$Credential = $(throw ((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'ParameterArgumentValidationErrorNullNotAllowed') -f $null,'Credential')),
		[string[]]$AssociatedObjectId = $null
	)
	Add-CachedCredential -Credential $Credential -AssociatedObjectId $AssociatedObjectId -Force
}

# Syntax:
#     Remove-CachedCredential [[-UserName] <string>]
function global:Remove-CachedCredential {
	param(
		[string]$UserName = $null
	)
	$credentialCache = Get-CredentialCache
	if ($keysToClear = $(if ($UserName) {$credentialCache.CredentialStore.Keys -like $UserName.TrimStart('\')} else {$credentialCache.CredentialStore.Keys})) {
		foreach ($item in $keysToClear) {
			$credentialCache.CredentialStore.Remove($item)
		}
	}
}

#endregion
#region CacheAssociation functions

# Syntax:
#     Add-CacheAssociation [-AssociatedObjectId] <string[]> [-UserName] <string> [-Force <Switch>]
function global:Add-CacheAssociation {
	param(
		[string[]]$AssociatedObjectId = $(throw ((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'ParameterArgumentValidationErrorNullNotAllowed') -f $null,'Credential')),
		[string]$UserName = $(throw ((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'ParameterArgumentValidationErrorNullNotAllowed') -f $null,'Credential')),
		[Switch]$Force
	)
	$credentialCache = Get-CredentialCache
	if (-not $credentialCache.Enabled) {
		Write-Warning 'Credential caching is not enabled.'
		return
	}
	$UserName = $UserName.TrimStart('\')
	if ($AssociatedObjectId.Count -and $UserName) {
		foreach ($item in $AssociatedObjectId) {
			if (($credentialCache.ObjectAssociations.Keys -notcontains $item) -or $Force) {
				$credentialCache.ObjectAssociations[$item] = $UserName
			} else {
				throw "Cannot set association for '$item' because it is already associated to '$($credentialCache.ObjectAssociations[$item])'. Use the -Force to overwrite the association for '$item'."
			}
		}
	}
}

# Syntax:
#     Get-CacheAssociation [-AssociatedObjectId] <string[]>
#     Get-CacheAssociation [-UserName] <string[]>
function global:Get-CacheAssociation {
	param(
		[string[]]$AssociatedObjectId = $null,
		[string[]]$UserName = $null
	)
	$credentialCache = Get-CredentialCache
	if ($AssociatedObjectId -and $UserName) {
		throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'AmbiguousParameterSet')
	} elseif ($AssociatedObjectId) {
		$keys = @()
		foreach ($item in $AssociatedObjectId) {
			$keys += ($credentialCache.ObjectAssociations.Keys -like $item)
		}
		foreach ($item in ($keys | Select-Object -Unique)) {
			$objectAssociationRecord = New-Object System.Management.Automation.PSObject
			$objectAssociationRecord.PSObject.TypeNames[0] = 'ObjectAssociationRecord'
			$objectAssociationRecord `
				| Add-Member -MemberType NoteProperty -Name AssociatedObjectId -Value $item -PassThru `
				| Add-Member -MemberType NoteProperty -Name UserName -Value $credentialCache.ObjectAssociations[$item] -PassThru
		}
	} elseif ($UserName) {
		$userNames = @()
		foreach ($item in $UserName) {
			$userNames += ($credentialCache.ObjectAssociations.Values -like $item)
		}
		foreach ($item in ($userNames | Select-Object -Unique)) {
			$credentialCache.ObjectAssociations.Keys | Where-Object {$credentialCache.ObjectAssociations[$_] -eq $item} | ForEach-Object {
				$objectAssociationRecord = New-Object System.Management.Automation.PSObject
				$objectAssociationRecord.PSObject.TypeNames[0] = 'ObjectAssociationRecord'
				$objectAssociationRecord `
					| Add-Member -MemberType NoteProperty -Name AssociatedObjectId -Value $_ -PassThru `
					| Add-Member -MemberType NoteProperty -Name UserName -Value $item -PassThru
			}
		}
	} else {
		$credentialCache.ObjectAssociations.Keys | ForEach-Object {
			$objectAssociationRecord = New-Object System.Management.Automation.PSObject
			$objectAssociationRecord.PSObject.TypeNames[0] = 'ObjectAssociationRecord'
			$objectAssociationRecord `
				| Add-Member -MemberType NoteProperty -Name AssociatedObjectId -Value $_ -PassThru `
				| Add-Member -MemberType NoteProperty -Name UserName -Value $credentialCache.ObjectAssociations[$_] -PassThru
		}
	}
}

# Syntax:
#     Set-CacheAssociation [-AssociatedObjectId] <string[]> [-UserName] <string>
function global:Set-CacheAssociation {
	param(
		[string[]]$AssociatedObjectId = $(throw ((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'ParameterArgumentValidationErrorNullNotAllowed') -f $null,'AssociatedObjectId')),
		[string]$UserName = $(throw ((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'ParameterArgumentValidationErrorNullNotAllowed') -f $null,'UserName'))
	)
	Add-CacheAssociation -AssociatedObjectId $AssociatedObjectId -UserName $UserName -Force
}

# Syntax:
#     Remove-CacheAssociation [[-AssociatedObjectId] <string>]
function global:Remove-CacheAssociation {
	param(
		[string]$AssociatedObjectId = $null
	)
	
	$credentialCache = Get-CredentialCache
	if ($keysToClear = $(if ($AssociatedObjectId) {$credentialCache.ObjectAssociations.Keys -like $AssociatedObjectId} else {$credentialCache.ObjectAssociations.Keys})) {
		foreach ($item in $keysToClear) {
			$credentialCache.ObjectAssociations.Remove($item)
		}
	}
}

#endregion
#region Cmdlet override functions

# Syntax:
#     Get-Credential [-credential] <PSCredential> [<CommonParameters>]
function global:Get-Credential {
	param(
		$Credential = $null,
		[Switch]$Verbose,
		[Switch]$Debug,
		[System.Management.Automation.ActionPreference]$ErrorAction = $errorActionPreference
	)
	$errorActionPreference = $ErrorAction
	if ($Debug) {$debugPreference = 'Continue'}
	if ($Verbose) {$verbosePreference = 'Continue'}
	if ($args.Count) {
		Write-Warning -Message 'The cached Get-Credential override does not support the OutVariable and ErrorVariable parameters yet.'
	}
	Get-CachedCredential -Credential $Credential
}

# Syntax:
#     Get-WmiObject [-class] <string> [[-property] <string[]>] [-namespace <string>] [-computerName <string[]>] [-filter <string>] [-credential <PSCredential>] [<CommonParameters>]
#     Get-WmiObject [-namespace <string>] [-computerName <string[]>] [-credential <PSCredential>] [-list] [<CommonParameters>]
#     Get-WmiObject -query <string> [-namespace <string>] [-computerName <string[]>] [-credential <PSCredential>] [<CommonParameters>]
function global:Get-WmiObject {
	$computerNameIndex = $null
	$credentialIndex = $null
	$namespaceIndex = $null
	$passThruArgs = @()
	$passThruArgIndex = 0;
	for ($index = 0; $index -lt $args.Count; $index++) {
		if ((-not $computerNameIndex) -and ($args[$index] -match '^-co') -and ('-ComputerName' -match "^$($args[$index])")) {
			if ($index -lt ($args.Count - 1)) {
				$computerNameIndex = $passThruArgIndex + 1
			}
		} elseif ((-not $credentialIndex) -and ($args[$index] -match '^-cr') -and ('-Credential' -match "^$($args[$index])")) {
			if ($index -lt ($args.Count - 1)) {
				if (($args[$index + 1] -eq $null) -or ($args[$index + 1] -eq [System.Management.Automation.PSCredential]::Empty)) {
					$index++
					continue
				}
				$credentialIndex = $passThruArgIndex + 1
			}
		} elseif ((-not $namespaceIndex) -and ($args[$index] -match '^-n') -and ('-Namespace' -match "^$($args[$index])")) {
			if ($index -lt ($args.Count - 1)) {
				$namespaceIndex = $passThruArgIndex + 1
			}
		}
		$passThruArgs += $args[$index]
		$passThruArgIndex++
	}
	$cancelled = $false
	$storeAssocation = $false
	if ((-not $namespaceIndex) -and ($PSWmiNamespace)) {
		$passThruArgs += '-Namespace'
		$passThruArgs += $PSWmiNamespace
		$namespaceIndex = $passThruArgs.Count - 2
	}
	if ((Get-CredentialCache).Enabled -and $computerNameIndex) {
		if ($credentialIndex) {
			$storeAssociation = $true
			if ($passThruArgs[$credentialIndex] -isnot [System.Management.Automation.PSCredential]) {
				if ($credential = Get-CachedCredential -Credential $passThruArgs[$credentialIndex]) {
					$passThruArgs[$credentialIndex] = $credential
				} else {
					$cancelled = $true
				}
			}
		} elseif ($credential = Get-CachedCredential -AssociatedObjectId $passThruArgs[$computerNameIndex]) {
			$passThruArgs += @('-Credential',$credential)
			$credentialIndex = $passThruArgs.Count - 1
		}
	}
	if (-not $cancelled) {
		$ifSuccessfulStoreCredentialAssociation = {
			if ($? -and $storeAssociation) {
				Set-CachedCredential -Credential $passThruArgs[$credentialIndex] -AssociatedObjectId $passThruArgs[$computerNameIndex]
			}
		}
		Microsoft.PowerShell.Utility\Invoke-Expression "Microsoft.PowerShell.Management\Get-WmiObject $(for ($i = 0; $i -lt $passThruArgs.Count; $i++) { if ($passThruArgs[$i] -match '^-') { $passThruArgs[$i] } else { `"`$passThruArgs[$i]`" } }); $ifSuccessfulStoreCredentialAssociation"
	}
}

#endregion

#endregion
#region ADSI Utility Functions

function global:Get-AdsiObject {
	param(
		[string]$AdsiPath = $null,
		$ComputerName = '.',
		$Credential = $null,
		[System.Management.Automation.PSObject]$AdsObject
	)

	$cancelled = $false

	if ($AdsiPath -and $AdsObject) {
		throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'AmbiguousParameterSet')
	} elseif (-not $AdsiPath -and -not $AdsObject) {
		throw $((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'ParameterArgumentValidationErrorNullNotAllowed') -f $null,'AdsiPath')
	}

	if ($AdsiPath) {
		if (-not $Credential) {
			if (Test-Path -Path function:Get-CachedCredential) {
				$Credential = Get-CachedCredential -AssociatedObjectId $ComputerName
			}
		} else {
			$Credential = Get-Credential $Credential
			if (-not $Credential) {
				$cancelled = $true
			}
		}

		if (-not $cancelled) {
			$userName = $password = $null
			if ($Credential) {
				$userName = $credential.UserName
				$password = $credential.Password | Get-Password -AsPlainText -Force
			}
			New-Object System.DirectoryServices.DirectoryEntry($AdsiPath,$userName,$password)
		}
	} else {
		New-Object System.DirectoryServices.DirectoryEntry($AdsObject)
	}
}

#endregion
#region WMI Utility Functions

function global:ConvertTo-WmiFilter {
	param(
		[string]$PropertyName = $(throw ((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'ParameterArgumentValidationErrorNullNotAllowed') -f $null,'PropertyName')),
		[string[]]$FilterValues,
		[string[]]$LiteralFilterValues
	)
	
	$wmiFilterSet = @()
	if ($FilterValues.Count) {
		foreach ($item in $FilterValues) {
			if ($item -match '[\*\?]') {
				$wmiFilterSet += "$PropertyName LIKE '$($item.Replace('*','%').Replace('?','_'))'"
			} else {
				$wmiFilterSet += "$PropertyName = '$item'"
			}
		}
	}
	if ($LiteralFilterValues.Count) {
		foreach ($item in $LiteralFilterValues) {
			$wmiFilterSet += "$PropertyName = '$item'"
		}
	}
	[string]::Join(' OR ',$wmiFilterSet)
}

# Syntax:
#     Use-WmiNamespace [-Namespace] <string>
#     Use-WmiNamespace [-Reset]
function global:Use-WmiNamespace {
	param(
		[string]$Namespace,
		[switch]$Reset
	)

	if ($Namespace -and $Reset) {
		throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'AmbiguousParameterSet')
	}
	if (($MyInvocation.InvocationName -eq '.') -and ($MyInvocation.MyCommand.CommandType -eq [System.Management.Automation.CommandTypes]::Function)) {
		$scope = 'Local'
	} else {
		$scope = 1
	}
	if ($Reset) {
		Set-Variable -Scope $scope -Name PSWmiNamespace -Value $null -Force | Out-Null
	} else {
		if (-not $Namespace) {
			Write-Host -ForegroundColor White -Object ((Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptCaption) -f 'Use-WmiNamespace',$MyInvocation.PipelinePosition)
			Write-Host (Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptMessage)
			$result = Read-Host -Prompt "Namespace"
			if ($result) {
				$Namespace = $Namespace
			} else {
				return
			}
		}
		Set-Variable -Scope $scope -Name PSWmiNamespace -Value $Namespace -Force | Out-Null
	}
}

function global:New-WmiObject {
	param(
		[string]$Namespace = $PSWmiNamespace,
		[string]$Class = $(throw ((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'ParameterArgumentValidationErrorNullNotAllowed') -f $null,'Class')),
		[string[]]$ComputerName = @(),
		[System.Management.Automation.PSObject]$Credential = $null
	)

	if (-not $ComputerName) {
		$ComputerName = @('.')
	}
	$wmiClass = Get-WmiClass -Namespace $Namespace -Class $Class -ComputerName $ComputerName -Credential $Credential
	$instance = $wmiClass.PSBase.CreateInstance()
	$attempt = 1
	while (($instance.PSBase.Properties.Count -lt $instance.__PROPERTYCOUNT) -and ($attempt -le 5)) {
		$attempt++
		Start-Sleep -Milliseconds 200
	}
	$instance
}

function global:Refresh-WmiObject {
	param(
		[System.Management.ManagementObject]$WmiObject = $(throw ((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'ParameterArgumentValidationErrorNullNotAllowed') -f $null,'WmiObject')),
		[System.Management.Automation.PSObject]$Credential = $null
	)

	if ($Credential) {
		Get-WmiObject -Namespace $WmiObject.__NAMESPACE -Class $WmiObject.__CLASS -Filter "__RELPATH='$($WmiObject.__RELPATH.Replace('\','\\'))'" -ComputerName $WmiObject.__SERVER -Credential $Credential
	} else {
		Get-WmiObject -Namespace $WmiObject.__NAMESPACE -Class $WmiObject.__CLASS -Filter "__RELPATH='$($WmiObject.__RELPATH.Replace('\','\\'))'" -ComputerName $WmiObject.__SERVER
	}
}

function global:Get-WmiObjectFromManagementPath {
	param(
		[System.Management.Automation.PSObject]$ManagementPath,
		[System.Management.Automation.PSObject]$Credential = $null
	)

	if ($ManagementPath -isnot [System.Management.ManagementPath]) {
		$ManagementPath = [System.Management.ManagementPath]$ManagementPath
	}

	if ($Credential) {
		Get-WmiObject -Namespace $ManagementPath.NamespacePath -Class $ManagementPath.ClassName -Filter "__RELPATH='$($ManagementPath.RelativePath.Replace('\','\\'))'" -ComputerName $ManagementPath.Server -Credential $Credential
	} else {
		Get-WmiObject -Namespace $ManagementPath.NamespacePath -Class $ManagementPath.ClassName -Filter "__RELPATH='$($ManagementPath.RelativePath.Replace('\','\\'))'" -ComputerName $ManagementPath.Server
	}
}

function global:Get-WmiClass {
	param(
		[string]$Namespace = $null,
		[string]$Class = $(throw ((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'ParameterArgumentValidationErrorNullNotAllowed') -f $null,'Class')),
		[string[]]$ComputerName = @(),
		[Switch]$IncludeDerivedClasses,
		[System.Management.Automation.PSObject]$Credential = $null
	)

	if (-not $ComputerName) {
		$ComputerName = @('.')
	}
	$filter = "__this isa '$Class'"
	if (-not $IncludeDerivedClasses) {
		$filter += " AND __CLASS='$Class'"
	}
	$defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet',[string[]]@('Name','Type','PropertyCount','Server','Namespace','Path'))
	$PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
	$processScript = {
		if ($host.Name -eq 'PowerGUIHost') {
			$_.PSObject.TypeNames.Remove($_.PSObject.TypeNames[0]) | Out-Null
			if (($_.__NAMESPACE -eq $root) -and ($_.__CLASS -eq '__NAMESPACE')) {
				$_.PSObject.TypeNames.Insert(0,"$($_.PSObject.TypeNames[0])#Root")
			} elseif ($_.__GENUS -eq 2) {
				$_.PSObject.TypeNames.Insert(0,"$($_.PSObject.TypeNames[0])#Namespace")
			} elseif ($_.__GENUS -eq 1) {
				$_.PSObject.TypeNames.Insert(0,"$($_.PSObject.TypeNames[0])#Class")
			}
		}
		for ($i=0; $i -lt $_.PSObject.TypeNames.Count; $i++) {
			$_.PSObject.TypeNames[$i] += '#MemberOverrideExtension'
		}
		$_ | Add-Member -Force -Name Name -MemberType ScriptProperty -Value {if ($this.__CLASS -eq '__NAMESPACE') {$this.__NAMESPACE} else {$this.__CLASS}}
		for ($i=0; $i -lt $_.PSObject.TypeNames.Count; $i++) {
			$_.PSObject.TypeNames[$i] = $_.PSObject.TypeNames[$i] -replace '#MemberOverrideExtension$',''
		}
		$_ `
			| Add-Member -Force -Name Type -MemberType ScriptProperty -Value {if ($this.__GENUS -eq 1) {'Class'} elseif ($this.__GENUS -eq 2 ) {'Namespace'}} -PassThru `
			| Add-Member -Force -Name PropertyCount -MemberType AliasProperty -Value __PROPERTY_COUNT -PassThru `
			| Add-Member -Force -Name Server -MemberType AliasProperty -Value __SERVER -PassThru `
			| Add-Member -Force -Name Namespace -MemberType AliasProperty -Value __NAMESPACE -PassThru `
			| Add-Member -Force -Name Path -MemberType AliasProperty -Value __PATH -PassThru `
			| Add-Member -Force -Name PSStandardMembers -MemberType MemberSet -Value $PSStandardMembers -PassThru
	}
	if ($Credential) {
		Get-WmiObject -Namespace $Namespace -Class meta_class -Filter $filter -ComputerName $ComputerName -Credential $Credential | ForEach-Object $processScript
	} else {
		Get-WmiObject -Namespace $Namespace -Class meta_class -Filter $filter -ComputerName $ComputerName | ForEach-Object $processScript
	}
}

function global:Get-WmiRoot {
	param(
		[string[]]$ComputerName = @(),
		[System.Management.Automation.PSObject]$Credential = $null
	)

	$wmiRoot = Get-WmiClass -Namespace root -Class __NAMESPACE -ComputerName $ComputerName -Credential $Credential
	if (($wmiRoot.PSObject.TypeNames -notcontains 'System.Management.ManagementObject#__NAMESPACE') -and ($wmiRoot.PSObject.TypeNames.Count -gt 1)) {
		$wmiRoot.PSObject.TypeNames.Insert(1,'System.Management.ManagementObject#__NAMESPACE')
	}
	$wmiRoot
}

#endregion
#region Local User and Group Functions

#region LocalUser functions

function global:New-LocalUser {
	param(
		[string[]]$Name = @(),
		[System.Security.SecureString]$Password,
		[string]$FullName = $null,
		[string]$Description = $null,
		[switch]$UserMustChangePasswordAtNextLogon,
		[switch]$UserCannotChangePassword,
		[switch]$PasswordNeverExpires,
		[switch]$AccountIsDisabled,
		[string[]]$ComputerName = @(),
		[System.Management.Automation.PSObject]$Credential = $null
	)

	if ($args.Count) {
		throw $((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'NamedParameterNotFound') -f $null,$args[0])
	}

	if ($UserMustChangePasswordAtNextLogon -and ($UserCannotChangePassword -or $PasswordNeverExpires)) {
		throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'AmbiguousParameterSet')
	}

	$executeLogonScriptFlag = 0x00000001
	$accountDisabledFlag = 0x00000002
	$homeDirectoryRequiredFlag = 0x00000008
	$accountLockedOutFlag = 0x00000010
	$passwordNotRequiredFlag = 0x00000020
	$passwordCannotChangeFlag = 0x00000040
	$encryptedPasswordAllowedFlag = 0x00000080
	$passwordNeverExpiresFlag = 0x00010000
	$smartcardRequiredFlag = 0x00040000
	$passwordExpiredFlag = 0x00800000

	$userFlags = 0
	if ($UserCannotChangePassword) {
		$userFlags = $userFlags -bor $passwordCannotChangeFlag
	}
	if ($PasswordNeverExpires) {
		$userFlags = $userFlags -bor $passwordNeverExpiresFlag
	}
	if ($AccountIsDisabled) {
		$userFlags = $userFlags -bor $accountDisabledFlag
	}

	$promptedForRequiredParameters = $false
	if ((-not $Name) -or (-not $Password)) {
		if (-not $promptedForRequiredParameters) {
			$promptedForRequiredParameters = $true
			Write-Host -ForegroundColor White -Object ((Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptCaption) -f 'New-LocalUser',$MyInvocation.PipelinePosition)
			Write-Host (Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptMessage)
			if (-not $Name) {
				$index = 0
				$Name = @()
				while ($result = Read-Host -Prompt "Name[$index]") {
					$index++
					$Name += $result
				}
				if (-not $Name) {
					return
				}
			}
			if (-not $Password) {
				if ($result = Read-Host -AsSecureString -Prompt 'Password') {
					$Password = $result
				} else {
					return
				}
			}
		} else {
			return
		}
	}

	if (-not $ComputerName) {
		$ComputerName = @('.')
	}
	$cancelled = $false
	if ($Credential) {
		$Credential = Get-Credential -Credential $Credential
		$cancelled = (-not $Credential)
	}

	if ($cancelled) {
		return
	}

	foreach ($item in $ComputerName) {
		if ($item -eq $env:COMPUTERNAME) {
			$item = '.'
		}
		$computer = Get-AdsiObject -AdsiPath "WinNT://$item" -ComputerName $item -Credential $Credential
		foreach ($userName in $Name) {
			$user = $computer.Create('user',$userName)
			if ($?) {
				$user.SetPassword(($Password | Get-Password -AsPlainText -Force))
				$user.SetInfo()
			}
			if ($? -and $FullName) {
				$user.Put('FullName',$FullName)
				$user.SetInfo()
			}
			if ($? -and $Description) {
				$user.Put('Description',$Description)
				$user.SetInfo()
			}
			if ($? -and $UserMustChangePasswordAtNextLogon) {
				$user.Put('PasswordExpired',1)
				$user.SetInfo()
			}
			if ($? -and $userFlags) {
				$user.Put('UserFlags',$userFlags)
				$user.SetInfo()
			}

			Get-LocalUser -Name $userName -ComputerName $item -Credential $Credential
		}
	}
}

function global:Get-LocalUser {
	param(
		[string[]]$Name = $null,
		[string[]]$ComputerName = @(),
		[System.Management.Automation.PSObject]$Credential = $null
	)

	if ($args.Count) {
		throw $((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'NamedParameterNotFound') -f $null,$args[0])
	}

	$defaultProperties = @('Name','Description','ComputerName','SID')
	$defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet',[string[]]$defaultProperties)
	$PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)

	if (-not $ComputerName) {
		$ComputerName = @('.')
	}
	$cancelled = $false
	if ($Credential) {
		$Credential = Get-Credential -Credential $Credential
		$cancelled = (-not $Credential)
	}
	if ($cancelled) {
		return
	}

	foreach ($item in $ComputerName) {
		if ($item -eq $env:COMPUTERNAME) {
			$item = '.'
		}

		$computerSystem = $(if ($Credential) {Get-WmiObject -Namespace root\cimv2 -Class Win32_ComputerSystem -ComputerName $item -Credential $Credential} else {Get-WmiObject -Namespace root\cimv2 -Class Win32_ComputerSystem -ComputerName $item})
		if ($computerSystem.Name -eq $env:COMPUTERNAME) {
			$item = '.'
		}

		$filter = "Domain='$($computerSystem.Name)'"
		if ($Name.Count) {
			$filter += "AND ($(ConvertTo-WmiFilter -PropertyName Name -FilterValues $Name))"
		}

		$toStringMethod = {
			$this.Name
		}

		$renameMethod = {
			if ($args.Count -and $args[0] -is [string]) {
				[string]$newName = $args[0]
				$newName = $newName.Trim()
				if ($newName.Length -gt 20) {
					Write-Warning '[LocalUser]::Rename: The new user name exceeds 20 characters in length and has been truncated.'
					$newName = $newName.SubString(0,20).Trim()
				}
				$arguments = @($newName)
				$result = $this.WmiUserAccount.PSBase.InvokeMethod('Rename',$arguments)
				if ($result -eq 0) {
					$this.WmiUserAccount.Name = $newName
					$this.WmiUserAccount.Caption = "$($this.WmiUserAccount.Domain)\$($this.WmiUserAccount.Name)"
					$computerName = $this.WmiUserAccount.__SERVER
					if ($computerName -eq $env:COMPUTERNAME) {
						$computerName = '.'
					}
					$this.ADSIUser = Get-AdsiObject -AdsiPath "WinNT://$computerName/$newName,User" -ComputerName $computerName -Credential $this.Credential
				}
			}
		}

		$unlockMethod = {
			$this.WmiUserAccount.Lockout = $false
			$this.WmiUserAccount.PSBase.Put() | Out-Null
		}

		$getGroupsMethod = {
			$this.ADSIUser.PSBase.Invoke('Groups') | ForEach-Object {
				$name = $_.GetType().InvokeMember('Name','GetProperty',$null,$_,$null)
				Get-LocalGroup -Name $Name -ComputerName $this.ComputerName -Credential $this.Credential
			}
		}

		$isMemberOfGroupMethod = {
			if ($args.Count -and $args[0] -is [string]) {
				$groupName = $args[0]
				$computerName = $this.ComputerName
				if ($computerName -eq $env:COMPUTERNAME) {
					$computerName = '.'
				}
				$group = Get-AdsiObject -AdsiPath "WinNT://$computerName/$groupName,group" -ComputerName $computerName -Credential $this.Credential
				$group.IsMember(($this.ADSIUser.PSBase.Path.Replace('WinNT://./',"WinNT://$($this.ComputerName)/") -replace ',User$',''))
			}
		}

		$addToGroupMethod = {
			if ($args.Count -and $args[0] -is [string]) {
				$groupName = $args[0]
				$computerName = $this.ComputerName
				if ($computerName -eq $env:COMPUTERNAME) {
					$computerName = '.'
				}
				$group = Get-AdsiObject -AdsiPath "WinNT://$computerName/$groupName,group" -ComputerName $computerName -Credential $this.Credential
				$group.Add(($this.ADSIUser.PSBase.Path.Replace('WinNT://./',"WinNT://$($this.ComputerName)/") -replace ',User$',''))
			}
		}

		$removeFromGroupMethod = {
			if ($args.Count -and $args[0] -is [string]) {
				$groupName = $args[0]
				$computerName = $this.ComputerName
				if ($computerName -eq $env:COMPUTERNAME) {
					$computerName = '.'
				}
				$group = Get-AdsiObject -AdsiPath "WinNT://$computerName/$groupName,group" -ComputerName $computerName -Credential $this.Credential
				$group.Remove(($this.ADSIUser.PSBase.Path.Replace('WinNT://./',"WinNT://$($this.ComputerName)/") -replace ',User$',''))
			}
		}

		$setPasswordMethod = {
			if ($args.Count -and ($password = $args[0])) {
				if ($password -is [System.Security.SecureString]) {
					$password = $password | Get-Password -AsPlainText -Force
				}
				if ($password -is [string]) {
					$this.ADSIUser.SetPassword($password)
				}
			}
		}

		$forcePasswordChangeMethod = {
			$this.UserMustChangePasswordAtNextLogon = $true
		}

		$expireAccountMethod = {
			$this.AccountExpirationDate = Get-Date
		}

		$enableMethod = {
			$this.ADSIUser.PSBase.InvokeSet('AccountDisabled',$false)
			$this.ADSIUser.SetInfo()
			if ($?) {
				$this.WmiUserAccount.Disabled = $false
			}
		}

		$disableMethod = {
			$this.ADSIUser.PSBase.InvokeSet('AccountDisabled',$true)
			$this.ADSIUser.SetInfo()
			if ($?) {
				$this.WmiUserAccount.Disabled = $true
			}
		}

		$(if ($Credential) {Get-WmiObject -Namespace root\cimv2 -Class Win32_UserAccount -Filter $filter -ComputerName $item -Credential $Credential} else {Get-WmiObject -Namespace root\cimv2 -Class Win32_UserAccount -Filter $filter -ComputerName $item}) `
			| Select-Object -Property @{Name='WmiUserAccount';Expression={$_}},@{Name='Credential';Expression={if ($Credential) {$Credential} else {$null}}} `
			| Add-Member -MemberType MemberSet -Name PSStandardMembers -Value $PSStandardMembers -PassThru `
			| Add-Member -MemberType ScriptMethod -Name ToString -Value $toStringMethod -Force -PassThru `
			| Add-Member -MemberType ScriptMethod -Name Rename -Value $renameMethod -PassThru `
			| Add-Member -MemberType ScriptMethod -Name Unlock -Value $unlockMethod -PassThru `
			| Add-Member -MemberType ScriptProperty -Name ComputerName -Value {$this.WmiUserAccount.__SERVER} -PassThru `
			| Add-Member -MemberType ScriptProperty -Name Name -Value {$this.WmiUserAccount.Name} -PassThru `
			| Add-Member -MemberType ScriptProperty -Name FullyQualifiedName -Value {$this.WmiUserAccount.Caption} -PassThru `
			| Add-Member -MemberType ScriptProperty -Name SID -Value {$this.WmiUserAccount.SID} -PassThru `
			| Add-Member -MemberType ScriptProperty -Name InstallDate -Value {$this.WmiUserAccount.InstallDate} -PassThru `
			| Add-Member -MemberType ScriptProperty -Name Disabled -Value {$this.WmiUserAccount.Disabled} -PassThru `
			| Add-Member -MemberType ScriptProperty -Name PasswordRequired -Value {$this.WmiUserAccount.PasswordRequired} -PassThru `
			| Add-Member -MemberType ScriptProperty -Name FullName -Value {$this.WmiUserAccount.FullName} -SecondValue {if ($args.Count -and $args[0] -is [string]) {$fullName = $args[0]; $this.WmiUserAccount.FullName = $fullName; $this.WmiUserAccount.PSBase.Put() | Out-Null}} -PassThru `
			| Add-Member -MemberType ScriptProperty -Name LockedOut -Value {$this.WmiUserAccount.Lockout} -PassThru `
			| Add-Member -MemberType ScriptProperty -Name PasswordNeverExpires -Value {-not $this.WmiUserAccount.PasswordExpires} -SecondValue {if ($args.Count -and $args[0] -is [bool]) {$passwordNeverExpires = $args[0]; $this.WmiUserAccount.PasswordExpires = -not $passwordNeverExpires; $this.WmiUserAccount.PSBase.Put() | Out-Null}} -PassThru `
			| Add-Member -MemberType ScriptProperty -Name UserCannotChangePassword -Value {-not $this.WmiUserAccount.PasswordChangeable} -SecondValue {if ($args.Count -and $args[0] -is [bool]) {$userCannotChangePassword = $args[0]; $this.WmiUserAccount.PasswordChangeable = -not $userCannotChangePassword; $this.WmiUserAccount.PSBase.Put() | Out-Null}} -PassThru `
			| ForEach-Object {
				$_ `
					| Add-Member -MemberType NoteProperty -Name ADSIUser -Value (Get-AdsiObject -AdsiPath "WinNT://$item/$($_.Name),User" -ComputerName $item -Credential $Credential) -PassThru `
					| Add-Member -MemberType ScriptMethod -Name GetGroups -Value $getGroupsMethod -PassThru `
					| Add-Member -MemberType ScriptMethod -Name IsMemberOfGroup -Value $isMemberOfGroupMethod -PassThru `
					| Add-Member -MemberType ScriptMethod -Name AddToGroup -Value $addToGroupMethod -PassThru `
					| Add-Member -MemberType ScriptMethod -Name RemoveFromGroup -Value $removeFromGroupMethod -PassThru `
					| Add-Member -MemberType ScriptMethod -Name SetPassword -Value $setPasswordMethod -PassThru `
					| Add-Member -MemberType ScriptMethod -Name ForcePasswordChange -Value $forcePasswordChangeMethod -PassThru `
					| Add-Member -MemberType ScriptMethod -Name ExpireAccount -Value $expireAccountMethod -PassThru `
					| Add-Member -MemberType ScriptMethod -Name Enable -Value $enableMethod -PassThru `
					| Add-Member -MemberType ScriptMethod -Name Disable -Value $disableMethod -PassThru `
					| Add-Member -MemberType ScriptProperty -Name Description -Value {$this.ADSIUser.Description.Value} -SecondValue {if ($args.Count -and $args[0] -is [string]) {$description = [string]$args[0]; $this.ADSIUser.PSBase.InvokeSet('Description',$description); $this.ADSIUser.PSBase.CommitChanges()}} -PassThru `
					| Add-Member -MemberType ScriptProperty -Name LastLogonDate -Value {trap {continue}; $this.ADSIUser.PSBase.InvokeGet('LastLogin')} -PassThru `
					| Add-Member -MemberType ScriptProperty -Name AccountExpirationDate -Value {trap {continue}; $this.ADSIUser.PSBase.InvokeGet('AccountExpirationDate')} -SecondValue {if ($accountExpirationDate = [datetime]$args[0]) {$this.ADSIUser.PSBase.InvokeSet('AccountExpirationDate',$accountExpirationDate); $this.ADSIUser.PSBase.CommitChanges()}} -PassThru `
					| Add-Member -MemberType ScriptProperty -Name PasswordAge -Value {[int]("{0:N0}" -f ($this.ADSIUser.PasswordAge.Value / 86400))} -PassThru `
					| Add-Member -MemberType ScriptProperty -Name MaxPasswordAge -Value {[int]("{0:N0}" -f ($this.ADSIUser.MaxPasswordAge.Value / 86400))} -PassThru `
					| Add-Member -MemberType ScriptProperty -Name MinPasswordAge -Value {[int]("{0:N0}" -f ($this.ADSIUser.MinPasswordAge.Value / 86400))} -PassThru `
					| Add-Member -MemberType ScriptProperty -Name PasswordHistoryLength -Value {$this.ADSIUser.PasswordHistoryLength.Value} -PassThru `
					| Add-Member -MemberType ScriptProperty -Name MinPasswordLength -Value {$this.ADSIUser.MinPasswordLength.Value} -PassThru `
					| Add-Member -MemberType ScriptProperty -Name UserMustChangePasswordAtNextLogon -Value {$this.ADSIUser.PasswordExpired.Value -ne 0} -SecondValue {if ($args.Count -and $args[0] -is [bool]) {$userMustChangePasswordAtNextLogon = $args[0]; $this.ADSIUser.Put('PasswordExpired', [int]$userMustChangePasswordAtNextLogon); $this.ADSIUser.SetInfo()}} -PassThru `
					| Add-Member -MemberType ScriptProperty -Name LogonScriptExecuted -Value {[bool]($this.ADSIUser.UserFlags.Value -band 0x1)} -PassThru `
					| Add-Member -MemberType ScriptProperty -Name HomeDirectoryRequired -Value {[bool]($this.ADSIUser.UserFlags.Value -band 0x8)} -PassThru `
					| Add-Member -MemberType ScriptProperty -Name EncryptedTextPasswordAllowed -Value {[bool]($this.ADSIUser.UserFlags.Value -band 0x80)} -PassThru `
					| Add-Member -MemberType ScriptProperty -Name SmartCardRequired -Value {[bool]($this.ADSIUser.UserFlags.Value -band 0x40000)} -PassThru `
					| Add-Member -MemberType ScriptProperty -Name LockoutObservationInterval -Value {$this.ADSIUser.LockoutObservationInterval.Value / 60} -PassThru `
					| Add-Member -MemberType ScriptProperty -Name LockoutMaxFailedAttempts -Value {$this.ADSIUser.MaxBadPasswordsAllowed.Value} -PassThru `
					| Add-Member -MemberType ScriptProperty -Name LockoutAutoUnlockInterval -Value {$this.ADSIUser.AutoUnlockInterval.Value / 60}
				$_.PSObject.TypeNames[0] = 'LocalUser'
				$_
			}
	}
}

function global:Enable-LocalUser {
	param(
		[string[]]$Name = $null,
		[string[]]$ComputerName = @(),
		[System.Management.Automation.PSObject]$Credential = $null
	)

	begin{
		if ($args.Count) {
			throw $((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'NamedParameterNotFound') -f $null,$args[0])
		}
		$promptedForRequiredParameters = $false
		$cancelled = $false
	}

	process {
		if ($Name -and $_) {
			throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
		} elseif ($_) {
			if ($_.PSObject.TypeNames -contains 'LocalUser') {
				if ($_.Disabled) {
					$_.Enable()
				}
				$_
			} else {
				$processName = $null
				$processComputerName = $ComputerName
				$processCredential = $Credential
				if ($_ -is [string]) {
					$processName = $_
				} else {
					if ($_.Name) {
						$processName = $_.Name
					}
					if ((-not $processComputerName) -and ($_.ComputerName)) {
						$processComputerName = $_.ComputerName
					}
					if ((-not $processCredential) -and ($_.Credential)) {
						$processCredential = $_.Credential
					}
				}
				if (-not $processName) {
					throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
				}
				Get-LocalUser -Name $processName -ComputerName $processComputerName -Credential $processCredential | Enable-LocalUser
			}
		} else {
			if (-not $Name) {
				if (-not $promptedForRequiredParameters) {
					$promptedForRequiredParameters = $true
					Write-Host -ForegroundColor White -Object ((Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptCaption) -f 'Enable-LocalUser',$MyInvocation.PipelinePosition)
					Write-Host (Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptMessage)
					$index = 0
					$Name = @()
					while ($result = Read-Host -Prompt "Name[$index]") {
						$index++
						$Name += $result
					}
					if (-not $Name) {
						return
					}
				} else {
					return
				}
			}
			Get-LocalUser -Name $Name -ComputerName $ComputerName -Credential $Credential | Enable-LocalUser
		}
	}
}

function global:Disable-LocalUser {
	param(
		[string[]]$Name = $null,
		[string[]]$ComputerName = @(),
		[System.Management.Automation.PSObject]$Credential = $null
	)

	begin{
		if ($args.Count) {
			throw $((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'NamedParameterNotFound') -f $null,$args[0])
		}
		$promptedForRequiredParameters = $false
	}

	process {
		if ($Name -and $_) {
			throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
		} elseif ($_) {
			if ($_.PSObject.TypeNames -contains 'LocalUser') {
				if (-not $_.Disabled) {
					$_.Disable()
				}
				$_
			} else {
				$processName = $null
				$processComputerName = $ComputerName
				$processCredential = $Credential
				if ($_ -is [string]) {
					$processName = $_
				} else {
					if ($_.Name) {
						$processName = $_.Name
					}
					if ((-not $processComputerName) -and ($_.ComputerName)) {
						$processComputerName = $_.ComputerName
					}
					if ((-not $processCredential) -and ($_.Credential)) {
						$processCredential = $_.Credential
					}
				}
				if (-not $processName) {
					throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
				}
				Get-LocalUser -Name $processName -ComputerName $processComputerName -Credential $processCredential | Disable-LocalUser
			}
		} else {
			if (-not $Name) {
				if (-not $promptedForRequiredParameters) {
					$promptedForRequiredParameters = $true
					Write-Host -ForegroundColor White -Object ((Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptCaption) -f 'Disable-LocalUser',$MyInvocation.PipelinePosition)
					Write-Host (Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptMessage)
					$index = 0
					$Name = @()
					while ($result = Read-Host -Prompt "Name[$index]") {
						$index++
						$Name += $result
					}
					if (-not $Name) {
						return
					}
				} else {
					return
				}
			}
			Get-LocalUser -Name $Name -ComputerName $ComputerName -Credential $Credential | Disable-LocalUser
		}
	}
}

function global:Unlock-LocalUser {
	param(
		[string[]]$Name = $null,
		[string[]]$ComputerName = @(),
		[System.Management.Automation.PSObject]$Credential = $null
	)

	begin{
		if ($args.Count) {
			throw $((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'NamedParameterNotFound') -f $null,$args[0])
		}
		$promptedForRequiredParameters = $false
	}

	process {
		if ($Name -and $_) {
			throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
		} elseif ($_) {
			if ($_.PSObject.TypeNames -contains 'LocalUser') {
				if ($_.LockedOut) {
					$_.Unlock()
				}
				$_
			} else {
				$processName = $null
				$processComputerName = $ComputerName
				$processCredential = $Credential
				if ($_ -is [string]) {
					$processName = $_
				} else {
					if ($_.Name) {
						$processName = $_.Name
					}
					if ((-not $processComputerName) -and ($_.ComputerName)) {
						$processComputerName = $_.ComputerName
					}
					if ((-not $processCredential) -and ($_.Credential)) {
						$processCredential = $_.Credential
					}
				}
				if (-not $processName) {
					throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
				}
				Get-LocalUser -Name $processName -ComputerName $processComputerName -Credential $processCredential | ForEach-Object {
					if ($_.LockedOut) {
						$_.Unlock()
					}
					$_
				}
			}
		} else {
			if (-not $Name) {
				if (-not $promptedForRequiredParameters) {
					$promptedForRequiredParameters = $true
					Write-Host -ForegroundColor White -Object ((Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptCaption) -f 'Unlock-LocalUser',$MyInvocation.PipelinePosition)
					Write-Host (Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptMessage)
					$index = 0
					$Name = @()
					while ($result = Read-Host -Prompt "Name[$index]") {
						$index++
						$Name += $result
					}
					if (-not $Name) {
						return
					}
				} else {
					return
				}
			}
			Get-LocalUser -Name $Name -ComputerName $ComputerName -Credential $Credential | Unlock-LocalUser
		}
	}
}

function global:Rename-LocalUser {
	param(
		[string]$Name = $null,
		[string]$NewName = $null,
		[string[]]$ComputerName = @(),
		[System.Management.Automation.PSObject]$Credential = $null
	)

	begin{
		if ($args.Count) {
			throw $((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'NamedParameterNotFound') -f $null,$args[0])
		}
		$promptedForRequiredParameters = $false
	}

	process {
		if ($Name -and $_) {
			throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
		} elseif ($_) {
			if (-not $NewName) {
				if (-not $promptedForRequiredParameters) {
					$promptedForRequiredParameters = $true
					Write-Host -ForegroundColor White -Object ((Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptCaption) -f 'Rename-LocalUser',$MyInvocation.PipelinePosition)
					Write-Host (Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptMessage)
					if (-not $NewName) {
						$result = Read-Host -Prompt "NewName"
						if ($result) {
							$NewName
						} else {
							return
						}
					}
				} else {
					return
				}
			}
			if ($_.PSObject.TypeNames -contains 'LocalUser') {
				$_.Rename($NewName)
				$_
			} else {
				$processName = $null
				$processComputerName = $ComputerName
				$processCredential = $Credential
				if ($_ -is [string]) {
					$processName = $_
				} else {
					if ($_.Name) {
						$processName = $_.Name
					}
					if ((-not $processComputerName) -and ($_.ComputerName)) {
						$processComputerName = $_.ComputerName
					}
					if ((-not $processCredential) -and ($_.Credential)) {
						$processCredential = $_.Credential
					}
				}
				if (-not $processName) {
					throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
				}
				Get-LocalUser -Name $processName -ComputerName $processComputerName -Credential $processCredential | Rename-LocalUser -NewName $NewName
			}
		} else {
			if ((-not $Name) -or (-not $NewName)) {
				if (-not $promptedForRequiredParameters) {
					$promptedForRequiredParameters = $true
					Write-Host -ForegroundColor White -Object ((Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptCaption) -f 'Rename-LocalUser',$MyInvocation.PipelinePosition)
					Write-Host (Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptMessage)
					if (-not $Name) {
						$result = Read-Host -Prompt "Name"
						if ($result) {
							$Name = $result
						} else {
							return
						}
					}
					if (-not $NewName) {
						$result = Read-Host -Prompt "NewName"
						if ($result) {
							$NewName
						} else {
							return
						}
					}
				} else {
					return
				}
			}
			Get-LocalUser -Name $Name -ComputerName $ComputerName -Credential $Credential | Rename-LocalUser -NewName $NewName
		}
	}
}

function global:Set-LocalUser {
	param(
		[string[]]$Name = $null,
		[System.Security.SecureString]$Password,
		[switch]$Enable,
		[switch]$Disable,
		[switch]$Unlock,
		[string]$FullName = $null,
		[string]$Description = $null,
		[System.Management.Automation.PSObject]$PasswordNeverExpires = $null,
		[System.Management.Automation.PSObject]$UserCanChangePassword = $null,
		[System.Management.Automation.PSObject]$UserMustChangePasswordAtNextLogon = $null,
		[System.Management.Automation.PSObject]$AccountExpirationDate = $null,
		[switch]$Force,
		[string[]]$ComputerName = @(),
		[System.Management.Automation.PSObject]$Credential = $null
	)

	begin{
		if ($args.Count) {
			throw $((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'NamedParameterNotFound') -f $null,$args[0])
		}
		$promptedForRequiredParameters = $false
		if ($UserMustChangePasswordAtNextLogon -and ($UserCannotChangePassword -or $PasswordNeverExpires)) {
			throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'AmbiguousParameterSet')
		}
		if (($PasswordNeverExpires -ne $null) -and ($PasswordNeverExpires -isnot [bool])) {
			[double]$number = 0
			if (-not [double]::TryParse($PasswordNeverExpires, [REF]$number)) {
				throw $((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'CannotConvertArgumentNoMessage') -f $null,'PasswordNeverExpires',$null,$null,$null,$null,((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'CannotConvertArgument') -f $null,'PasswordNeverExpires','System.Boolean',$null,$null,$null,$PasswordNeverExpires.ToString(),$null))
			}
			$PasswordNeverExpires = [bool]$number
		}
		if (($UserCannotChangePassword -ne $null) -and ($UserCannotChangePassword -isnot [bool]))  {
			[double]$number = 0
			if (-not [double]::TryParse($UserCannotChangePassword, [REF]$number)) {
				throw $((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'CannotConvertArgumentNoMessage') -f $null,'UserCannotChangePassword',$null,$null,$null,$null,((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'CannotConvertArgument') -f $null,'UserCannotChangePassword','System.Boolean',$null,$null,$null,$UserCannotChangePassword.ToString(),$null))
			}
			$UserCannotChangePassword = [bool]$number
		}
		if (($UserMustChangePasswordAtNextLogon -ne $null) -and ($UserMustChangePasswordAtNextLogon -isnot [bool]))  {
			[double]$number = 0
			if (-not [double]::TryParse($UserMustChangePasswordAtNextLogon, [REF]$number)) {
				throw $((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'CannotConvertArgumentNoMessage') -f $null,'UserMustChangePasswordAtNextLogon',$null,$null,$null,$null,((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'CannotConvertArgument') -f $null,'UserMustChangePasswordAtNextLogon','System.Boolean',$null,$null,$null,$UserMustChangePasswordAtNextLogon.ToString(),$null))
			}
			$UserMustChangePasswordAtNextLogon = [bool]$number
		}
		if ($AccountExpirationDate -ne $null) {
			$AccountExpirationDate = [System.DateTime]$AccountExpirationDate
		}
	}

	process {
		if ($Name -and $_) {
			throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
		} elseif ($_) {
			if ($_.PSObject.TypeNames -contains 'LocalUser') {
				if ($Password) {
					$_.SetPassword($Password)
				}
				if ($Enable -and $_.Disabled) {
					$_.Enable()
				}
				if ($Disable -and -not $_.Disabled) {
					$_.Disable()
				}
				if ($Unlock -and $_.LockedOut) {
					$_.Unlock()
				}
				if ($FullName -and ($_.FullName -cne $FullName)) {
					$_.FullName = $FullName
				}
				if ($Description -and ($_.Description -cne $Description)) {
					$_.Description = $Description
				}
				if (($PasswordNeverExpires -ne $null) -and ($_.PasswordNeverExpires -ne $PasswordNeverExpires)) {
					$_.PasswordNeverExpires = $PasswordNeverExpires
				}
				if (($UserCannotChangePassword -ne $null) -and ($_.UserCannotChangePassword -ne $UserCannotChangePassword)) {
					$_.UserCannotChangePassword = $UserCannotChangePassword
				}
				if (($UserMustChangePasswordAtNextLogon -ne $null) -and ($_.UserMustChangePasswordAtNextLogon -ne $UserMustChangePasswordAtNextLogon)) {
					$_.UserMustChangePasswordAtNextLogon = $UserMustChangePasswordAtNextLogon
				}
				if (($AccountExpirationDate) -and ($_.AccountExpirationDate -ne $AccountExpirationDate)) {
					$_.AccountExpirationDate = $AccountExpirationDate
				}
				$_
			} else {
				$processName = $null
				$processComputerName = $ComputerName
				$processCredential = $Credential
				if ($_ -is [string]) {
					$processName = $_
				} else {
					if ($_.Name) {
						$processName = $_.Name
					}
					if ((-not $processComputerName) -and ($_.ComputerName)) {
						$processComputerName = $_.ComputerName
					}
					if ((-not $processCredential) -and ($_.Credential)) {
						$processCredential = $_.Credential
					}
				}
				if (-not $processName) {
					throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
				}
				Get-LocalUser -Name $processName -ComputerName $processComputerName -Credential $processCredential | Set-LocalUser -Password $Password -Enable:$Enable -Disable:$Disable -Unlock:$Unlock -FullName $FullName -Description $Description -PasswordNeverExpires $PasswordNeverExpires -UserCannotChangePassword $UserCannotChangePassword -UserMustChangePasswordAtNextLogon $UserMustChangePasswordAtNextLogon -AccountExpirationDate $AccountExpirationDate
			}
		} else {
			if (-not $Name) {
				if (-not $promptedForRequiredParameters) {
					$promptedForRequiredParameters = $true
					Write-Host -ForegroundColor White -Object ((Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptCaption) -f 'Set-LocalUser',$MyInvocation.PipelinePosition)
					Write-Host (Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptMessage)
					$index = 0
					$Name = @()
					while ($result = Read-Host -Prompt "Name[$index]") {
						$index++
						$Name += $result
					}
					if (-not $Name) {
						return
					}
				} else {
					return
				}
			}
			Get-LocalUser -Name $Name -ComputerName $ComputerName -Credential $Credential | Set-LocalUser -Password $Password -Enable:$Enable -Disable:$Disable -Unlock:$Unlock -FullName $FullName -Description $Description -PasswordNeverExpires $PasswordNeverExpires -UserCannotChangePassword $UserCannotChangePassword -UserMustChangePasswordAtNextLogon $UserMustChangePasswordAtNextLogon -AccountExpirationDate $AccountExpirationDate
		}
	}
}

function global:Remove-LocalUser {
	param(
		[string[]]$Name = $null,
		[string[]]$ComputerName = @(),
		[System.Management.Automation.PSObject]$Credential = $null
	)

	begin{
		if ($args.Count) {
			throw $((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'NamedParameterNotFound') -f $null,$args[0])
		}
		$promptedForRequiredParameters = $false
	}

	process {
		if ($Name -and $_) {
			throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
		}
		if ($_) {
			$processName = $null
			$processComputerName = $ComputerName
			$processCredential = $Credential
			if ($_ -is [string]) {
				$processName = $_
			} else {
				if ($_.Name) {
					$processName = $_.Name
				}
				if ((-not $processComputerName) -and ($_.ComputerName)) {
					$processComputerName = $_.ComputerName
				}
				if ((-not $processCredential) -and ($_.Credential)) {
					$processCredential = $_.Credential
				}
			}
			if (-not $processName) {
				throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
			}
		} else {
			if (-not $Name) {
				if (-not $promptedForRequiredParameters) {
					$promptedForRequiredParameters = $true
					Write-Host -ForegroundColor White -Object ((Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptCaption) -f 'Remove-LocalUser',$MyInvocation.PipelinePosition)
					Write-Host (Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptMessage)
					$index = 0
					$Name = @()
					while ($result = Read-Host -Prompt "Name[$index]") {
						$index++
						$Name += $result
					}
					if (-not $Name) {
						return
					}
				} else {
					return
				}
			}
			$processName = $Name
			$processComputerName = $ComputerName
			$processCredential = $Credential
		}
		if (-not $processComputerName) {
			$processComputerName = @('.')
		}
		foreach ($item in $processComputerName) {
			if ($item -eq $env:COMPUTERNAME) {
				$item = '.'
			}
			if ($computer = Get-AdsiObject -AdsiPath "WinNT://$item" -ComputerName $item -Credential $processCredential) {
				foreach ($userName in $processName) {
					$computer.Delete('user',$userName)
				}
			}
		}
	}
}

#endregion
#region LocalGroup functions

function global:New-LocalGroup {
	param(
		[string[]]$Name = @(),
		[string[]]$ComputerName = @(),
		[string]$Description = $null,
		[System.Management.Automation.PSObject]$Credential = $null
	)

	if ($args.Count) {
		throw $((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'NamedParameterNotFound') -f $null,$args[0])
	}
	$promptedForRequiredParameters = $false
	if (-not $Name) {
		if (-not $promptedForRequiredParameters) {
			$promptedForRequiredParameters = $true
			Write-Host -ForegroundColor White -Object ((Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptCaption) -f 'New-LocalGroup',$MyInvocation.PipelinePosition)
			Write-Host (Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptMessage)
			$index = 0
			$Name = @()
			while ($result = Read-Host -Prompt "Name[$index]") {
				$index++
				$Name += $result
			}
			if (-not $Name) {
				return
			}
		} else {
			return
		}
	}

	if (-not $ComputerName) {
		$ComputerName = @('.')
	}
	$cancelled = $false
	if ($Credential) {
		$Credential = Get-Credential -Credential $Credential
		$cancelled = (-not $Credential)
	}

	if ($cancelled) {
		return
	}

	foreach ($item in $ComputerName) {
		if ($item -eq $env:COMPUTERNAME) {
			$item = '.'
		}
		$computer = Get-AdsiObject -AdsiPath "WinNT://$item" -ComputerName $item -Credential $Credential
		foreach ($groupName in $Name) {
			$group = $computer.Create('group',$groupName)
			if ($?) {
				$group.Put('GroupType',4)
				$group.SetInfo()
			}
			if ($? -and $Description) {
				$group.Put('Description',$Description)
				$group.SetInfo()
			}

			Get-LocalGroup -Name $groupName -ComputerName $item -Credential $Credential
		}
	}
}

function global:Get-LocalGroup {
	param(
		[string[]]$Name = $null,
		[string[]]$ComputerName = @(),
		[System.Management.Automation.PSObject]$Credential = $null
	)

	if ($args.Count) {
		throw $((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'NamedParameterNotFound') -f $null,$args[0])
	}

	$defaultProperties = @('Name','Description','ComputerName','SID')
	$defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet',[string[]]$defaultProperties)
	$PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)

	if (-not $ComputerName) {
		$ComputerName = @('.')
	}

	$cancelled = $false
	if ($Credential) {
		$Credential = Get-Credential -Credential $Credential
		$cancelled = (-not $Credential)
	}

	if ($cancelled) {
		return
	}

	foreach ($item in $ComputerName) {
		if ($item -eq $env:COMPUTERNAME) {
			$item = '.'
		}

		$computerSystem = $(if ($Credential) {Get-WmiObject -Namespace root\cimv2 -Class Win32_ComputerSystem -ComputerName $item -Credential $Credential} else {Get-WmiObject -Namespace root\cimv2 -Class Win32_ComputerSystem -ComputerName $item})
		if ($computerSystem.Name -eq $env:COMPUTERNAME) {
			$item = '.'
		}

		$filter = "Domain='$($computerSystem.Name)'"
		if ($Name.Count) {
			$filter += "AND ($(ConvertTo-WmiFilter -PropertyName Name -FilterValues $Name))"
		}

		$toStringMethod = {
			$this.Name
		}

		$renameMethod = {
			if ($args.Count -and $args[0] -is [string]) {
				[string]$newName = $args[0]
				$newName = $newName.Trim()
				if ($newName.Length -gt 20) {
					Write-Warning '[LocalGroup]::Rename: The new group name exceeds 20 characters in length and has been truncated.'
					$newName = $newName.SubString(0,20).Trim()
				}
				$arguments = @($newName)
				$result = $this.WmiGroup.PSBase.InvokeMethod('Rename',$arguments)
				if ($result -eq 0) {
					$this.WmiGroup.Name = $newName
					$this.WmiGroup.Caption = "$($this.WmiGroup.Domain)\$($this.WmiGroup.Name)"
					$computerName = $this.WmiGroup.__SERVER
					if ($ComputerName -eq $env:COMPUTERNAME) {
						$ComputerName = '.'
					}
					$this.ADSIGroup = Get-AdsiObject -AdsiPath "WinNT://$computerName/$newName,Group" -ComputerName $computerName -Credential $this.Credential
				}
			}
		}

		$getMembersMethod = {
			[string[]]$member = @()
			if ($args.Count -and $args[0]) {
				$member = $args[0]
			}

			$toStringMethod = {
				$this.Name
			}

			$getLocalUserMethod = {
				if ($this.Type -eq 'Local User') {
					Get-LocalUser -Name $this.Name.Replace("$($env:COMPUTERNAME)\",'') -ComputerName $this.ComputerName -Credential $this.LocalGroup.Credential
				}
			}

			$defaultProperties = @('Name','Type','Path','SID')
			$defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet',[string[]]$defaultProperties)
			$PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)

			$parentSidMap = @{}
			$localGroupMembers = @()
			$this.ADSIGroup.PSBase.Invoke('Members') | ForEach-Object {
				$guid = $_.GetType().InvokeMember('guid','GetProperty',$null,$_,$null)
				$name = $_.GetType().InvokeMember('name','GetProperty',$null,$_,$null)
				$sid = New-Object 'System.Security.Principal.SecurityIdentifier' (([byte[]]$_.GetType().InvokeMember('objectsid','GetProperty',$null,$_,$null)),0)
				$parentName = $_.GetType().InvokeMember('parent','GetProperty',$null,$_,$null) -replace 'WinNT:(//)?([^/]+/)?',''
				if ($parentName -and $sid.AccountDomainSid) {$parentSidMap[$sid.AccountDomainSid] = $parentName}
				if ((-not $parentName) -and ($name -eq $sid.Value)) {$name = 'Account Unknown'}
				$localAccount = ($parentName -eq $this.ComputerName)
				$type = 'Unknown'
				$path = $null
				switch ($guid) {
					'{D83F1060-1E71-11CF-B1F3-02608C9E7553}' {
						if ($localAccount) {
							$type = 'Local User'
							if ($name -ne 'Account Unknown') {
								$path = "WinNT://$parentName/$name,User"
							}
						} else {
							$type = 'Domain User'
							if ($name -ne 'Account Unknown') {
								$path = "WinNT://$parentName/$name,User"
								$name = "$parentName\$name"
							}
						}
						break
					}
					'{D9C1AAD0-1E71-11CF-B1F3-02608C9E7553}' {
						if ($sid.AccountDomainSid) {
							$type = 'Domain Group'
							if ($name -ne 'Account Unknown') {
								$path = "WinNT://$parentName/$name,Group"
								$name = "$parentName\$name"
							}
						} else {
							$type = 'Built-in Security Principal'
							$path = "WinNT://$parentName/$name"
							$name = "$parentName\$name"
						}
						break
					}
				}
				$localGroupMember = New-Object System.Management.Automation.PSObject `
					| Add-Member -MemberType MemberSet -Name PSStandardMembers -Value $PSStandardMembers -PassThru `
					| Add-Member -MemberType ScriptMethod -Name ToString -Value $toStringMethod -Force -PassThru `
					| Add-Member -MemberType ScriptMethod -Name GetLocalUser -Value $getLocalUserMethod -PassThru `
					| Add-Member -MemberType NoteProperty -Name LocalGroup -Value $this -PassThru `
					| Add-Member -MemberType ScriptProperty -Name LocalGroupName -Value {$this.LocalGroup.Name} -PassThru `
					| Add-Member -MemberType ScriptProperty -Name ComputerName -Value {$this.LocalGroup.ComputerName} -PassThru `
					| Add-Member -MemberType NoteProperty -Name Name -Value $name -PassThru `
					| Add-Member -MemberType NoteProperty -Name Type -Value $type -PassThru `
					| Add-Member -MemberType NoteProperty -Name SID -Value $sid.Value -PassThru `
					| Add-Member -MemberType NoteProperty -Name ParentSID -Value $sid.AccountDomainSid -PassThru `
					| Add-Member -MemberType NoteProperty -Name ParentName -Value $parentName -PassThru `
					| Add-Member -MemberType NoteProperty -Name Path -Value $path -PassThru
				$localGroupMember.PSObject.TypeNames[0] = 'LocalGroupMember'
				$localGroupMember.PSObject.TypeNames.Insert(0,"LocalGroupMember#$($type -replace ' ','')")
				$localGroupMembers += $localGroupMember
			}
			$localGroupMembers | ForEach-Object {
				if (($_.Name -eq 'Account Unknown') -and ($parentSidMap.Keys -contains $_.ParentSID)) {
					$_.Name = "$($parentSidMap[$_.ParentSID])\$($_.Name)"
				}
				if ($member.Count) {
					foreach ($item in $member) {
						if (("$($_.ParentName)" -like $item) -or (($_.Name -replace "^$($_.ParentName)\\",'') -like $item) -or (($item -match '\\') -and ("$($_.ParentName)\$($_.Name -replace `"^$($_.ParentName)\\`",''))" -like $item))) {
							$_
							break
						}
					}
				} else {
					$_
				}
			}
		}

		$containsMemberMethod = {
			if ($args.Count -and $args[0] -is [string]) {
				$member = $args[0]
				if ($member -notmatch '^(LDAP|WinNT)://') {
					$member = $member.TrimStart('\').Replace('\','/')
					if ($member -notmatch '/') {
						$member = "$($this.ComputerName)/$member"
					}
					$member = "WinNT://$member"
				}
				$this.ADSIGroup.IsMember($member)
			}
		}

		$addMemberMethod = {
			if ($args.Count -and $args[0] -is [string]) {
				$member = $args[0]
				if ($member -notmatch '^(LDAP|WinNT)://') {
					$member = $member.TrimStart('\').Replace('\','/')
					if ($member -notmatch '/') {
						$member = "$($this.ComputerName)/$member"
					}
					$member = "WinNT://$member"
				}
				$this.ADSIGroup.Add($member)
			}
		}

		$removeMemberMethod = {
			if ($args.Count -and $args[0] -is [string]) {
				$member = $args[0]
				if ($member -notmatch '^(LDAP|WinNT)://') {
					$member = $member.TrimStart('\').Replace('\','/')
					if ($member -notmatch '/') {
						$member = "$($this.ComputerName)/$member"
					}
					$member = "WinNT://$member"
				}
				$this.ADSIGroup.Remove($member)
			}
		}

		$(if ($Credential) {Get-WmiObject -Namespace root\cimv2 -Class Win32_Group -Filter $filter -ComputerName $item -Credential $Credential} else {Get-WmiObject -Namespace root\cimv2 -Class Win32_Group -Filter $filter -ComputerName $item}) `
			| Select-Object -Property @{Name='WmiGroup';Expression={$_}},@{Name='Credential';Expression={$Credential}} `
			| Add-Member -MemberType MemberSet -Name PSStandardMembers -Value $PSStandardMembers -PassThru `
			| Add-Member -MemberType ScriptMethod -Name ToString -Value $toStringMethod -Force -PassThru `
			| Add-Member -MemberType ScriptMethod -Name Rename -Value $renameMethod -PassThru `
			| Add-Member -MemberType ScriptProperty -Name ComputerName -Value {$this.WmiGroup.__SERVER} -PassThru `
			| Add-Member -MemberType ScriptProperty -Name Name -Value {$this.WmiGroup.Name} -PassThru `
			| Add-Member -MemberType ScriptProperty -Name FullyQualifiedName -Value {$this.WmiGroup.Caption} -PassThru `
			| Add-Member -MemberType ScriptProperty -Name SID -Value {$this.WmiGroup.SID} -PassThru `
			| Add-Member -MemberType ScriptProperty -Name InstallDate -Value {$this.WmiGroup.InstallDate} -PassThru `
			| ForEach-Object {
				$_ `
					| Add-Member -MemberType NoteProperty -Name ADSIGroup -Value (Get-AdsiObject -AdsiPath "WinNT://$item/$($_.Name),Group" -ComputerName $item -Credential $Credential) -PassThru `
					| Add-Member -MemberType ScriptMethod -Name GetMembers -Value $getMembersMethod -PassThru `
					| Add-Member -MemberType ScriptMethod -Name ContainsMember -Value $containsMemberMethod -PassThru `
					| Add-Member -MemberType ScriptMethod -Name AddMember -Value $addMemberMethod -PassThru `
					| Add-Member -MemberType ScriptMethod -Name RemoveMember -Value $removeMemberMethod -PassThru `
					| Add-Member -MemberType ScriptProperty -Name Description -Value {$this.ADSIGroup.Description.Value} -SecondValue {if ($args.Count -and $args[0] -is [string]) {$description = [string]$args[0]; $this.ADSIGroup.PSBase.InvokeSet('Description',$description); $this.ADSIGroup.PSBase.CommitChanges()}}
				$_.PSObject.TypeNames[0] = 'LocalGroup'
				$_
			}
	}
}

function global:Rename-LocalGroup {
	param(
		[string]$Name = $null,
		[string]$NewName = $null,
		[string[]]$ComputerName = @(),
		[System.Management.Automation.PSObject]$Credential = $null
	)

	begin{
		if ($args.Count) {
			throw $((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'NamedParameterNotFound') -f $null,$args[0])
		}
		$promptedForRequiredParameters = $false
	}

	process {
		if ($Name -and $_) {
			throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
		} elseif ($_) {
			if (-not $NewName) {
				if (-not $promptedForRequiredParameters) {
					$promptedForRequiredParameters = $true
					Write-Host -ForegroundColor White -Object ((Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptCaption) -f 'Rename-LocalGroup',$MyInvocation.PipelinePosition)
					Write-Host (Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptMessage)
					if (-not $NewName) {
						$result = Read-Host -Prompt "NewName"
						if ($result) {
							$NewName
						} else {
							return
						}
					}
				}
			}
			if ($_.PSObject.TypeNames -contains 'LocalGroup') {
				$_.Rename($NewName)
				$_
			} else {
				$processName = $null
				$processComputerName = $ComputerName
				$processCredential = $Credential
				if ($_ -is [string]) {
					$processName = $_
				} else {
					if ($_.Name) {
						$processName = $_.Name
					}
					if ((-not $processComputerName) -and ($_.ComputerName)) {
						$processComputerName = $_.ComputerName
					}
					if ((-not $processCredential) -and ($_.Credential)) {
						$processCredential = $_.Credential
					}
				}
				if (-not $processName) {
					throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
				}
				Get-LocalGroup -Name $processName -ComputerName $processComputerName -Credential $processCredential | Rename-LocalGroup -NewName $NewName
			}
		} else {
			if ((-not $Name) -or (-not $NewName)) {
				if (-not $promptedForRequiredParameters) {
					$promptedForRequiredParameters = $true
					Write-Host -ForegroundColor White -Object ((Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptCaption) -f 'Rename-LocalGroup',$MyInvocation.PipelinePosition)
					Write-Host (Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptMessage)
					if (-not $Name) {
						$result = Read-Host -Prompt "Name"
						if ($result) {
							$Name = $result
						} else {
							return
						}
					}
					if (-not $NewName) {
						$result = Read-Host -Prompt "NewName"
						if ($result) {
							$NewName
						} else {
							return
						}
					}
				}
			}
			Get-LocalGroup -Name $Name -ComputerName $ComputerName -Credential $Credential | Rename-LocalGroup -NewName $NewName
		}
	}
}

function global:Set-LocalGroup {
	param(
		[string[]]$Name = $null,
		[string]$Description = $null,
		[string[]]$ComputerName = @(),
		[System.Management.Automation.PSObject]$Credential = $null
	)

	begin{
		if ($args.Count) {
			throw $((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'NamedParameterNotFound') -f $null,$args[0])
		}
		$promptedForRequiredParameters = $false
	}

	process {
		if ($Name -and $_) {
			throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
		} elseif ($_) {
			if ($_.PSObject.TypeNames -contains 'LocalGroup') {
				if ($Description -and ($_.Description -cne $Description)) {
					$_.Description = $Description
				}
				$_
			} else {
				$processName = $null
				$processComputerName = $ComputerName
				$processCredential = $Credential
				if ($_ -is [string]) {
					$processName = $_
				} else {
					if ($_.Name) {
						$processName = $_.Name
					}
					if ((-not $processComputerName) -and ($_.ComputerName)) {
						$processComputerName = $_.ComputerName
					}
					if ((-not $processCredential) -and ($_.Credential)) {
						$processCredential = $_.Credential
					}
				}
				if (-not $processName) {
					throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
				}
				Get-LocalGroup -Name $processName -ComputerName $processComputerName -Credential $processCredential | ForEach-Object {
					if ($Description -and ($_.Description -cne $Description)) {
						$_.Description = $Description
					}
					$_
				}
			}
		} else {
			if (-not $Name) {
				if (-not $promptedForRequiredParameters) {
					$promptedForRequiredParameters = $true
					Write-Host -ForegroundColor White -Object ((Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptCaption) -f 'Set-LocalGroup',$MyInvocation.PipelinePosition)
					Write-Host (Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptMessage)
					$index = 0
					$Name = @()
					while ($result = Read-Host -Prompt "Name[$index]") {
						$index++
						$Name += $result
					}
					if (-not $Name) {
						return
					}
				} else {
					return
				}
			}
			Get-LocalGroup -Name $Name -ComputerName $ComputerName -Credential $Credential | Set-LocalGroup -Description $Description
		}
	}
}

function global:Remove-LocalGroup {
	param(
		[string[]]$Name = $null,
		[string]$ComputerName = @(),
		[System.Management.Automation.PSObject]$Credential = $null
	)

	begin{
		if ($args.Count) {
			throw $((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'NamedParameterNotFound') -f $null,$args[0])
		}
		$promptedForRequiredParameters = $false
	}

	process {
		if ($Name -and $_) {
			throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
		}
		if ($_) {
			$processName = $null
			$processComputerName = $ComputerName
			$processCredential = $Credential
			if ($_ -is [string]) {
				$processName = $_
			} else {
				if ($_.Name) {
					$processName = $_.Name
				}
				if ((-not $processComputerName) -and ($_.ComputerName)) {
					$processComputerName = $_.ComputerName
				}
				if ((-not $processCredential) -and ($_.Credential)) {
					$processCredential = $_.Credential
				}
			}
			if (-not $processName) {
				throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
			}
		} else {
			if (-not $Name) {
				if (-not $promptedForRequiredParameters) {
					$promptedForRequiredParameters = $true
					Write-Host -ForegroundColor White -Object ((Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptCaption) -f 'Remove-LocalGroup',$MyInvocation.PipelinePosition)
					Write-Host (Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptMessage)
					$index = 0
					$Name = @()
					while ($result = Read-Host -Prompt "Name[$index]") {
						$index++
						$Name += $result
					}
					if (-not $Name) {
						return
					}
				} else {
					return
				}
			}
			$processName = $Name
			$processComputerName = $ComputerName
			$processCredential = $Credential
		}
		if (-not $processComputerName) {
			$processComputerName = @('.')
		}
		foreach ($item in $processComputerName) {
			if ($item -eq $env:COMPUTERNAME) {
				$item = '.'
			}
			if ($computer = Get-AdsiObject -AdsiPath "WinNT://$item" -ComputerName $item -Credential $processCredential) {
				foreach ($groupName in $processName) {
					$computer.Delete('group',$groupName)
				}
			}
		}
	}
}

#endregion
#region LocalGroupMember functions

function global:Add-LocalGroupMember {
	param(
		[string[]]$Name = $null,
		[string[]]$ComputerName = @(),
		[System.Management.Automation.PSObject]$Credential = $null,
		$Member = $null
	)

	begin{
		if ($args.Count) {
			throw $((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'NamedParameterNotFound') -f $null,$args[0])
		}
		$promptedForRequiredParameters = $false
	}

	process {
		if ($Name -and $_) {
			throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
		} elseif ($_) {
			if (-not $Member) {
				if (-not $promptedForRequiredParameters) {
					$promptedForRequiredParameters = $true
					Write-Host -ForegroundColor White -Object ((Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptCaption) -f 'Add-LocalGroupMember',$MyInvocation.PipelinePosition)
					Write-Host (Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptMessage)
					if (-not $Member) {
						$index = 0
						$Member = @()
						while ($result = Read-Host -Prompt "Member[$index]") {
							$index++
							$Member += $result
						}
						if (-not $Member) {
							return
						}
					}
				} else {
					return
				}
			}
			if ($_.PSObject.TypeNames -contains 'LocalGroup') {
				foreach ($item in $Member) {
					if ($item) {
						[string]$memberIdentifier = $item
						if ($item.PSObject.TypeNames -contains 'LocalUser') {
							$memberIdentifier = $item.Name
						} elseif ($item -is [System.DirectoryServices.DirectoryEntry]) {
							$memberIdentifier = $item.PSBase.Path
						} elseif ($item.PSObject.TypeNames -contains 'Quest.ActiveRoles.ArsPowerShellSnapIn.Data.ArsPersonObject') {
							$memberIdentifier = $item.Path
						}
						$_.AddMember($memberIdentifier)
					}
				}
				$_
			} else {
				$processName = $null
				$processComputerName = $ComputerName
				$processCredential = $Credential
				if ($_ -is [string]) {
					$processName = $_
				} else {
					if ($_.Name) {
						$processName = $_.Name
					}
					if ((-not $processComputerName) -and ($_.ComputerName)) {
						$processComputerName = $_.ComputerName
					}
					if ((-not $processCredential) -and ($_.Credential)) {
						$processCredential = $_.Credential
					}
				}
				if (-not $processName) {
					throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
				}
				Get-LocalGroup -Name $processName -ComputerName $processComputerName -Credential $processCredential | ForEach-Object {
					foreach ($item in $Member) {
						if ($item) {
							[string]$memberIdentifier = $item
							if ($item.PSObject.TypeNames -contains 'LocalUser') {
								$memberIdentifier = $item.Name
							} elseif ($item -is [System.DirectoryServices.DirectoryEntry]) {
								$memberIdentifier = $item.PSBase.Path
							} elseif ($item.PSObject.TypeNames -contains 'Quest.ActiveRoles.ArsPowerShellSnapIn.Data.ArsPersonObject') {
								$memberIdentifier = $item.Path
							}
							$_.AddMember($memberIdentifier)
						}
					}
					$_
				}
			}
		} else {
			if ((-not $Name) -or (-not $Member)) {
				if (-not $promptedForRequiredParameters) {
					$promptedForRequiredParameters = $true
					Write-Host -ForegroundColor White -Object ((Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptCaption) -f 'Add-LocalGroupMember',$MyInvocation.PipelinePosition)
					Write-Host (Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptMessage)
					if (-not $Name) {
						$index = 0
						$Name = @()
						while ($result = Read-Host -Prompt "Name[$index]") {
							$index++
							$Name += $result
						}
						if (-not $Name) {
							return
						}
					}
					if (-not $Member) {
						$index = 0
						$Member = @()
						while ($result = Read-Host -Prompt "Member[$index]") {
							$index++
							$Member += $result
						}
						if (-not $Member) {
							return
						}
					}
				} else {
					return
				}
			}
			Get-LocalGroup -Name $Name -ComputerName $ComputerName -Credential $Credential | Add-LocalGroupMember -Member $Member
		}
	}
}

function global:Get-LocalGroupMember {
	param(
		[string[]]$Name = $null,
		[string[]]$ComputerName = @(),
		[System.Management.Automation.PSObject]$Credential = $null,
		$Member = $null
	)

	begin{
		if ($args.Count) {
			throw $((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'NamedParameterNotFound') -f $null,$args[0])
		}
		$promptedForRequiredParameters = $false
	}

	process {
		if ($Name -and $_) {
			throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
		} elseif ($_) {
			if ($_.PSObject.TypeNames -contains 'LocalGroup') {
				$_.GetMembers($Member)
			} else {
				$processName = $null
				$processComputerName = $ComputerName
				$processCredential = $Credential
				if ($_ -is [string]) {
					$processName = $_
				} else {
					if ($_.Name) {
						$processName = $_.Name
					}
					if ((-not $processComputerName) -and ($_.ComputerName)) {
						$processComputerName = $_.ComputerName
					}
					if ((-not $processCredential) -and ($_.Credential)) {
						$processCredential = $_.Credential
					}
				}
				if (-not $processName) {
					throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
				}
				Get-LocalGroup -Name $processName -ComputerName $processComputerName -Credential $processCredential | ForEach-Object {
					$_.GetMembers($Member)
				}
			}
		} else {
			if (-not $Name) {
				if (-not $promptedForRequiredParameters) {
					$promptedForRequiredParameters = $true
					Write-Host -ForegroundColor White -Object ((Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptCaption) -f 'Get-LocalGroupMember',$MyInvocation.PipelinePosition)
					Write-Host (Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptMessage)
					if (-not $Name) {
						$index = 0
						$Name = @()
						while ($result = Read-Host -Prompt "Name[$index]") {
							$index++
							$Name += $result
						}
						if (-not $Name) {
							return
						}
					}
				} else {
					return
				}
			}
			Get-LocalGroup -Name $Name -ComputerName $ComputerName -Credential $Credential | Get-LocalGroupMember -Member $Member
		}
	}
}

function global:Remove-LocalGroupMember {
	param(
		[string[]]$Name = $null,
		[string[]]$ComputerName = @(),
		[System.Management.Automation.PSObject]$Credential = $null,
		$Member = $null
	)

	begin{
		if ($args.Count) {
			throw $((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'NamedParameterNotFound') -f $null,$args[0])
		}
		$promptedForRequiredParameters = $false
	}

	process {
		if ($Name -and $_) {
			throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
		} elseif ($_) {
			if (-not $Member) {
				if (-not $promptedForRequiredParameters) {
					$promptedForRequiredParameters = $true
					Write-Host -ForegroundColor White -Object ((Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptCaption) -f 'Remove-LocalGroupMember',$MyInvocation.PipelinePosition)
					Write-Host (Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptMessage)
					if (-not $Member) {
						$index = 0
						$Member = @()
						while ($result = Read-Host -Prompt "Member[$index]") {
							$index++
							$Member += $result
						}
						if (-not $Member) {
							return
						}
					}
				} else {
					return
				}
			}
			if ($_.PSObject.TypeNames -contains 'LocalGroup') {
				foreach ($item in $Member) {
					if ($item) {
						[string]$memberIdentifier = $item
						if ($item.PSObject.TypeNames -contains 'LocalUser') {
							$memberIdentifier = $item.Name
						} elseif ($item -is [System.DirectoryServices.DirectoryEntry]) {
							$memberIdentifier = $item.PSBase.Path
						} elseif ($item.PSObject.TypeNames -contains 'Quest.ActiveRoles.ArsPowerShellSnapIn.Data.ArsPersonObject') {
							$memberIdentifier = $item.Path
						}
						$_.RemoveMember($memberIdentifier)
					}
				}
				$_
			} else {
				$processName = $null
				$processComputerName = $ComputerName
				$processCredential = $Credential
				if ($_ -is [string]) {
					$processName = $_
				} else {
					if ($_.Name) {
						$processName = $_.Name
					}
					if ((-not $processComputerName) -and ($_.ComputerName)) {
						$processComputerName = $_.ComputerName
					}
					if ((-not $processCredential) -and ($_.Credential)) {
						$processCredential = $_.Credential
					}
				}
				if (-not $processName) {
					throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
				}
				Get-LocalGroup -Name $processName -ComputerName $processComputerName -Credential $processCredential | ForEach-Object {
					foreach ($item in $Member) {
						if ($item) {
							[string]$memberIdentifier = $item
							if ($item.PSObject.TypeNames -contains 'LocalUser') {
								$memberIdentifier = $item.Name
							} elseif ($item -is [System.DirectoryServices.DirectoryEntry]) {
								$memberIdentifier = $item.PSBase.Path
							} elseif ($item.PSObject.TypeNames -contains 'Quest.ActiveRoles.ArsPowerShellSnapIn.Data.ArsPersonObject') {
								$memberIdentifier = $item.Path
							}
							$_.RemoveMember($memberIdentifier)
						}
					}
					$_
				}
			}
		} else {
			if ((-not $Name) -or (-not $Member)) {
				if (-not $promptedForRequiredParameters) {
					$promptedForRequiredParameters = $true
					Write-Host -ForegroundColor White -Object ((Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptCaption) -f 'Remove-LocalGroupMember',$MyInvocation.PipelinePosition)
					Write-Host (Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptMessage)
					if (-not $Name) {
						$index = 0
						$Name = @()
						while ($result = Read-Host -Prompt "Name[$index]") {
							$index++
							$Name += $result
						}
						if (-not $Name) {
							return
						}
					}
					if (-not $Member) {
						$index = 0
						$Member = @()
						while ($result = Read-Host -Prompt "Member[$index]") {
							$index++
							$Member += $result
						}
						if (-not $Member) {
							return
						}
					}
				} else {
					return
				}
			}
			Get-LocalGroup -Name $Name -ComputerName $ComputerName -Credential $Credential | Remove-LocalGroupMember -Member $Member
		}
	}
}

#endregion
#region LocalGroupMembership Functions

function global:Get-LocalGroupMembership {
	param(
		[string[]]$Name = $null,
		[string[]]$ComputerName = @(),
		[System.Management.Automation.PSObject]$Credential = $null
	)

	begin{
		if ($args.Count) {
			throw $((Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'NamedParameterNotFound') -f $null,$args[0])
		}
		$promptedForRequiredParameters = $false
	}

	process {
		if ($Name -and $_) {
			throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
		} elseif ($_) {
			if ($_.PSObject.TypeNames -contains 'LocalUser') {
				$_.GetGroups()
			} else {
				$processName = $null
				$processComputerName = $ComputerName
				$processCredential = $Credential
				if ($_ -is [string]) {
					$processName = $_
				} else {
					if ($_.Name) {
						$processName = $_.Name
					}
					if ((-not $processComputerName) -and ($_.ComputerName)) {
						$processComputerName = $_.ComputerName
					}
					if ((-not $processCredential) -and ($_.Credential)) {
						$processCredential = $_.Credential
					}
				}
				if (-not $processName) {
					throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
				}
				Get-LocalUser -Name $processName -ComputerName $processComputerName -Credential $processCredential | ForEach-Object {
					$_.GetGroups($Member)
				}
			}
		} else {
			if (-not $Name) {
				if (-not $promptedForRequiredParameters) {
					$promptedForRequiredParameters = $true
					Write-Host -ForegroundColor White -Object ((Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptCaption) -f 'Get-LocalGroupMembership',$MyInvocation.PipelinePosition)
					Write-Host (Get-PSResourceString -BaseName ParameterBinderStrings -ResourceId PromptMessage)
					if (-not $Name) {
						$index = 0
						$Name = @()
						while ($result = Read-Host -Prompt "Name[$index]") {
							$index++
							$Name += $result
						}
						if (-not $Name) {
							return
						}
					}
				} else {
					return
				}
			}
			Get-LocalGroup -Name $Name -ComputerName $ComputerName -Credential $Credential | Get-LocalGroupMembership
		}
	}
}

#endregion

#endregion
#region Managed Computer Functions

function global:Initialize-ManagedComputerCache {

	# Create and enable the credential cache

	$credentialCache = Get-CredentialCache | Enable-CredentialCache -PassThru

	# If the WMI connection cache is not initialized, initialize it ('.' represents the local computer)

	if ((-not (Get-Variable -Name wmiConnections -Scope Global -ErrorAction SilentlyContinue)) -or ($global:wmiConnections.Count -eq 0)) {

		$global:wmiConnections = @{}
		$global:wmiConnections['.'] = @{'ComputerName'='.'}

		# Read the managed computer list from the appropriate file and add nodes for managed computers to the tree

		$configXmlPath = "$($Host.PrivateData.UserAppData)\PowerPack.Config.xml"
		if ((-not (Test-Path -Path $configXmlPath)) -and (Test-Path -Path "$($Host.PrivateData.UserAppData)\Quest.PowerGUI.PowerPack.Config.xml")) {
			Rename-Item -Path "$($Host.PrivateData.UserAppData)\Quest.PowerGUI.PowerPack.Config.xml" -NewName $configXmlPath
		}
		if (Test-Path -Path $configXmlPath) {
			$fileContents = Get-Content -Force -Encoding Unicode -Path $configXmlPath | ForEach-Object {
				$_.Replace('managedobjects>','ManagedObjects>').Replace('computers>','Computers>').Replace('computer>','Computer>').Replace('name>','Name>').Replace('connectionaccount>','ConnectionAccount>').Replace('domains>','Domains>').Replace('domain>','Domain>').Replace('service>','Service>')
			}
			$fileContents = ([string]::Join("`n",$fileContents) -replace '\s*<computers>\s*</computers>','' -replace '\s*<domains>\s*</domains>','').Split("`n")
			$powerPackConfig = [xml]$fileContents
			if ($managedComputers = $powerPackConfig.ManagedObjects.Computers.Computer) {
				foreach ($computer in $managedComputers) {
					$global:wmiConnections[$computer.Name] = @{'ComputerName'=$computer.Name}
					if ($computer.ConnectionAccount) {
						Add-CachedCredential -Credential $computer.ConnectionAccount -AssociatedObjectId $computer.Name
					}
				}
			}
		}
	}
}

function global:Add-ManagedComputer {
	param(
		[String[]]$ComputerName,
		[string]$ConnectionAccount = $null
	)

	Initialize-ManagedComputerCache

	if ($ComputerName) {

		# Filter out the local computer since it is managed automatically

		$localComputerHits = @()
		$localComputerSystem = Get-WmiObject -Namespace root\cimv2 -Class Win32_ComputerSystem
		$localComputerIds = @('.','localhost','loopback','127.0.0.1',$localComputerSystem.Name)
		if (($localComputerSystem.DomainRole -ne 0) -and ($localComputerSystem.DomainRole -ne 2)) {
			$localComputerIds += ($localComputerSystem.Name + '.' + $localComputerSystem.Domain)
		}
		$localComputerIds += Get-WmiObject -Namespace root\cimv2 -Class Win32_NetworkAdapterConfiguration | ForEach-Object {$_.IPAddress | ForEach-Object {$_}}
		$ComputerName = $ComputerName `
			| ForEach-Object {$_.Split(',')} `
			| ForEach-Object {
				$userInput = $_.Trim('''" ')
				if ($userInput) {
					if ($localComputerIds -contains $userInput) {
						$localComputerHits += $userInput
					} else {
						$userInput
					}
				}
			}
		if ($localComputerHits) {
			[System.Windows.Forms.MessageBox]::Show("The following identifiers represent the local system. The local system is managed automatically so these will not be added.`n`n$([string]::Join(`"`n`",$localComputerHits))",'Local System Identifiers Found',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
		}

	}

	if ($ComputerName) {

		# Add a new connection to the global WMI connection cache for each computer name passed in

		$configXmlPath = "$($Host.PrivateData.UserAppData)\PowerPack.Config.xml"
		$newConfigXmlPath = $configXmlPath
		if ((-not (Test-Path -Path $configXmlPath)) -and (Test-Path -Path "$($Host.PrivateData.UserAppData)\Quest.PowerGUI.PowerPack.Config.xml")) {
			Rename-Item -Path "$($Host.PrivateData.UserAppData)\Quest.PowerGUI.PowerPack.Config.xml" -NewName $configXmlPath
		}
		if (-not (Test-Path -Path $configXmlPath)) {
			$computerItems = $ComputerName | ForEach-Object { "<Computer><Name>$_</Name></Computer>" }
			$powerPackConfig = [xml]"<?xml version=`"1.0`" encoding=`"utf-8`" ?><ManagedObjects><Computers>$computerItems</Computers></ManagedObjects>"
			$powerPackConfig.Save($newConfigXmlPath)
			$configXmlPath = $newConfigXmlPath
		}

		$fileContents = Get-Content -Force -Encoding Unicode -Path $configXmlPath | ForEach-Object {
			$_.Replace('managedobjects>','ManagedObjects>').Replace('computers>','Computers>').Replace('computer>','Computer>').Replace('name>','Name>').Replace('connectionaccount>','ConnectionAccount>').Replace('domains>','Domains>').Replace('domain>','Domain>').Replace('service>','Service>')
		}
		$fileContents = ([string]::Join("`n",$fileContents) -replace '\s*<computers>\s*</computers>','' -replace '\s*<domains>\s*</domains>','').Split("`n")
		$powerPackConfig = [xml]$fileContents
		$managedComputers = $powerPackConfig.ManagedObjects.Computers.Computer | ForEach-Object {$_.Name}

		foreach ($item in $ComputerName) {
			if ($global:wmiConnections.Keys -notcontains $item) {
				if ($ConnectionAccount) {
					$global:wmiConnections[$item] = @{'ComputerName'=$item;'ManagementScope'=(New-Object System.Management.ManagementScope);'ConnectionAccount'=$ConnectionAccount}
				} else {
					$global:wmiConnections[$item] = @{'ComputerName'=$item;'ManagementScope'=(New-Object System.Management.ManagementScope)}
				}
				$global:wmiConnections[$item].ManagementScope.Path = "\\$($item)\root"
				$global:wmiConnections[$item].ManagementScope.Options = New-Object System.Management.ConnectionOptions
				if ($ConnectionAccount) {
					$global:wmiConnections[$item].ManagementScope.Options.Username = $ConnectionAccount
				}
			}

			if ($global:wmiConnections[$item].ConnectionAccount) {
				if ($global:wmiConnections[$item].ConnectionPassword) {
					if (-not $global:wmiConnections[$item].Credential) {
						$global:wmiConnections[$item].ManagementScope.Options.Username = $global:wmiConnections[$item].ConnectionAccount
						$global:wmiConnections[$item].ManagementScope.Options.SecurePassword = $global:wmiConnections[$item].ConnectionPassword
						$global:wmiConnections[$item]['Credential'] = New-Object System.Management.Automation.PSCredential($global:wmiConnections[$item].ConnectionAccount,$global:wmiConnections[$item].ConnectionPassword)
					}
				} else {
					trap {
						continue
					}

					if ($credential = Get-Credential -Credential $global:wmiConnections[$item].ConnectionAccount) {
						$global:wmiConnections[$item]['ConnectionPassword'] = $credential.Password
						$global:wmiConnections[$item].ManagementScope.Options.Username = $global:wmiConnections[$item].ConnectionAccount
						$global:wmiConnections[$item].ManagementScope.Options.SecurePassword = $global:wmiConnections[$item].ConnectionPassword
						$global:wmiConnections[$item]['Credential'] = $credential
						Set-CachedCredential -Credential $credential -AssociatedObjectId $item
					}
				}
			}

			if ($managedComputers -notcontains $item) {
				$computerElement = $powerPackConfig.CreateElement('Computer')
				$nameElement = $powerPackConfig.CreateElement('Name')
				$nameElement.PSBase.InnerText = $item
				$nameNode = $computerElement.AppendChild($nameElement)
				if ($ConnectionAccount) {
					$connectionAccountElement = $powerPackConfig.CreateElement('ConnectionAccount')
					$connectionAccountElement.PSBase.InnerText = $ConnectionAccount
					$connectionAccountNode = $computerElement.AppendChild($connectionAccountElement)
				}
				if ($computersNode = $powerPackConfig.SelectSingleNode('ManagedObjects/Computers')) {
					$computerNode = $computersNode.AppendChild($computerElement)
				} else {
					$computersElement = $powerPackConfig.CreateElement('Computers')
					$computerNode = $computersElement.AppendChild($computerElement)
					$computersNode = $powerPackConfig.get_DocumentElement().AppendChild($computersElement)
				}
				$managedComputers += $item
			}
		}

		# Export the file system cache with the list of managed computers

		$powerPackConfig.Save($newConfigXmlPath)
	}
}

#endregion
#region Admin Console Functions

function global:Get-AdminConsoleName {
	if ($Host.PrivateData.ProductTitle) {
		$Host.PrivateData.ProductTitle
	} else {
		$currentNode = $Host.PrivateData.ConsoleHostFactory.Application.Navigation.CurrentItem
		while ($currentNode.Type -ne 'Root') {
			$currentNode = $currentNode.Parent
		}
		$currentNode.Name
	}
}

function global:Get-AdminConsoleViewName {
	$Host.PrivateData.ConsoleHostFactory.Application.Navigation.LinkLabel
}

function global:Get-AdminConsoleNodePath {
	param(
		$Node = $Host.PrivateData.ConsoleHostFactory.Application.Navigation.CurrentItem
	)

	if ($Node.Type -ne 'Root') {
		$path = $Node.Name
	} else {
		$path = ''
	}

	while (($Node = $Node.Parent) -and ($Node.Type -ne 'Root')) {
		$path = "$($Node.Name)\$path"
	}

	$path
}

function global:Add-AdminConsoleDynamicScriptNode {
	param(
		$ParentNode,
		[string] $Name,
		$Script,
		[System.Management.Automation.PSObject[]] $ScriptParameters = $null,
		[System.Management.Automation.PSObject] $AssociatedObject = $null,
		[System.Management.Automation.PSObject] $IconTypeIdentifier = $null,
		[switch]$PassThru
	)

	$childNode = $ParentNode.AddChild()
	$childNode.Name = $Name
	if ($Script -is [System.Management.Automation.ScriptBlock]) {
		[string]$parameters = ''
		[string[]]$parameterArray = @()
		if ($ScriptParameters -is [System.Collections.Hashtable]) {
			if ($ScriptParameters.Keys.Count) {
				foreach ($item in $ScriptParameters.Keys) {
					if ($ScriptParameters[$item].Count -gt 0) {
						$parameterArray += "-$item @('$([string]::Join(''',''',@($ScriptParameters[$item] | ForEach-Object {$_.Replace('''','''''')})))')"
					} elseif ($ScriptParameters[$item].Count -eq 0) {
						$parameterArray += "-$item @()"
					} else {
						$parameterArray += "-$item '$($ScriptParameters[$item].Replace('''',''''''))'"
					}
				}
			}
		} elseif ($ScriptParameters.Count -ne $null) {
			for ($index = 0; $index -lt $ScriptParameters.Count; $index++) {
				if ($ScriptParameters[$index].Count -ne $null) {
					$parameterArray += "@('$([string]::Join(''',''',@($ScriptParameters[$index] | ForEach-Object {$_.Replace('''','''''')})))')"
				} elseif ($ScriptParameters[$index].Count -eq 0) {
					$parameterArray += "-$item @()"
				} else {
					$parameterArray += "'$($ScriptParameters[$index].Replace('''',''''''))'"
				}
			}
		} else {
			$parameters = $ScriptParameters
		}
		if ($parameterArray.Count) {
			$parameters = [string]::Join(' ',$parameterArray)
		}
		$childNode.Script = @"
& {
    $Script
} $parameters
"@
	} else {
		$childNode.Script = $Script.ToString()
	}

	if ($AssociatedObject) {
		Set-AdminConsoleNodeData -Node $childNode -AssociatedObject $AssociatedObject
	}

	if ($IconTypeIdentifier) {
		if ($IconTypeIdentifier -is [string]) {
			$childNode.SetIconByType($IconTypeIdentifier)
		} else {
			$childNode.SetIconByType($IconTypeIdentifier.PSObject.TypeNames[0])
		}
	}

	$ParentNode.Expand()

	if ($PassThru) {
		$childNode
	}
}

function global:Get-AdminConsoleNodeData {
	param(
		$Node = $null
	)
	if ($host.Name -ne 'PowerGUIHost') {
		throw 'Get-AdminConsoleNodeData is only valid when used inside the Admin Console'	
	} else {
		if (-not $Node) {
			$Node = $Host.PrivateData.ConsoleHostFactory.Application.Navigation.CurrentItem
		}
		$nodePath = Get-AdminConsoleNodePath $Node
		if (-not (Get-Variable -Scope Global -Name AdminConsoleNodeDataMap -ErrorAction SilentlyContinue)) {
			$global:AdminConsoleNodeDataMap = @{}
		} elseif ($global:AdminConsoleNodeDataMap.ContainsKey($nodePath)) {
			$global:AdminConsoleNodeDataMap[$nodePath]
		}
	}
}

function global:Set-AdminConsoleNodeData {
	param(
		$Node = $null,
		[System.Management.Automation.PSObject] $AssociatedObject = $null
	)
	
	if ($host.Name -ne 'PowerGUIHost') {
		throw 'Set-AdminConsoleNodeData is only valid when used inside the Admin Console'	
	} else {
		if (-not $Node) {
			$Node = $Host.PrivateData.ConsoleHostFactory.Application.Navigation.CurrentItem
		}
		$nodePath = Get-AdminConsoleNodePath $Node
		if (-not (Get-Variable -Scope Global -Name AdminConsoleNodeDataMap -ErrorAction SilentlyContinue)) {
			$global:AdminConsoleNodeDataMap = @{}
		}
		if ($AssociatedObject) {
			$global:AdminConsoleNodeDataMap[$nodePath] = $AssociatedObject
		} else {
			$global:AdminConsoleNodeDataMap.Remove($nodePath)
		}
	}
}

function global:Update-AdminConsoleLinkLabel {
	param(
		[string] $Prefix = $null,
		[string] $Property = 'Name',
		[int] $MaxLength = 50,
		$InputObject = $null
	)
	begin {
		$label = $null
	}
	process {
		if ($InputObject -and $_) {
			throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'AmbiguousParameterSet')
		} elseif ($InputObject -or $_) {
			$processObject = $(if ($InputObject) {$InputObject} else {$_})
			if (-not $label) {
				if ($Prefix) {
					$label = "$Prefix $($processObject.`"$Property`")"
				} else {
					$label = $processObject."$Property"
				}
			} else {
				$label = "$label, $($processObject.`"$Property`")"
				if ($label.Length -gt $maxLength) {
					$label = "$($label.SubString(0,$MaxLength-3))..."
				}
			}
			if ($host.Name -eq 'PowerGUIHost') {
				$Host.PrivateData.ConsoleHostFactory.Application.Action.Links.LinkLabel = $label
			}
			$processObject
		} else {
			throw $(Get-PSResourceString -BaseName 'ParameterBinderStrings' -ResourceId 'InputObjectNotBound')
		}
	}
	end {
	}
}

function Install-AdminConsoleStencilFile {
	param(
		$Filename
	)
	#region Initialize local variables.
	[System.Reflection.Assembly] $visioAssembly           = $null
	[string]                     $visioAssemblyName       = $null
	[string]                     $myShapesPath            = $null
	[string]                     $stencilMyShapesPath     = $null
	[string]                     $adminConsoleFolder      = $null
	[string]                     $stencilAdminConsolePath = $null
	#endregion

	#region Import the Visio assembly if it is not already loaded.
	$visioAssembly = Import-VisioAssembly -PassThru
	$visioAssemblyName = $visioAssembly.FullName
	#endregion

	#region Determine the 'My Shapes' folder path for the current Visio assembly.
	if ($visioAssemblyName -eq 'Microsoft.Office.Interop.Visio, Version=12.0.0.0, Culture=neutral, PublicKeyToken=71e9bce111e9429c') {
		$myShapesPath = (Get-ItemProperty -Path 'Registry::HKEY_CURRENT_USER\Software\Microsoft\Office\12.0\Visio\Application' -ErrorAction SilentlyContinue).MyShapesPath
	} else {
		$myShapesPath = (Get-ItemProperty -Path 'Registry::HKEY_CURRENT_USER\Software\Microsoft\Office\11.0\Visio\Application' -ErrorAction SilentlyContinue).MyShapesPath
	}
	#endregion

	#region Copy the stencil to the 'My Shapes' folder if it isn't there already.
	$stencilMyShapesPath = Join-Path -Path $myShapesPath -ChildPath $Filename
	if (-not (Test-Path -Path $stencilMyShapesPath -ErrorAction SilentlyContinue)) {
		$adminConsoleFolder = Split-Path -Path $([System.Reflection.Assembly]::GetEntryAssembly().Location) -Parent
		if ($adminConsoleFolder) {
			$stencilAdminConsolePath = Join-Path -Path $adminConsoleFolder -ChildPath $Filename
			if (Test-Path -Path $stencilAdminConsolePath -ErrorAction SilentlyContinue) {
				Copy-Item -LiteralPath $stencilAdminConsolePath -Destination $myShapesPath
			}
		}
	}
	#endregion

	#region Throw an error if the stencil does not exist in the 'My Shapes' folder.
	if (-not (Test-Path -Path $stencilMyShapesPath -ErrorAction SilentlyContinue)) {
		throw "The installation of the stencil '$Filename' failed."
	}
	#endregion
}

#endregion
#region Admin Console Dynamic Node Generation Functions

function global:Add-AdminConsoleWMIConnection {
	param(
		$ComputerName = '.'
	)

	$selectedNode = $host.PrivateData.ConsoleHostFactory.Application.Navigation.CurrentItem

	$newNodeName = $(if ($computerName -eq '.') {'Local System'} else {$ComputerName})

	if ($global:wmiConnections -and $global:wmiConnections[$computerName].ComputerRoles.Count) {
		$newNodeScript = {
	param(
		$ComputerName = '.'
	)

	Add-AdminConsoleServerRoleContainerNodes $ComputerName
}
	} else {
		$newNodeScript = {
	param(
		$ComputerName = '.'
	)

	Add-AdminConsoleRemoteComputerContainerNodes $ComputerName
}
	}
	
	Add-AdminConsoleDynamicScriptNode -ParentNode $selectedNode -Name $newNodeName -Script $newNodeScript -ScriptParameters @($ComputerName) -IconTypeIdentifier 'ManagedComputer'
}

function global:Add-AdminConsoleServerRoleContainerNodes {
	param(
		$ComputerName = '.'
	)

	if ($global:wmiConnections) {

		$selectedNode = $host.PrivateData.ConsoleHostFactory.Application.Navigation.CurrentItem

		# Add a node for each of the roles

		foreach ($item in $global:wmiConnections[$computerName].ComputerRoles) {
			if ($function = Get-Item -Path "function:Add-AdminConsole$($item -replace '[^a-z]','')RoleNodes" -ErrorAction SilentlyContinue) {
				Add-AdminConsoleDynamicScriptNode -ParentNode $selectedNode -Name "$item Manager" -Script "$($function.Name) -ComputerName '$ComputerName'" -IconTypeIdentifier "$($item -replace '[^a-z]','')Manager"
			}
		}

		# Then add the nodes for Server Management

		Add-AdminConsoleRemoteComputerContainerNodes $ComputerName

		$selectedNode.Expand()
	}
}

function global:Add-AdminConsoleRemoteComputerContainerNodes {
	param(
		$computerName = '.'
	)

	# Add the Process node to the tree

	Add-AdminConsoleProcessNode $computerName

	# Add the Services node to the tree

	Add-AdminConsoleServicesNode $computerName

	# Add the Event Log node to the tree

	Add-AdminConsoleEventLogNode $computerName

	# Add the Registry node to the tree

	Add-AdminConsoleRegistryNode $computerName

	# Add the Drives node to the tree

	Add-AdminConsoleRemoteDriveNode $computerName

	# Add the Shares node to the tree

	Add-AdminConsoleSharesNode $computerName

	# Add the Local Users and Groups node to the tree

	Add-AdminConsoleLocalUsersAndGroupsNode $computerName

	# Add the WMI browser node to the tree

	Add-AdminConsoleWMIBrowserNode $computerName
}

function global:Add-AdminConsoleProcessNode {
	param(
		$computerName = '.'
	)

	$selectedNode = $host.PrivateData.ConsoleHostFactory.Application.Navigation.CurrentItem

	Add-AdminConsoleDynamicScriptNode -ParentNode $selectedNode -Name 'Processes' -Script "Get-WmiObject -Namespace root\cimv2 -Class Win32_Process -ComputerName '$computerName'" -IconTypeIdentifier 'System.Management.ManagementObject#root\cimv2\Win32_Process'
}

function global:Add-AdminConsoleServicesNode {
	param(
		$computerName = '.'
	)

	$selectedNode = $host.PrivateData.ConsoleHostFactory.Application.Navigation.CurrentItem

	Add-AdminConsoleDynamicScriptNode -ParentNode $selectedNode -Name 'Services' -Script "Get-WmiObject -Namespace root\cimv2 -Class Win32_Service -ComputerName '$computerName'" -IconTypeIdentifier 'System.Management.ManagementObject#root\cimv2\Win32_Service'
}

function global:Add-AdminConsoleEventLogNode {
	param(
		$computerName = '.'
	)

	$selectedNode = $host.PrivateData.ConsoleHostFactory.Application.Navigation.CurrentItem

	Add-AdminConsoleDynamicScriptNode -ParentNode $selectedNode -Name 'Event Logs' -Script "Add-AdminConsoleEventLogFileNode '$computerName'" -IconTypeIdentifier 'System.Management.ManagementObject#root\cimv2\Win32_NTEventlogFile'
}

function global:Add-AdminConsoleEventLogFileNode {
	param(
		$computerName = '.'
	)

	$selectedNode = $host.PrivateData.ConsoleHostFactory.Application.Navigation.CurrentItem

	Get-WmiObject -Namespace root\cimv2 -Class Win32_NTEventLogFile -ComputerName $computerName | ForEach-Object {
		Add-AdminConsoleDynamicScriptNode -ParentNode $selectedNode -Name $_.LogfileName -Script "Get-WmiObject -Namespace root\cimv2 -Class Win32_NTLogEvent -Filter 'Logfile=`"$($_.LogfileName)`"' -ComputerName '$computerName'"
		$_
	}
}

function global:Add-AdminConsoleRegistryNode {
	param(
		$computerName = '.'
	)

	$selectedNode = $host.PrivateData.ConsoleHostFactory.Application.Navigation.CurrentItem

	if ($computerName -eq '.') {
		$computerName = [System.Environment]::MachineName
	}

	$childNodeScript = @"
Add-AdminConsoleRemoteRegistryHiveNode '$computerName' 'CurrentUser' 'HKEY_CURRENT_USER'
Add-AdminConsoleRemoteRegistryHiveNode '$computerName' 'LocalMachine' 'HKEY_LOCAL_MACHINE'
"@

	Add-AdminConsoleDynamicScriptNode -ParentNode $selectedNode -Name 'Registry' -Script $childNodeScript -IconTypeIdentifier 'RegistryNode_8F5B3BF3-B43C-40ef-AFEC-030994089E03'
}

function global:Add-AdminConsoleRemoteRegistryHiveNode {
	param(
		$computerName = '.',
		$registryHive,
		$registryHiveNickname
	)

	$selectedNode = $host.PrivateData.ConsoleHostFactory.Application.Navigation.CurrentItem

	$registryKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($registryHive, $computerName)
	if ($registryKey) {
		$registryKey.PSObject.TypeNames[0] = "$($registryKey.PSObject.TypeNames[0])#Remote"
		Add-AdminConsoleDynamicScriptNode -ParentNode $selectedNode -Name $registryHiveNickname -Script "Add-AdminConsoleRemoteRegistrySubkeyNode '$computerName' '$registryHive'" -IconTypeIdentifier $registryKey
		$registryKey `
			| Add-Member -Force -Name Computer -MemberType NoteProperty -Value $computerName -PassThru `
			| Add-Member -Force -Name Hive -MemberType NoteProperty -Value $registryHive -PassThru `
			| Add-Member -Force -Name Path -MemberType NoteProperty -Value $null -PassThru
	}
}

function global:Add-AdminConsoleRemoteRegistrySubkeyNode {
	param(
		$computerName = '.',
		$registryHive,
		$registrySubkeyPath = ''
	)

	$selectedNode = $host.PrivateData.ConsoleHostFactory.Application.Navigation.CurrentItem

	$registryKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($registryHive, $computerName)
	if ($registryKey) {
		$registryKey = $registryKey.OpenSubKey($registrySubkeyPath, $false)
	}
	if ($registryKey) {
		foreach ($subKeyName in $registryKey.GetSubKeyNames()) {
			trap {
				continue
			}
			$registrySubKey = $registryKey.OpenSubKey($subKeyName, $false)
			$registrySubKeyChildName = $null
			if (-not $registrySubkeyPath) {
				$registrySubKeyChildName = $subKeyName
			} else {
				$registrySubKeyChildName = Join-Path -Path $registrySubkeyPath -ChildPath $subKeyName
			}
			
			$registrySubKey.PSObject.TypeNames[0] = "$($registrySubKey.PSObject.TypeNames[0])#Remote"
			Add-AdminConsoleDynamicScriptNode -ParentNode $selectedNode -Name $subKeyName -Script "Add-AdminConsoleRemoteRegistrySubkeyNode '$computerName' '$registryHive' '$registrySubKeyChildName'" -IconTypeIdentifier $registrySubKey
			$registrySubKey `
				| Add-Member -Force -Name Name -MemberType NoteProperty -Value $subkeyName -PassThru `
				| Add-Member -Force -Name Computer -MemberType NoteProperty -Value $computerName -PassThru `
				| Add-Member -Force -Name Hive -MemberType NoteProperty -Value $registryHive -PassThru `
				| Add-Member -Force -Name Path -MemberType NoteProperty -Value $registrySubkeyPath -PassThru
		}
	}
}

function global:Add-AdminConsoleRemoteDriveNode {
	param(
		$computerName = '.'
	)

	$selectedNode = $host.PrivateData.ConsoleHostFactory.Application.Navigation.CurrentItem

	if ($computerName -eq '.') {
		$computerName = [System.Environment]::MachineName
	}

	$childNodeScript = @"
Add-AdminConsoleRemoteFileSystemNode '$computerName'
Add-AdminConsoleRegistryNode '$computerName'
"@

	Add-AdminConsoleDynamicScriptNode -ParentNode $selectedNode -Name 'Drives' -Script $childNodeScript -IconTypeIdentifier 'DrivesNode_B59748CC-4A26-4789-B790-E653D3702E8D'
}

function global:Add-AdminConsoleRemoteFileSystemNode {
	param(
		$computerName = '.'
	)

	$selectedNode = $host.PrivateData.ConsoleHostFactory.Application.Navigation.CurrentItem

	Add-AdminConsoleDynamicScriptNode -ParentNode $selectedNode -Name 'FileSystem' -Script "Add-AdminConsoleRemoteFileSystemDriveNode '$computerName'"
}

function global:Add-AdminConsoleRemoteFileSystemDriveNode {
	param(
		$computerName = '.'
	)

	$selectedNode = $host.PrivateData.ConsoleHostFactory.Application.Navigation.CurrentItem

	Get-WmiObject -Namespace root\cimv2 -Class Win32_LogicalDisk -ComputerName $computerName | ForEach-Object {
		$driveLetter = $_.DeviceID.Replace(':','')
		Add-AdminConsoleDynamicScriptNode -ParentNode $selectedNode -Name $driveLetter -Script "Get-ChildItem -LiteralPath $(`"\\$computerName\$driveLetter`$`") -Force -ErrorAction SilentlyContinue | ForEach-Object { Add-AdminConsoleProviderItemNode `$_ $(`"\\$computerName\$driveLetter`$`") }" -IconTypeIdentifier $_
		$_
	}
}

function global:Add-AdminConsoleProviderItemNode {
	param(
		$Item,
		[string]$ParentPath
	)

	$selectedNode = $host.PrivateData.ConsoleHostFactory.Application.Navigation.CurrentItem;

	$newNodeScript = {
	param(
		$Path
	)

	Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue | ForEach-Object {
		Add-AdminConsoleProviderItemNode $_ $Path
	}
}

	if ($Item.PSIsContainer) {
		Add-AdminConsoleDynamicScriptNode -ParentNode $selectedNode -Name $Item.PSChildName -Script $newNodeScript -ScriptParameters @((Join-Path -Path $ParentPath -ChildPath $Item.PSChildName)) -IconTypeIdentifier $Item
	}
	$Item
}

function global:Add-AdminConsoleSharesNode {
	param(
		$ComputerName = '.'
	)

	$selectedNode = $host.PrivateData.ConsoleHostFactory.Application.Navigation.CurrentItem

	Add-AdminConsoleDynamicScriptNode -ParentNode $selectedNode -Name 'Shares' -Script "Add-AdminConsoleShareNode '$ComputerName'" -IconTypeIdentifier 'System.Management.ManagementObject#root\cimv2\Win32_Share'
}

function global:Add-AdminConsoleShareNode {
	param(
		$ComputerName  = '.'
	)
	
	$selectedNode = $host.PrivateData.ConsoleHostFactory.Application.Navigation.CurrentItem

	$newNodeScript = {
	param(
		$ComputerName = '.',
		$ShareName
	)

	Get-ChildItem -LiteralPath "\\$ComputerName\$ShareName" -Force -ErrorAction SilentlyContinue | ForEach-Object {
		Add-AdminConsoleProviderItemNode $_ "\\$ComputerName\$ShareName"
	}
}

	Get-WmiObject -Namespace root\cimv2 -Class Win32_Share -ComputerName $computerName | ForEach-Object {
		Add-AdminConsoleDynamicScriptNode -ParentNode $selectedNode -Name $_.Name -Script $newNodeScript -ScriptParameters @($_.__SERVER,$_.Name) -IconTypeIdentifier $_
		$_
	}
}

function global:Add-AdminConsoleLocalUsersAndGroupsNode {
	param(
		$computerName  = '.'
	)

	$selectedNode = $host.PrivateData.ConsoleHostFactory.Application.Navigation.CurrentItem

	$childNodeScript = @"
Add-AdminConsoleLocalUsersNode '$computerName'
Add-AdminConsoleLocalGroupsNode '$computerName'
"@

	Add-AdminConsoleDynamicScriptNode -ParentNode $selectedNode -Name 'Local Users and Groups' -Script $childNodeScript -IconTypeIdentifier 'LocalUsersAndGroupsNode_CAA51B11-63C2-4c57-BF4A-1E8993A2B0C9'
}

function global:Add-AdminConsoleLocalUsersNode {
	param(
		$computerName  = '.'
	)

	$selectedNode = $host.PrivateData.ConsoleHostFactory.Application.Navigation.CurrentItem

	Add-AdminConsoleDynamicScriptNode -ParentNode $selectedNode -Name 'Users' -Script "Get-LocalUser -ComputerName '$computerName'" -IconTypeIdentifier 'LocalUsersNode_94935352-09F6-4E7E-85B1-027C20C5049D'
}

function global:Add-AdminConsoleLocalGroupsNode {
	param(
		$computerName = '.'
	)

	$selectedNode = $host.PrivateData.ConsoleHostFactory.Application.Navigation.CurrentItem

	Add-AdminConsoleDynamicScriptNode -ParentNode $selectedNode -Name 'Groups' -Script "Get-LocalGroup -ComputerName '$computerName'" -IconTypeIdentifier 'LocalGroupsNode_0B51B357-0465-49C8-8BF0-89CD2BFA602E'
}

function global:Add-AdminConsoleWMIBrowserNode {
	param(
		$computerName = '.'
	)

	$selectedNode = $host.PrivateData.ConsoleHostFactory.Application.Navigation.CurrentItem

	$childNodeScript = {
	param(
		$computerName = '.'
	)

	# Get the root namespace

	$rootNamespace = Get-WmiRoot -ComputerName $computerName

	# Get the default namespace name

	$defaultNamespace = 'root\cimv2'
	if (($wmiRegistryProvider = Get-WmiClass -Namespace root\default -Class StdRegProv -ComputerName $computerName) -and ($value = $wmiRegistryProvider.GetExpandedStringValue(2147483650,'SOFTWARE\Microsoft\WBEM\Scripting','Default Namespace').sValue)) {
		$defaultNamespace = $value
	}

	# Add the root namespace node to the tree

	Add-AdminConsoleWMINamespaceNode $computerName $rootNamespace $defaultNamespace
}

	Add-AdminConsoleDynamicScriptNode -ParentNode $selectedNode -Name 'WMI Browser' -Script $childNodeScript -ScriptParameters @($ComputerName) -IconTypeIdentifier 'WMIBrowserNode_FB5027E1-F147-40e1-B951-CF5C8AC21F2B'
}

function global:Add-AdminConsoleWMINamespaceNode {
	param(
		$computerName = '.',
		$namespace,
		$defaultNamespace
	)

	$selectedNode = $host.PrivateData.ConsoleHostFactory.Application.Navigation.CurrentItem

	# Set the script for the child node

	$childNodeScript = {
	param(
		$computerName = '.',
		$namespacePath,
		$defaultNamespace
	)

	# Retrieve the child namespaces of the namespace identified by $namespacePath and add them to the tree

	Get-WmiObject -Namespace $namespacePath.ToLower() -Class __NAMESPACE -ComputerName $computerName `
		| Sort-Object -Property __NAMESPACE,Name `
		| ForEach-Object {
			if (($_.PSObject.TypeNames -notcontains 'System.Management.ManagementObject#__NAMESPACE') -and ($_.PSObject.TypeNames.Count -gt 1)) {
				$_.PSObject.TypeNames.Insert(1,'System.Management.ManagementObject#__NAMESPACE')
			}
			Add-AdminConsoleWMINamespaceNode $computerName $_ $defaultNamespace
		}

	# Retrieve the available WMI classes in the namespace identified by $namespacePath and output them to the data grid

	Get-WmiObject -Namespace $namespacePath.ToLower() -List -ComputerName $computerName `
		| Sort-Object -Property __NAMESPACE,Name `
		| Add-Member -Force -Name Type -MemberType ScriptProperty -Value {if ($this.__GENUS -eq 1) {'Class'} elseif ($this.__GENUS -eq 2 ) {'Namespace'}} -PassThru `
		| Add-Member -Force -Name PropertyCount -MemberType ScriptProperty -Value {$this.__PROPERTY_COUNT} -PassThru `
		| Add-Member -Force -Name Server -MemberType ScriptProperty -Value {$this.__SERVER} -PassThru `
		| Add-Member -Force -Name Namespace -MemberType ScriptProperty -Value {$this.__NAMESPACE} -PassThru `
		| Add-Member -Force -Name Path -MemberType ScriptProperty -Value {$this.__PATH} -PassThru `
		| Select-Object -Property Name,Type,PropertyCount,Server,Namespace,Path `
		| ForEach-Object {
			$_.PSObject.TypeNames.Clear()
			$_.PSObject.TypeNames.Insert(0,'System.Management.ManagementObject')
			$_.PSObject.TypeNames.Insert(0,'System.Management.ManagementObject#Class')
			$_
		}
}

	# Build the name for the child node and the current namespace path

	$namespacePath = $namespace.Name
	if ($namespace.Name -ne $namespace.__NAMESPACE) {
		$namespacePath = "$($namespace.__NAMESPACE)\$($namespace.Name)"
	}
	$childNodeName = $namespace.Name
	if ($namespacePath -eq $defaultNamespace) {
		$childNodeName += ' (default)'
	}

	Add-AdminConsoleDynamicScriptNode -ParentNode $selectedNode -Name $childNodeName -Script $childNodeScript -ScriptParameters @($ComputerName,$namespacePath,$DefaultNamespace) -IconTypeIdentifier 'System.Management.ManagementObject#__NAMESPACE'
}

#endregion