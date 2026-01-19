@echo off
setlocal EnableExtensions EnableDelayedExpansion

FOR /F "tokens=*" %%I IN ('hostname') DO (
        SET "hostname=%%I"
        )

FOR /F "tokens=*" %%I IN ('whoami') DO (
        SET "user=%%I"
        )

FOR /F "tokens=*" %%I IN ('now') DO (
        SET "now=%%I"
        )

Echo:#-------------------------------------CheckCSR--------------------------------------#
Echo:#                                                                                   #
Echo:#         program:  CheckCSR		                                                 #
Echo:#                                                                                   #
Echo:#         purpose:  Tool to quickly pull info from a CSR                            #
Echo:#                                                                                   #
Echo:#         version:  0.1.0 (.19Jan26.AndrewD)                                        #
Echo:#                                                                                   #
Echo:#          author:  Andrew Doan                                                     #
Echo:#                                                                                   #
Echo:#-----------------------------------------------------------------------------------#
Echo: Runtime:    !now!
Echo: HostName:   !hostname!
Echo: User:       !user!
Echo:---------------------------------------
Echo.

if "%~1"=="" (
    call :help
	goto :eof
	)

REM Read Input

:parse

if "%~1"=="" goto :main

if /I "%~1"=="-h" (
    call :help
    goto :eof
    )

if /I "%~1"=="-c" (
    SET "CSR=%~2"
    if exist "!CSR!" (
        FOR %%I in ("%~2") do (
            set "CSRPath=%%~fI"
            )
        shift & shift & goto parse
        ) else (
            echo Invalid CSR
            call :help
            goto :eof
            )
    )

if /I "%~1"=="-s" (
    SET "StudyID=%~2"
    shift & shift & goto parse
	)

if /I "%~1"=="-l" (
    SET "LogPicker=%~2"
    if not exist "!LogPicker!" (
		echo Invalid LogPicker Directory
        call :help
        goto :eof
        )
    FOR %%I in ("%~2") do (
        set "LogPicker=%%~fI"
        shift & shift & goto parse
        )
    )

if /I "%~1"=="-p" (
    SET "Priors=1"
    shift
    goto parse
    )

if /I "%~1"=="-d" (
    SET "detailed=1"
    shift
    goto parse
    )
	
if /I "%~1"=="-e" (
	if /I "%~2"=="Slowness" (
		SET "SlownessCheck=1"
        shift & shift & goto parse
		)
	if /I "%~2"=="DiskImport" (
		SET "DiskImportCheck=1"
        shift & shift & goto parse
		)
	if /I "%~2"=="DiskExport" (
		SET "DiskExportCheck=1"
        shift & shift & goto parse
		)
    SET "errorcheck=1"
    shift
    goto parse
    )
	
REM Ignore Unrecognized Arguments

shift
goto parse

:main

REM Checks if DBDumpTDS can find StudyID

if defined StudyID (
	Echo Validating StudyID...
	FOR /F "tokens=2" %%I in ('dbs -s "!StudyID!" ^| grep Modality') DO (
		SET "foundmatch=1"
		SET "modality=%%I"
		)
	If not defined foundmatch (
		echo.
		echo StudyID Not Found or DBDumpTDS is Occupied
		GOTO :eof
		) else (SET "foundmatch=")
    )

REM -e slowness cannot be used with -s, resetting SlownessCheck

if defined SlownessCheck (
    if defined StudyID (
		SET "SlownessCheck="
	    )
	)

REM Verify CSR is not zipped

if /I "%CSR:~-4%"==".zip" (
    Echo CSR not Extracted
    call :help
    goto :eof
    ) else (
        pushd "!CSR!\Logs\C_\ChangeHealthcareApps\logs"
        )

For %%A IN ("!CSR!") DO (SET "CSRName=%%~nxA")
For /F "tokens=1 delims=_" %%X IN ("!CSRName!") DO (SET "WID=%%X")

if defined StudyID (
    Echo StudyID:  !StudyID!
	)
Echo Modality: !modality!
Echo CSR:      !CSRPath!
If defined LogPicker (
    Echo Web Logs: !LogPicker!
    )
Echo WID:      !WID!

REM Dump worksation specs and configs

Echo.
Echo: ------ Workstation Specs ------
Echo.

FOR /F "tokens=2,9*" %%I IN ('findstr /SC:"Starting McKesson Radiology Station" AliHRS*.log* 2^>nul') DO (
    SET "foundmatch=1"
    Echo:Version: %%J %%K
	FOR /F "tokens=1,2,3,4 delims=:," %%W IN ("%%I") DO (SET "CSRStart=%%W%%X%%Y%%Z")
    )

FOR /F %%F IN ('dir /b /s ^| grep -i alihrs') DO (
    FOR /F "tokens=2,8*" %%A in ('grep -i -A 4 "Loading McKesson Radiology Station HAL" "%%F" ^| grep -v HAL 2^>nul') do (
        SET "foundmatch=1"
        echo %%B %%C
		FOR /F "tokens=1,2,3,4 delims=:," %%W IN ("%%A") DO (SET "CSRStart=%%W%%X%%Y%%Z")
        )
    )
	
If not defined foundmatch (
    echo Workstation Specs not Found
    ) else (SET "foundmatch=")

Echo.
Echo: ------ Workstation Configurations ------
Echo.

FOR /F "tokens=2* delims=:" %%I IN ('findstr "!WID!" "%ALI_SITE_CONFIG_PATH%\*.site" 2^>nul') DO (
    SET "foundmatch=1"
    Echo %%I %%J
    )

If not defined foundmatch (
    echo No Workstation Specific Configurations Found
    ) else (SET "foundmatch=")

FOR /F "tokens=2* delims=:" %%I IN ('findstr "LOG_PERFORMANCE_DATA" "%ALI_SITE_CONFIG_PATH%\emviewer.site" 2^>nul') DO (
    Echo %%I %%J
    )

findstr /SIC:"AutoRegistration enabled = True" AliHRS*.log* >nul
    if not errorlevel 1 (
    echo Auto-Registration is Enabled
    SET "AutoReg=1"
    )

REM DiskImport option
	
if defined DiskImportCheck (
	Echo.
	Echo ------ Disk Import Check ------
	Echo.
	Call :DiskRWConfig
	Echo.
	Echo Disk Import Workflow:
REM --------------------------------------------------------------------------------------------------------------
	REM HmiWebApps check - Unsupported SOP, Transfer Syntax, Network Name, extension, and Cyclic Redundancy (AddPatient unknown error)
	REM MediaInspector check - Permissions, Path Length, and Transfer Syntax
	REM AliDXVSal - 

	if defined LogPicker (
		Echo LogPicker Directory specified check

		REM HmiWebService check - 
		REM DiskImportChildSrv - Failed DICOM association
		REM igen_WID - Check import status

		) else (
			Echo LogPicker Directory not specified
			)

	Echo Error: Feature still in development
	goto :eof
	)

REM DiskExport option

if defined DiskExportCheck (
	Echo.
	Echo ------ Disk Export Check ------
	Echo.
	Call :DiskRWConfig
	Echo.
	Echo Disk Export Workflow:
REM --------------------------------------------------------------------------------------------------------------
	REM HmiWebApps check - 
	REM DiskBurnerService - 
	REM AliDXVSal - 

	if defined LogPicker (
		Echo LogPicker Directory specified check
		
		REM HmiWebService check - 
		REM DiskExport - 
		REM ConvAgnt - 		
		
		) else (
			Echo LogPicker Directory not specified
			)

	Echo Error: Feature still in development
	goto :eof
	)
	
REM Checks for memory load logs

Echo.
Echo: ------ Memory Load Check ------
Echo.

FOR /F "tokens=2,14,15,16,17,18*" %%I IN ('findstr /SIC "PhysicalMemoryLoad" AliHRS*.log* 2^>nul') DO (
    SET "foundmatch=1"
    Echo %%I %%J %%N %%O
    )

FOR /F "tokens=2,8*" %%I IN ('findstr /SIC:"stopping loading" AliHRS*.log* 2^>nul') DO (
    SET "foundmatch=1"
    Echo %%I %%J %%K
    )
	
If not defined foundmatch (
    echo Memory Load logs not Found
    ) else (SET "foundmatch=")

REM Dumps AutoRegistration Times

if defined AutoReg (
	Echo.
	Echo: ------ Auto Registration Times ------
	Echo.
	FOR /F "tokens=8*" %%I IN ('findstr /SIC:"ProcessAutoRegistrationRequest: the request is completed in" alihrs*.log* 2^>nul') DO (
		SET "foundmatch=1"
		Echo %%I %%J
		)
	If not defined foundmatch (
		echo No Auto-Registration Times Found
		) else (SET "foundmatch=")
	)

REM Search for Opened Studies

if defined StudyID (

Echo.
Echo: ------ Prior Studies ------
Echo.

FOR /F "tokens=2" %%E in ('Dbs -s !StudyID! ^| grep PatientID') DO (
    FOR /F "tokens=3" %%A IN ('Dbs -p "%%E" ^| grep -w Study ^| grep -v !StudyID!') DO (
        findstr /SC:"OpenStudiesInContext - Study %%A" AliHRS*.log* >nul 2>&1
        if not errorlevel 1 (
            SET "foundpriors=1"
            echo %%A
            )
        )
    )

If not defined foundpriors (
    echo No Prior Studies were Opened for Anchor Study !StudyID!
    )

) else (
	Echo.
	Echo ------ Opened Studies ------
	Echo.

	FOR /F "tokens=16" %%A IN (
	'findstr /SIC "CREATING STUDY CONTEXT for Patient" AliHRS*.log* 2^>nul') DO (
		Echo Anchor Study: %%A
		)

	For /F "tokens=11" %%A in ('findstr /SC:"OpenStudiesInContext - Study" AliHRS*.log* 2^>nul') DO (
		ECHO Prior Study: %%A
		)
	)

REM Search for Large Delays

If defined LogPicker (
    If defined CSRStart (
		If defined SlownessCheck (
			Call :ExcessiveTimes
		) else if defined errorcheck (
			Call :ExcessiveTimes
		)
		)
    )

REM Check for Common Errors

if defined errorcheck (
REM ---------------------------------------------------------------------------------------
	Echo.
	Echo: ------ Common Error Check ------
	Echo.

REM ---------------------------------------------------------------------------------------
if defined StudyID (
	Echo Feature In Development
	)
	Echo Error: Feature In Development
REM ---------------------------------------------------------------------------------------
	)

REM Study Checks
	
if defined StudyID (

Echo.
Echo: ------ CheckStudy for StudyID !StudyID! ------
Echo.

For /F "delims=" %%G in ('checkstudy -s !StudyID! ^| grep -A 50 "Status:"') DO (
    Echo %%G
    )

Echo.
Echo ------ CheckIndex for StudyID !StudyID! ------
Echo.

For /F "delims=" %%F in ('checkindex -s !StudyID! ^| grep -A 50 "Bag Summary:"') DO (
    Echo %%F
    )

REM RUID Search on StudyID

Call :opentimes
Call :FileFragments

REM RUID Search on Priors

if defined Priors (
    If not defined foundpriors (
        echo No Prior Studies were Opened for Anchor Study !StudyID!
        ) else (
            FOR /F "tokens=2" %%E in ('Dbs -s !StudyID! ^| grep PatientID') DO (
                FOR /F "tokens=3" %%A IN ('Dbs -p "%%E" ^| grep -w Study ^| grep -v !StudyID!') DO (
				    findstr /SC:"OpenStudiesInContext - Study %%A" AliHRS*.log* >nul 2>&1
					if not errorlevel 1 (
						SET "StudyID=%%A"
						Call :opentimes
						Call :FileFragments
						)
					)
				)
			)
    )
)

REM Performance Check on Opened Studies

if defined SlownessCheck (
	FOR /F "tokens=16" %%A IN (
	'findstr /SIC "CREATING STUDY CONTEXT for Patient" AliHRS*.log* 2^>nul') DO (
		SET "StudyID=%%A"
		SET "StudyID=!StudyID:~0,-1!"
		SET "StudyStartTime="
		SET "StudyEndTime="
		Call :opentimes
		)
		
	FOR /F "tokens=11" %%A IN (
	'findstr /SC:"OpenStudiesInContext - Study" AliHRS*.log* 2^>nul') DO (
		SET "StudyID=%%A"
		SET "StudyStartTime="
		SET "StudyEndTime="
		Call :opentimes
		)
	)

popd
GOTO :eof

REM ------ FUNCTIONS ------

:opentimes

Echo.
Echo: ------ Open Study Times for StudyID !StudyID! ------
echo.

FOR /F "tokens=2,9*" %%A IN ('findstr /SIC "Openstudies" AliHRS*.log* ^| grep !StudyID! 2^>nul') DO (
    SET "foundmatch=1"
    Echo %%A %%B %%C
    FOR /F "tokens=1,2,3,4 delims=:," %%W IN ("%%A") DO (SET "StudyStartTime=%%W%%X%%Y%%Z")
    )

FOR /F "tokens=2,8*" %%I IN ('findstr /SIC:"load the first image for" AliHRS*.log* ^| grep !StudyID! 2^>nul') DO (
    SET "foundmatch=1"
    Echo %%I %%J %%K
    )

FOR /F "tokens=2,8*" %%I IN ('findstr /SIC:"display first image for" AliHRS*.log* ^| grep !StudyID! 2^>nul') DO (
    SET "foundmatch=1"
    Echo %%I %%J %%K
    )

FOR /F "tokens=2,8*" %%A IN ('findstr /SIC:"fire loading" AliHRS*.log* ^| grep !StudyID! 2^>nul') DO (
    SET "foundmatch=1"
    Echo %%A %%B %%C
    FOR /F "tokens=1,2,3,4 delims=:," %%W IN ("%%A") DO (SET "StudyEndTime=%%W%%X%%Y%%Z")
    )

FOR /F "tokens=2,8*" %%A IN ('grep -i "Performance data (Part 1) for study ID = !StudyID!" StatRep/* 2^>nul') DO (
    SET "foundmatch=1"
    Echo %%A %%B %%C
    )

FOR /F "tokens=2*" %%A IN ('grep -i -A 6 "Performance data (Part 1) for study ID = !StudyID!" StatRep/* ^| grep -v "Performance" 2^>nul') DO (
    SET "foundmatch=1"
    Echo %%A %%B
    )

FOR /F "tokens=2,8*" %%A IN ('grep -i "Performance data (Part 1) for study ID = !StudyID!" Staging/HRS/* 2^>nul') DO (
    SET "foundmatch=1"
    Echo %%A %%B %%C
    )

FOR /F "tokens=2*" %%A IN ('grep -i -A 6 "Performance data (Part 1) for study ID = !StudyID!" Staging/HRS/* ^| grep -v "Performance" 2^>nul') DO (
    SET "foundmatch=1"
    Echo %%A %%B
    )

If not defined foundmatch (
    echo Study times not found
    )
SET "foundmatch="

Echo.
If defined StudyStartTime (
    SET "string=!StudyStartTime:~0,2!:!StudyStartTime:~2,2!:!StudyStartTime:~4,2!,!StudyStartTime:~6,3!"
    Echo Study Opened at !string!
	) else (
	    Echo Start Time not Found
		)

If defined StudyEndTime (
    SET "string=!StudyEndTime:~0,2!:!StudyEndTime:~2,2!:!StudyEndTime:~4,2!,!StudyEndTime:~6,3!"
    Echo Study Finished Loading at !string!
    ) else (
	    Echo End Time not Found
		)

exit /b

:FileFragments

Echo.
Echo ------ File Fragments ------
Echo.

If not defined StudyStartTime (
    Echo Start or End time not set, cannot set timeframe to search RUIDs
	echo.
	exit /b
	)

If not defined StudyEndTime (
    Echo Start or End time not set, cannot set timeframe to search RUIDs
	echo.
	exit /b
	)
	
if defined detailed (
for /f "tokens=2,8,9,11,12,13,14,15,16,17,18,19,*" %%A in ('findstr /SIC "filefragment" AliHRS*.log* 2^>nul') do (
    FOR /F "tokens=1,2,3,4 delims=:," %%W IN ("%%A") DO (SET "logtime=%%W%%X%%Y%%Z")
    if !logtime! geq !StudyStartTime! (
        if !logtime! leq !StudyEndTime! (
            Echo AliHRS: %%A %%B %%C %%D %%E %%F %%G %%H %%I %%J %%K %%L
			SET "foundmatch=1"
            If defined LogPicker (
                SET "RUID=%%C"
                call :RUIDWebApi
                Echo.
                ) else (Echo.)
            )
        )
    )
If not defined foundmatch (
    echo No File Fragments found with search criteria
    )
SET "foundmatch="
) else (
for /f "tokens=2,8,9,11,12,13,14,15,16,17,18,19,*" %%A in ('findstr /SI "filefragment" AliHRS*.log* ^| egrep "[1-9]\.[0-9]* seconds" 2^>nul') do (
    FOR /F "tokens=1,2,3,4 delims=:," %%W IN ("%%A") DO (SET "logtime=%%W%%X%%Y%%Z")
    if !logtime! geq !StudyStartTime! (
        if !logtime! leq !StudyEndTime! (
            Echo AliHRS: %%A %%B %%C %%D %%E %%F %%G %%H %%I %%J %%K %%L
			SET "foundexcess=1"
            If defined LogPicker (
                SET "RUID=%%C"
                call :RUIDWebApi
                Echo.
                ) else (Echo.)
            )
        )
    )
If not defined foundexcess (
    echo No File Fragments found with over 1 second response time
    )
SET "foundexcess="
)

SET "StudyStartTime="
SET "StudyEndTime="
exit /b

:ExcessiveTimes

Echo.
Echo: ------ Excessive Times ------
Echo.
FOR /F "tokens=2,8*" %%I IN ('findstr /SIC:"secs to get response from study server" "!LogPicker!\AliWebBEx*" ^| gawk "{if ($9>1) print}" 2^>nul') DO (
	FOR /F "tokens=1,2,3,4 delims=:," %%W IN ("%%I") DO (SET "logtime=%%W%%X%%Y%%Z")
	if !logtime! geq !CSRStart! (
		SET "excess=1"
		Echo AliWebBex: %%I %%J %%K
		)
	)
Echo.

FOR /F "tokens=2,5,6,7,8,9,13,14,15,16" %%A IN ('findstr /SIC:"REQUEST COMPLETED: GETSTUDYFILELIST" "!LogPicker!\WebServer*" ^| egrep -i "[0-9][0-9][0-9][0-9][0-9][\.]|[0-9][0-9][0-9][0-9][\.]" 2^>nul') DO (
	FOR /F "tokens=1,2,3,4 delims=:," %%W IN ("%%A") DO (SET "logtime=%%W%%X%%Y%%Z")
	if !logtime! geq !CSRStart! (
		SET "excess=1"
		Echo WebServer: %%A %%B %%C %%D %%E %%F %%G %%H %%I %%J
		SET "RUID=%%F"
		Call :RUIDAliWebBEx
		Echo.
		)
	)

If not defined excess (
	echo No Excessive Delays Found
	)
exit /b

:RUIDWebApi

For /F "tokens=2,4*" %%A IN ('findstr /S "!RUID!" "!LogPicker!\WebApi*.log*" 2^>nul') DO (
    Echo WebApi: %%A %%B %%C
    )
exit /b

:RUIDAliWebBEx

For /F "tokens=2,4*" %%A IN ('findstr /S "!RUID!" "!LogPicker!\AliWebBEx*.log*" 2^>nul') DO (
    Echo AliWebBEx: %%A %%B %%C
    )
exit /b

:DiskRWConfig

Echo Applied DiskRW configurations:
FOR /F "tokens=2* delims= :" %%I IN ('findstr /V /B /C:"#" "%ALI_SYS_CONFIG_PATH%\DiskRW.base" 2^>nul') DO (
	findstr /C:"%%I" "%ALI_SITE_CONFIG_PATH%\DiskRW.site" >nul 2>&1
	if errorlevel 1 (
        Echo %%I %%J
    ) else (
		FOR /F "tokens=2*" %%A IN ('findstr /C:"%%I" "%ALI_SITE_CONFIG_PATH%\DiskRW.site" 2^>nul') DO (
			Echo %%A %%B
			)
		)
	)
exit /b

:help

Echo.
Echo: CheckCSR Tool Help Page
Echo.
Echo: Description: Pull and parse information in a CSR
Echo.
Echo "Usage: CheckCSR -c <CSR> [-e <Option>] [-l <LogPicker>] [-s <StudyID>] [-p/-d/-h]"
Echo.
Echo: Options:
Echo: [required] -c Extracted CSR directory
Echo: [Optional] -e Error check; see notes below
Echo: [Optional] -l LogPicker directory; see notes below
Echo: [Optional] -s Search logs and perform checks for a specific StudyID
Echo: [Optional] -p Used with -s, recursively search RUIDs for prior studies
Echo: [Optional] -d Used with -s, search all RUIDs for the study
Echo: [Optional] -h Output this help page
Echo:
Echo: [-l] Specifying LogPicker directory can provide additional log search functions 
Echo:      based on the search or inputed error check option. See error check notes 
Echo:      below for recommended logs pulled for each error check option.
Echo:
Echo: [-e] Error check can take additional option for advanced search options.
Echo:      Accepted options listed below and their logpicker files:
Echo:      DiskImport - HmiWebService*, DiskImportChilSrv*
Echo:      DiskExport - HmiWebService*, DiskExport*, ConvAgnt*
Echo:      Slowness   - WebApi*, AliWebBEx*, WebServer*
Echo.
Echo: Note:
Echo.
Echo: Use ^> to redirect output
Echo: WID must not contain _
Echo: CSR must be the extracted directory
Echo: For best results, ensure CSR captures client initialization logs
Echo: Detailed (-d) and Prior (-p) search can take awhile
Echo:

exit /b

REM ------ UNUSED FUNCTIONS ------

:OpenStudyCall

Echo.
Echo -- Open Study Call --
Echo.
FOR /F "tokens=2,8-19" %%A IN ('findstr /SIC "!StudyID!" alidxvsal*.log* ^| grep GETSTUDYFILELIST 2^>nul') DO (
    SET "foundmatch=1"
    Echo AliDXVSal: %%A %%B %%C : %%E %%F %%G %%H %%I %%J %%K %%L %%M
    if defined LogPicker (
        SET "RUID=%%C"
        Call :RUIDWebServer
        Call :RUIDAliWebBEx
        Echo.
        )
    )
    
If not defined foundmatch (
    echo Open Study Call not found
    )
SET "foundmatch="

exit /b

:RUIDWebServer

For /F "tokens=2,4*" %%A IN ('findstr /S "!RUID!" "!LogPicker!\WebServer*.log*" 2^>nul') DO (
    Echo WebServer: %%A %%B %%C
    )
exit /b