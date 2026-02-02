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
Echo:#         program:  CheckCSR                                                        #
Echo:#                                                                                   #
Echo:#         purpose:  Tool to quickly pull info from a CSR                            #
Echo:#                                                                                   #
Echo:#         version:  1.0.1 (.02Feb26.AndrewD)                                        #
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
	if /I "%~2"=="Study" (
		SET "StudyCheck=1"
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

REM -s must be used with -e study

if defined StudyCheck (
    if not defined StudyID (
		Echo.
		Echo StudyID must be specified for -e Study check
		GOTO :eof
	    )
	)

REM Checks if DBDumpTDS can find StudyID

if defined StudyID (
	Echo Validating StudyID...
	FOR /F "tokens=2" %%I in ('dbs -s "!StudyID!" ^| grep Modality') DO (
		SET "foundmatch=1"
		SET "modality=%%I"
		)
	If not defined foundmatch (
		Echo.
		Echo StudyID Not Found or DBDumpTDS is Occupied
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

FOR /F "tokens=10" %%A in ('findstr /SC:"Workstation name:" AliHRS* 2^>nul') do (
	SET "WID=%%A"
	)
	
if not defined WID (
	For %%A IN ("!CSR!") DO (SET "CSRName=%%~nxA")
	For /F "tokens=1 delims=_" %%X IN ("!CSRName!") DO (SET "WID=%%X")
	)

if defined StudyID (
    Echo StudyID:  !StudyID!
	)
if defined modality (
	Echo Modality: !modality!
	)
Echo CSR:      !CSRPath!
If defined LogPicker (
    Echo Web Logs: !LogPicker!
    )
Echo WID:      !WID!

REM Dump worksation specs and configs

Echo.
Echo: ------ Workstation Specs ------
Echo.

FOR /F "tokens=2,9*" %%I IN ('findstr /SC:"Starting McKesson Radiology Station" StatRep\AliHRS*.log* 2^>nul') DO (
    SET "foundmatch=1"
    Echo:Version: %%J %%K
	FOR /F "tokens=1,2,3,4 delims=:," %%W IN ("%%I") DO (SET "CSRStart=%%W%%X%%Y%%Z")
    )
	
If not defined foundmatch (
	FOR /F "tokens=2,9*" %%I IN ('findstr /SC:"Starting McKesson Radiology Station" Staging\AliHRS*.log* 2^>nul') DO (
		SET "foundmatch=1"
		Echo:Version: %%J %%K
		FOR /F "tokens=1,2,3,4 delims=:," %%W IN ("%%I") DO (SET "CSRStart=%%W%%X%%Y%%Z")
		)
	) else (SET "foundmatch=")

FOR /F %%F IN ('dir /b /s StatRep ^| grep -i alihrs') DO (
    FOR /F "tokens=2,8*" %%A in ('grep -i -A 4 "Loading McKesson Radiology Station HAL" "%%F" ^| grep -v HAL 2^>nul') do (
        SET "foundmatch=1"
        echo %%B %%C
		FOR /F "tokens=1,2,3,4 delims=:," %%W IN ("%%A") DO (SET "CSRStart=%%W%%X%%Y%%Z")
        )
    )
	
If not defined foundmatch (
	FOR /F %%F IN ('dir /b /s ^| grep -i alihrs') DO (
		FOR /F "tokens=2,8*" %%A in ('grep -i -A 4 "Loading McKesson Radiology Station HAL" "%%F" ^| grep -v HAL 2^>nul') do (
			SET "foundmatch=1"
			echo %%B %%C
			FOR /F "tokens=1,2,3,4 delims=:," %%W IN ("%%A") DO (SET "CSRStart=%%W%%X%%Y%%Z")
			)
		)
	)

If not defined foundmatch (
    echo Workstation Specs not Found
    ) else (SET "foundmatch=")

Echo.
Echo: ------ Workstation Configurations ------
Echo.

FOR /F "tokens=5* delims=\" %%I IN ('findstr "!WID!" "%ALI_SITE_CONFIG_PATH%\*.site" 2^>nul') DO (
    SET "foundmatch=1"
    Echo %%I %%J
    )

If not defined foundmatch (
    echo No Workstation Specific Configurations Found
    ) else (SET "foundmatch=")

FOR /F "tokens=5* delims=\" %%I IN ('findstr "LOG_PERFORMANCE_DATA" "%ALI_SITE_CONFIG_PATH%\emviewer.site" 2^>nul') DO (
    Echo %%I %%J
    )

findstr /SIC:"AutoRegistration enabled = True" AliHRS*.log* >nul
    if not errorlevel 1 (
    echo Auto-Registration is Enabled
    SET "AutoReg=1"
    )

REM Error check option for Disk Import and Export
	
if defined DiskImportCheck (
	Goto :CheckDiskImport
	)

if defined DiskExportCheck (
	goto :CheckDiskExport
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

	FOR /F "tokens=17" %%A IN (
	'findstr /SC:"FINISHED CREATING STUDY CONTEXT for Patient" AliHRS*.log* 2^>nul') DO (
		Echo Anchor Study: %%A
		)

	For /F "tokens=11" %%A in ('findstr /SC:"OpenStudiesInContext - Study" AliHRS*.log* 2^>nul') DO (
		ECHO Prior Study: %%A
		)
	)

REM Study Checks
	
if defined StudyID (
	Call :opentimes
	if defined StudyCheck (
		Echo.
		Echo: ------ CheckStudy for StudyID !StudyID! ------
		Echo.
		For /F "delims=" %%G in ('checkstudy -s !StudyID! ^| grep -A 50 "Status:"') DO (
			Echo %%G
			SET "foundmatch=1"
			)
		If not defined foundmatch (
			Echo CheckStudy on !StudyID! failed, please run this manually
			) else (
				SET "foundmatch="
				)
		Echo.
		Echo ------ CheckIndex for StudyID !StudyID! ------
		Echo.

		For /F "delims=" %%F in ('checkindex -s !StudyID! ^| grep -A 50 "Bag Summary:"') DO (
			Echo %%F
			SET "foundmatch=1"
			)
		For /F "delims=" %%F in ('checkindex -s !StudyID! ^| grep -A 50 "Critical Errors:"') DO (
			Echo %%F
			SET "foundmatch=1"
			)
		If not defined foundmatch (
			Echo CheckIndex on !StudyID! failed, please run this manually
			) else (
				SET "foundmatch="
				)
		Call :GeneralStudyCheck
		)

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
							)
						)
					)
				)
		)
	)

REM Performance Check on Opened Studies

if defined SlownessCheck (
	Call :ExcessiveTimes
	FOR /F "tokens=17" %%A IN (
	'findstr /SC:"FINISHED CREATING STUDY CONTEXT for Patient" AliHRS*.log* 2^>nul') DO (
		SET "StudyID=%%A"
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
Echo.
Echo This tool is supplementary to troubleshooting. Confirm all issues with supporting logs!
GOTO :eof

REM ------ FUNCTIONS ------

:opentimes

Echo.
Echo: ------ Open Study Times for StudyID !StudyID! ------
echo.

FOR /F "tokens=2,8*" %%A IN ('findstr /SIC:"Openstudies" AliHRS*.log* ^| grep !StudyID! 2^>nul') DO (
    SET "foundmatch=1"
    Echo %%A %%B %%C
    FOR /F "tokens=1,2,3,4 delims=:," %%W IN ("%%A") DO (SET "StudyStartTime=%%W%%X%%Y%%Z")
    )

FOR /F "tokens=2,8*" %%I IN ('findstr /SC:"load the first image for" AliHRS*.log* ^| grep !StudyID! 2^>nul') DO (
    SET "foundmatch=1"
    Echo %%I %%J %%K
    )

FOR /F "tokens=2,8*" %%I IN ('findstr /SC:"display first image for" AliHRS*.log* ^| grep !StudyID! 2^>nul') DO (
    SET "foundmatch=1"
    Echo %%I %%J %%K
    )

FOR /F "tokens=2,8*" %%A IN ('findstr /SC:"Fire loading" AliHRS*.log* ^| grep !StudyID! 2^>nul') DO (
    SET "foundmatch=1"
	SET "string=%%A %%B %%C"
    FOR /F "tokens=1,2,3,4 delims=:," %%W IN ("%%A") DO (SET "StudyEndTime=%%W%%X%%Y%%Z")
    )
if defined string (
	Echo !string!
	SET "string="
	)

FOR /F "tokens=2,8*" %%A IN ('grep -i "Performance data (Part 1) for study ID = !StudyID!" StatRep/* 2^>nul') DO (
    SET "foundmatch=1"
	SET "string=%%A %%B %%C"
	SET "LastMatch=%%A"
    )
if defined string (
	Echo !string!
	SET "string="
	)

FOR /F "tokens=2*" %%A IN ('grep -i -A 6 "!LastMatch!" StatRep/* ^| grep -A 6 "Performance data (Part 1) for study ID = !StudyID!"  ^| grep -v "Performance" 2^>nul') DO (
    SET "foundmatch=1"
    Echo %%A %%B
    )

if exist Staging/HRS (
	FOR /F "tokens=2,8*" %%A IN ('grep -i "Performance data (Part 1) for study ID = !StudyID!" Staging/HRS/* 2^>nul') DO (
		SET "foundmatch=1"
		SET "string=%%A %%B %%C"
		SET "LastMatch=%%A"
		)
	if defined string (
		Echo !string!
		SET "string="
		)

	FOR /F "tokens=2*" %%A IN ('grep -i -A 6 "!LastMatch!" StatRep/* ^| grep -A 6 "Performance data (Part 1) for study ID = !StudyID!" Staging/HRS/* ^| grep -v "Performance" 2^>nul') DO (
		SET "foundmatch=1"
		Echo %%A %%B
		)
	)

SET "LastMatch="

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
	)

SET "foundmatch="
SET "foundexcess="
SET "StudyStartTime="
SET "StudyEndTime="
exit /b

:ExcessiveTimes

Echo.
Echo: ------ Excessive Times ------
Echo.
if defined LogPicker (
	if defined CSRStart (
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
			Echo.
			) else (SET "excess=")
		)
	)

for /f "tokens=2,8,9,11,12,13,14,15,16,17,18,19,*" %%A in ('findstr /SI "filefragment" AliHRS*.log* ^| egrep "[1-9]\.[0-9]* seconds" 2^>nul') do (
	Echo AliHRS: %%A %%B %%C %%D %%E %%F %%G %%H %%I %%J %%K %%L
	SET "foundexcess=1"
	If defined LogPicker (
		SET "RUID=%%C"
		call :RUIDWebApi
		Echo.
		) else (Echo.)
	)
If not defined foundexcess (
	echo No Excessive RUID Delays Found
	Echo.
	) else (SET "foundexcess=")

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

:GeneralStudyCheck

Echo.
Echo: ------ Checking Common Study Errors ------
Echo.
FOR /F "delims=" %%I IN ('findstr /SIC:"Overall impression object is NULL" AliHRS* 2^>nul') DO (
	Echo Found Bad CAD Files
	Echo %%I
	Echo See KB211119174313903
	SET "founderror=1"
	Echo.
	)
	
FOR /F "delims=" %%I IN ('findstr /SIC:"[IP] Error: Fail to retrieve the viewport output rectangle Source" AliHRS* 2^>nul') DO (
	Echo Found Life-Size Calibration Mismatch
	Echo %%I
	Echo See KB210816154942807
	SET "founderror=1"
	Echo.
	)


FOR /F "delims=" %%I IN ('findstr /SIC:"code: 500, description: Status text in HTTP headers: Internal Server Error" AliDXVSal* 2^>nul') DO (
	Echo Found Error While Creating Patient Context
	Echo %%I
	Echo See KB210723104644350
	SET "founderror=1"
	Echo.
	)

FOR /F "delims=" %%I IN ('findstr /SIC:"[IP] Error: Mismatch between pixel data size" AliHRS* 2^>nul') DO (
	Echo Found Pixel Data Mismatch
	Echo %%I
	Echo See KB220930102759250
	SET "founderror=1"
	Echo.
	)
	
FOR /F "delims=" %%I IN ('findstr /SIC:"[IP] Error: 48bit RGB images not supported" AliHRS* 2^>nul') DO (
	Echo Found Unsupported 48-bit Image
	Echo %%I
	Echo See KB220930102759250
	SET "founderror=1"
	Echo.
	)
	
FOR /F "delims=" %%I IN ('findstr /SIC:"[IP] Error: Fail to generate the output image Source" AliHRS* 2^>nul') DO (
	Echo Found Pixel Data Mismatch
	Echo %%I
	Echo See KB220930102759250
	SET "founderror=1"
	Echo.
	)
	
FOR /F "delims=" %%I IN ('findstr /SIC:"Failed to normailze pixel data" AliHRS* 2^>nul') DO (
	Echo Found Pixel Data Mismatch
	Echo %%I
	Echo See KB220930102759250
	SET "founderror=1"
	Echo.
	)

FOR /F "tokens=2" %%I in ('dbs -s "!StudyID!" ^| grep BagID:') DO (
	FOR /F "tokens=1,2,5* delims=" %%A in ('view_tag_for_bag -t 0008,0068 -b %%I ^| grep -i processing 2^>nul') DO (
		Echo Found "FOR PROCESSING" Images
		Echo %%A %%B %%C %%D
		Echo See KB210719153436890
		SET "founderror=1"
		Echo.
		)
	)

if not defined founderror (
	Echo Did not find any common errors, please search logs manually for issues
	) else (SET "founderror=")
	
exit /b

:CheckDiskImport

Echo.
Echo ------ Disk Import Check ------
Echo.
Echo:DiskRW.site Configs:
FOR /F "tokens=* delims=" %%I IN ('findstr /V /B /C:"#" "%ALI_SITE_CONFIG_PATH%\DiskRW.site" 2^>nul') DO (
	Echo %%I
	)
Echo.
Echo --- Checking for errors in KB022226911434521 ---
Echo Scenario 4B, and 5 requires LogPicker, Scenario 1, 2B, and 6 cannot be checked
Echo.

FOR /F "tokens=13" %%F in ('findstr /SIC:"Trying to create virtual DICOMDIR for path" MediaInspector* 2^>nul') DO (
	SET "PathCheck=%%F"
	if "!PathCheck:~127,1!" neq "" (
		Echo File Path is 128 characters or greater; File Path Too Long
		Echo !PathCheck!
		Echo See KB220217115504897 or KB022226911434521:Scenario 2A
		SET "founderror=1"
		Echo.
		)
	)

FOR /F "delims=" %%I IN ('findstr /SIC:"unsupported SOP" HmiWebApps* 2^>nul') DO (
	Echo Found Unsupported SOP Class
	Echo %%I
	Echo See KB210729145051080, KB230525104020800, or KB022226911434521:Scenario 3A
	SET "founderror=1"
	Echo.
	)
	
FOR /F "delims=" %%A IN ('findstr /SIC:"Transfer Syntax not found" MediaInspector* 2^>nul') DO (
	Echo Found Missing Transfer Syntax
	Echo %%A
	Echo See KB022226911434521:Scenario 3B
	SET "founderror=1"
	Echo.
	)
	
FOR /F "tokens=1,2,10,11,12,13,14,15,16" %%A IN ('findstr /SIC:"unsupported Transfer Syntax" HmiWebApps* 2^>nul') DO (
	Echo Found Unsupported Transfer Syntax
	Echo %%A %%B - %%C %%D %%E %%F %%G %%H %%I
	Echo See KB210720144545237 or KB022226911434521:Scenario 3C
	SET "founderror=1"
	Echo.
	)

FOR /F "delims=" %%X IN ('findstr /SIC:"Data error (cyclic redundancy check)" HmiWebApps* 2^>nul') DO (
	Echo Found possible data corruption on disk
	Echo %%X
	Echo See KB022226911434521:Scenario 3D
	SET "founderror=1"
	Echo.
	)
	
FOR /F "delims=" %%G IN ('findstr /SIC:"AddPatient - Unknown error" HmiWebApps* 2^>nul') DO (
	Echo Found Unknown Error regarding AddPatient
	Echo %%G
	Echo See KB022226911434521:Scenario 3E
	SET "founderror=1"
	Echo.
	)

FOR /F "delims=" %%B IN ('findstr /SIC:"The network name cannot be found" HmiWebApps* 2^>nul') DO (
	Echo Network Name Cannot be Found
	Echo %%B
	Echo See KB022226911434521:Scenario 4A
	SET "founderror=1"
	Echo.
	)

FOR /F "delims=" %%C IN ('findstr /SIC:"is not allowed (allowed extensions:" HmiWebApps* 2^>nul') DO (
	Echo Found Unsupported File Extension
	Echo %%C
	Echo See KB022226911434521:Scenario 4C
	SET "founderror=1"
	Echo.
	)

if defined LogPicker (
	FOR /F "delims=" %%K IN ('findstr /SIC:"The maximum message size quota for incoming messages" HmiWebService* ^| grep -i "has been exceeded" 2^>nul') DO (
		Echo Data Imported is too large, limit is 2GB
		Echo %%K
		Echo See KB210924174140653 or KB022226911434521:Scenario 4B
		SET "founderror=1"
		Echo.
		)

	FOR /F "delims=" %%T IN ('findstr /SIC:"Failed to initialize association" DiskImportChild* 2^>nul') DO (
		Echo Found Unknown Error regarding AddPatient
		Echo %%T
		Echo See KB250526134630553, KB210722162452767, or KB022226911434521:Scenario 5
		SET "founderror=1"
		Echo.
		)
	)
	
if not defined founderror (
	Echo Did not find any errors, please search logs manually for issues
	) else (SET "founderror=")

Echo.
Echo This tool is used to quickly search for known issues. Confirm any issues found with supporting logs!
goto :eof

:CheckDiskExport

Echo.
Echo ------ Disk Export Check ------
Echo.
Echo:DiskRW.site Configs:
FOR /F "tokens=* delims=" %%I IN ('findstr /V /B /C:"#" "%ALI_SITE_CONFIG_PATH%\DiskRW.site" 2^>nul') DO (
	Echo %%I
	)
Echo.
Echo --- Checking for errors in KB221019131513817 ---
Echo. Scenario 1 and 6 requires LogPicker, Scenario 3 cannot be checked
Echo.

FOR /F "delims=" %%I IN ('findstr /SIC:"The current media is not supported" DiskBurnerService* 2^>nul') DO (
	Echo Current Media is Not Supported
	Echo %%I
	Echo See KB221019131513817:Scenario 2
	SET "founderror=1"
	Echo.
	)
	
FOR /F "delims=" %%A IN ('findstr /SIC:"fails to return true to IsReady query so returning false." HmiWebApps* ^| grep "Media.IsPresent()" 2^>nul') DO (
	Echo Current Media is Not Supported
	Echo %%A
	Echo See KB221019131513817:Scenario 2
	SET "founderror=1"
	Echo.
	)
	
FOR /F "delims=" %%D IN ('findstr /SIC:"ExportStudiesOnServer() failed, return code = 505," HmiWebApps* 2^>nul') DO (
	Echo Study Sequencing Preventing Export
	Echo %%D
	Echo See KB221019131513817:Scenario 4
	SET "founderror=1"
	Echo.
	)

FOR /F "delims=" %%B IN ('findstr /SIC:"call to UpdateAdvancedViewer() returned Failed" HmiWebApps* 2^>nul') DO (
	Echo Found Issues with Advanced Viewer files
	Echo %%B
	Echo See KB022226911434521:Scenario 5
	SET "founderror=1"
	Echo.
	)
	
FOR /F "delims=" %%Y IN ('findstr /SIC:"CheckCreateNewDirectory() failed for ClientAdvancedViewerDirectory" HmiWebApps* 2^>nul') DO (
	Echo Found Issues with Advanced Viewer files
	Echo %%Y
	Echo See KB022226911434521:Scenario 5
	SET "founderror=1"
	Echo.
	)
	
FOR /F "delims=" %%Z IN ('findstr /SIC:"caught exception = Some or all identity references could not be translated" HmiWebApps* 2^>nul') DO (
	Echo Found Issues with Advanced Viewer files
	Echo %%Z
	Echo See KB022226911434521:Scenario 5
	SET "founderror=1"
	Echo.
	)

FOR /F "delims=" %%B IN ('findstr /SIC:"_exportController.ExportStudiesOnServer() failed, return code = 708," HmiWebApps* 2^>nul') DO (
	Echo Found Not Enough Space on Selected Media
	Echo %%B
	Echo See KB022226911434521:Scenario 6
	SET "founderror=1"
	Echo.
	)
	
FOR /F "delims=" %%B IN ('findstr /SIC:"Could not get HRS-D access COM error" HmiWebApps* 2^>nul') DO (
	Echo Found Invalid Path
	Echo %%B
	Echo See KB210721122002000
	SET "founderror=1"
	Echo.
	)
	
FOR /F "delims=" %%B IN ('findstr /SIC:"Exception = An error occurred while receiving the HTTP response" HmiWebApps* 2^>nul') DO (
	Echo Found HTTP Response Error
	Echo %%B
	Echo See CASE1218900, CASE1131647, and ACTN02925526
	SET "founderror=1"
	Echo.
	)
	
FOR /F "delims=" %%B IN ('findstr /SIC:"Memory is locked" HmiWebApps* 2^>nul') DO (
	Echo Found Invalid Path
	Echo %%B
	Echo See KB210721122002000
	SET "founderror=1"
	Echo.
	)

if defined LogPicker (
	FOR /F "delims=" %%K IN ('findstr /SIC:"unable to find context PK" DiskExport* 2^>nul') DO (
		Echo Failed to Retrieve Study Information
		Echo %%K
		Echo See KB221019131513817:Scenario 1
		SET "founderror=1"
		Echo.
		)

	FOR /F "delims=" %%K IN ('findstr /SIC:"Not enough space on selected media" DiskExport* 2^>nul') DO (
		Echo Found Not Enough Space on Selected Media
		Echo %%K
		Echo See KB221019131513817:Scenario 6
		SET "founderror=1"
		Echo.
		)

	FOR /F "delims=" %%K IN ('findstr /SIC:"The network path was not found" HmiWebService* 2^>nul') DO (
		Echo Found Invalid Path
		Echo %%K
		Echo See KB210721122002000
		SET "founderror=1"
		Echo.
		)

	FOR /F "delims=" %%K IN ('findstr /SIC:"Failed to create directory" DiskExport* 2^>nul') DO (
		Echo Found Invalid Path
		Echo %%K
		Echo See KB210721122002000
		SET "founderror=1"
		Echo.
		)
	
	FOR /F "delims=" %%K IN ('findstr /SIC:"Failed to export advanced viewer metadata on media" DiskExport* 2^>nul') DO (
		Echo Couldn't Open SAL Study
		Echo %%K
		Echo See KB220706114417100
		SET "founderror=1"
		Echo.
		)

	FOR /F "delims=" %%K IN ('findstr /SIC:"Failed to export advanced viewer metadata" DiskExport* 2^>nul') DO (
		Echo Couldn't Open SAL Study
		Echo %%K
		Echo See KB220706114417100
		SET "founderror=1"
		Echo.
		)
	
	FOR /F "delims=" %%K IN ('findstr /SIC:"Call to Backend Pacs SAL OpenStudy method failed" ConvAgnt* 2^>nul') DO (
		Echo Couldn't Open SAL Study
		Echo %%K
		Echo See KB220706114417100
		SET "founderror=1"
		Echo.
		)

	FOR /F "delims=" %%K IN ('findstr /SIC:"Failed to save Metadata" ConvAgnt* 2^>nul') DO (
		Echo Couldn't Open SAL Study
		Echo %%K
		Echo See KB220706114417100
		SET "founderror=1"
		Echo.
		)
	
	FOR /F "delims=" %%K IN ('findstr /SIC:"Unable to connect to the study server at this time" DiskExport* 2^>nul') DO (
		Echo Failed to retrieve study info 
		Echo %%K
		Echo See KB210726172723650
		SET "founderror=1"
		Echo.
		)
	)

FOR /F "delims=" %%A IN ('findstr /SIC:"ExportStudiesOnServer() failed" HmiWebApps* 2^>nul') DO (
	Echo Found Generic Error
	Echo %%A
	SET "founderror=1"
	Echo.
	)
	
if not defined founderror (
	Echo Did not find any matches for known issues
	Echo.
	)

Echo This tool is used to quickly search for known issues. Confirm any issues found with supporting logs!
goto :eof

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
Echo: [Optional] -d Used with -s and -e Slowness; Search all RUIDs
Echo: [Optional] -h Output this help page
Echo:
Echo: [-l] Specifying LogPicker directory can provide additional log search functions 
Echo:      based on the search or inputed error check option. See error check notes 
Echo:      below for recommended logs pulled for each error check option.
Echo:
Echo: [-e] Error check can take additional option for additional functions.
Echo:      Accepted options listed below with notes and required logpicker files:
Echo:      DiskImport - HmiWebService*, DiskImportChildSrv*
Echo:      DiskExport - HmiWebService*, DiskExport*, ConvAgnt*
Echo:      Slowness   - WebApi*, AliWebBEx*, WebServer*
Echo:      Study      - Used with -s, Runs CheckStudy, CheckIndex, and checks for common errors
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
