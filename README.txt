=============
Introduction
=============
CheckCSR is an internal tool designed to quickly parse CSRs for known issues or errors that stand out. The tool is build around 4 troubleshooting KBs on workflows that typically requires the CSRs be checked. This tool is supplementary to troubleshooting and support agents will still be required to confirm any issues found with supporting logs.

The 4 primary troubleshooting KBs used:
SolutionID: 022226318283523 - Troubleshooting Why A Study Will Not Open
SolutionID: 022226911434521 - Troubleshooting Disk Import
SolutionID: 221019131513817 - Troubleshooting CD/Disk Export
SolutionID: 220131165305857 - Troubleshooting Slowness Opening Studies In Radiology PACS


==============================
CheckCSR Tool Help/Usage Page
==============================

Description: Pull and parse information in a CSR

Usage: CheckCSR -c <CSR> [-e <Option>] [-l <LogPicker>] [-s <StudyID>] [-p/-d/-h]

Options:
[required] -c CSR file
[Optional] -e Error check; see notes below
[Optional] -l LogPicker directory; see notes below
[Optional] -s Search logs and perform checks for a specific StudyID
[Optional] -p Used with -s, recursively search RUIDs for prior studies
[Optional] -d Used with -s and -e Slowness; Search all RUIDs
[Optional] -h Output this help page

[-l] Specifying LogPicker directory can provide additional log search functions 
     based on the search or inputed error check option. See error check notes 
     below for recommended logs pulled for each error check option.

[-e] Error check can take additional option for additional functions.
     Accepted options listed below with logpicker files and notes:
     DiskImport - HmiWebService*, DiskImportChildSrv*
     DiskExport - HmiWebService*, DiskExport*, ConvAgnt*
     Slowness   - WebApi*, AliWebBEx*, WebServer*
     Study      - Used with -s, Runs CheckStudy, CheckIndex, and checks for common errors

Note:
Use > to redirect tool output
WID must not contain _
For best results, ensure CSR captures client initialization logs
Detailed (-d) and Prior (-p) search may cause tool to run for too long


==========
Functions
==========
-                Pulls workstation specs from aliHRS initialization
-                Pulls workstation configs from WID across all site files
-                Checks if auto-registration is enabled and auto-reg times
-                Check for all studies opened in AliHRS, sorted by anchor and priors
-                Checked Memory Load from AliHRS
(-l)             Search server-side logs when applicable; WebApi, DiskExport, etc
(-e slowness)    Checks performance data; open study speeds and times for all studies
(-e slowness)    Search for all FileFragments over 1s
(-e slowness -l) Match RUIDs between CSR and Server logs
(-e slowness -d) Search for all FileFragments
(-s)             Check for prior studies opened in AliHRS
(-s)             Checks performance data; open study speeds and times
(-s)             Search for all FileFragments over 1s for this study
(-s -d)          Search for all FileFragments for this study
(-s -e study)    Runs checkstudy and checkindex
(-s -e study)    Checks for open studies errors in KB022226318283523
(-e diskimport)  Checks for known DiskImport issues in KB022226911434521
(-e diskexport)  Checks for known DiskExport issues in KB221019131513817


=================
Script Breakdown
=================

- Pulls info to match standard tool output formats with current time, user and host running the tool
	Uses hostname, whoami, and now

- Read switches used in the CLI Input
	Recursive if value=switch checks, then skips to next value
	Unrecognized switch/values are skipped
	Tool proceeds when there's no more value

- if StudyID is specified, checks if StudyID is valid
	Uses DBDumpTDS (dbs -s) and checks for "Modality"
	Since tool uses DBDumpTDS, if another CLI is using it, it'll fail

- Checks and stages CSR path
	If the CSR filename provided ends with ".zip";
		deletes and recreates "C:\Temp\CheckCSR-temp" to ensure no issues
		set variable to clean up extracted files after script completes
		use PowerShell Expand-Archive to extract CSR into "C:\Temp\CheckCSR-temp"
			if PowerShell Expand-Archive; go to end of file to trigger cleanup
		pushd into "C:\Temp\CheckCSR-temp\Logs\C_\ChangeHealthcareApps\logs"
		Pulls WID from AliHRS or from the CSR's name
	If the CSR filename does no end with ".zip";
		pushd into "<CSR>\Logs\C_\ChangeHealthcareApps\logs"
		Pulls WID from AliHRS or from the CSR's name

- Dumps information inputted and pulled
	StudyID, Modality type, CSR path, Logpicker path, WID

- Dump workstation specs and configs
	Specs pulled from AliHRS initialization logs
	Pulls client version, Windows version, RAM installed
	Searches WID through all site files
	Specifically checks if LOG_PERFORMANCE_DATA and AutoRegistration is enabled

- Pull misc information; 
	Checks Physical Memory Load and auto-reg times from in AliHRS
	Search for studies opened
		If StudyID provided, will search for prior studies opened
		If StudyID not provided, will pull all anchor and prior studies opened
	skipped with -e diskimport/diskexport information is not relevant

- Error Checks (-e)
	diskimport:
		Dumps all configurations in DiskRW.site
		checks for errors in KB022226911434521
		notes some scenarios cannot be checked or requires -l

	diskexport:
		Dumps all configurations in DiskRW.site
		checks for errors in KB221019131513817
		notes some scenarios cannot be checked or requires -l

	study:
		Uses CheckStudy and CheckIndex
		Checks for errors in KB022226318283523
		Checks for common study issues from various KBs
			Uses view_tag_for_bag
		Check study open times
		If -p, recursively check study open times on all priors

	slowness:
		Pulls first image times for all studies
		Pulls all FileFragments over 1 second
		If -l, Match each RUID to Web logs
		If -d, pulls all FileFragments
		If -s, only check StudyID
		If -p, recursive search through all priors

- Cleanup
	If CSR was extracted through this script, delete "C:\Temp\CheckCSR-temp"


==============================
Commands called in the script
==============================
hostname
whoami
now
findstr
grep
egrep
gawk
DBDumpTDS
checkstudy
checkindex
view_tag_for_bag
rmdir /S /Q
mkdir
powershell expand-archive
