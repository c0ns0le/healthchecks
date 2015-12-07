[Instructions to get started]

0) Edit and adapt .\Customer_Settings\default.ini for the installation

1) Open up a VMware vSphere PowerCLI console (or a normal PowerShell Gui but you need to load the VMware Snapin)

2) Navigate to the installation directory where this file is located (for example: C:\admin\scripts ..etc..)

3) Generate the required credentials for vCenter, SAN, etc...
For examples in the customer INI file you modified in step 1, 
you may find this line "vcCredentialsFile=.\Customer_Settings\myuser-securestring-vc.txt". 
You need to store the encrypted password for vCenter in that file. To generate the credentials run this command.

read-host -assecurestring -prompt "Enter password" | convertfrom-securestring | Out-file ".\myuser-securestring-vc.txt"


, then you could keep the resultant file with the ini file file but you don't have too. If you choose to move it elsewhere, be sure to 
specify the exact full path to the password file in the ini config file (for Example: vcCredentialsFile=C:\myuser-securestring-vc.txt)

Repeat this process for other credentials files needed for this script

4) start collecting using

.\documentCustomer.ps1 -iniFile .\Customer_Settings\customer.ini

5) Navigate to the output directory you specified in the init file 
for example: "outputDirectory=C:\admin\scripts\healthchecks"

the reports will be in HTML format
the raw data will be in CSV files.

[What works and What DOESN'T]
- vmware scripts work. Although there are many powershell scripts in the vmware folder, not all are needed or used by documentCustomer.ps1
- IBM V7000/5000/3000 work and are called from documentCUstomer.ps1
- IBM TSM scripts work, but not called from documentCustomer.ps1

Teiva


-----------------------------------------------
Issues & Features to implement
- Split generic from VMware specific functions from vmwareModules.psm1
- Fix up spelling and gramar mistakes