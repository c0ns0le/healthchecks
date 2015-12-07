# gmsTeivaModule-Storage.psm1
# 
# This module contains a collection of functions and modules targetting VMware Infrastructures
# Note: This script calls the overall Module called gmsTeivaModules.psm1 (where it is located)
#


#function InitialiseModule()
#{
	# Put in there what needs to load for each Storage script.. Unlikely to find modules that are common the various modules..but just in case.
#}

# gbValue should be something like 1 GB (which is 1000 MB NOT 1024)
function convertGBtoGiB($gbValue)
{

}

# tbValue should be something like 1 GB (which is 1000 MB NOT 1024)
function convertGiBtoGB($gbValue)
{

}

# The SVC needs date formats to be yyMMdd hhmmss
# So I need to be able to create dates dynamically for the svc storage arrays
function formatDateNeededBySVC([string] $date)
{
	return "$(Get-Date $date -Format yyMMddHHmmss)"
}

