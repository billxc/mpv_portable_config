@echo off
setlocal enableextensions enabledelayedexpansion
path %SystemRoot%\System32;%SystemRoot%;%SystemRoot%\System32\Wbem

:: Unattended install flag. When set, the script will not require user input.
set unattended=no
if "%1"=="/u" set unattended=yes

:: Make sure this is Windows Vista or later
call :ensure_vista

:: Make sure the script is running as admin
call :ensure_admin

:: Command line arguments to use when launching mpv from a file association
set mpv_args=

:: Get mpv.exe location
set mpv_path=%~dp0mpv.exe
if not exist "%mpv_path%" call :die "mpv.exe not found"

:: Get mpv-document.ico location
set icon_path=%~dp0mpv-document.ico
if not exist "%icon_path%" call :die "mpv-document.ico not found"

:: Register mpv.exe under the "App Paths" key, so it can be found by
:: ShellExecute, the run command, the start menu, etc.
call :reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\mpv.exe" /d "%mpv_path%" /f
call :reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\mpv.exe" /v "UseUrl" /t REG_DWORD /d 1 /f

:: Register mpv.exe under the "Applications" key to add some default verbs for
:: when mpv is used from the "Open with" menu
call :reg add "HKLM\SOFTWARE\Classes\Applications\mpv.exe" /v "FriendlyAppName" /d "MPV Player" /f
call :add_verbs "HKLM\SOFTWARE\Classes\Applications\mpv.exe"

:: Add mpv to the "Open with" list for all video and audio file types
call :reg add "HKLM\SOFTWARE\Classes\SystemFileAssociations\video\OpenWithList\mpv.exe" /d "" /f
call :reg add "HKLM\SOFTWARE\Classes\SystemFileAssociations\audio\OpenWithList\mpv.exe" /d "" /f

:: Add a capabilities key for mpv, which is registered later on for use in the
:: "Default Programs" control panel
set capabilities_key=HKLM\SOFTWARE\Clients\Media\mpv\Capabilities
call :reg add "HKLM\SOFTWARE\Clients\Media\mpv\Capabilities" /v "ApplicationName" /d "mpv" /f
call :reg add "HKLM\SOFTWARE\Clients\Media\mpv\Capabilities" /v "ApplicationDescription" /d "MPV Player" /f


call :add_type "video/x-matroska"                 "video" "Matroska Video"             ".mkv"
call :add_type "video/mp4"                        "video" "MPEG-4 Video"               ".mpeg4" ".m4v" ".mp4" ".mp4v" ".mpg4"
call :add_type "video/avi"                        "video" "Video Clip"                 ".avi" ".vfw"
call :add_type "video/x-ms-wmv"                   "video" "Windows Media Video"        ".wmv"

@REM :: Register "Default Programs" entry
call :reg add "HKLM\SOFTWARE\RegisteredApplications" /v "mpv" /d "SOFTWARE\Clients\Media\mpv\Capabilities" /f

echo.
echo Installed successfully^^! You can now configure mpv's file associations in the
echo Default Programs control panel.
echo.
if [%unattended%] == [yes] exit 0
<nul set /p =Press any key to open the Default Programs control panel . . .
pause >nul
control /name Microsoft.DefaultPrograms
exit 0

:die
	if not [%1] == [] echo %~1
	if [%unattended%] == [yes] exit 1
	pause
	exit 1

:ensure_admin
	:: 'openfiles' is just a commmand that is present on all supported Windows
	:: versions, requires admin privileges and has no side effects, see:
	:: https://stackoverflow.com/questions/4051883/batch-script-how-to-check-for-admin-rights
	openfiles >nul 2>&1
	if errorlevel 1 (
		echo This batch script requires administrator privileges. Right-click on
		echo mpv-install.bat and select "Run as administrator".
		call :die
	)
	goto :EOF

:ensure_vista
	ver | find "XP" >nul
	if not errorlevel 1 (
		echo This batch script only works on Windows Vista and later. To create file
		echo associations on Windows XP, right click on a video file and use "Open with...".
		call :die
	)
	goto :EOF

:reg
	:: Wrap the reg command to check for errors
	>nul reg %*
	if errorlevel 1 set error=yes
	if [%error%] == [yes] echo Error in command: reg %*
	if [%error%] == [yes] call :die
	goto :EOF

:reg_set_opt
	:: Set a value in the registry if it doesn't already exist
	set key=%~1
	set value=%~2
	set data=%~3

	reg query "%key%" /v "%value%" >nul 2>&1
	if errorlevel 1 call :reg add "%key%" /v "%value%" /d "%data%"
	goto :EOF

:add_verbs
	set key=%~1

	@REM echo Set the default verb to "play"
	@REM call :reg add "%key%\shell" /d "play" /f

	@REM echo Hide the "open" verb from the context menu, since it's the same as "play"
	@REM call :reg add "%key%\shell\open" /v "LegacyDisable" /f

	echo Set open command
	call :reg add "%key%\shell\open\command" /d "\"%mpv_path%\" %mpv_args% -- \"%%%%L" /f

	@REM echo Add "play" verb
	@REM call :reg add "%key%\shell\play" /d "&Play" /f
	@REM call :reg add "%key%\shell\play\command" /d "\"%mpv_path%\" %mpv_args% -- \"%%%%L" /f

	goto :EOF

:add_progid
	set prog_id=%~1
	set friendly_name=%~2

	:: Add ProgId, edit flags are FTA_OpenIsSafe | FTA_AlwaysUseDirectInvoke
	set prog_id_key=HKLM\SOFTWARE\Classes\%prog_id%
	call :reg add "HKLM\SOFTWARE\Classes\%prog_id%" /d "%friendly_name%" /f
	call :reg add "HKLM\SOFTWARE\Classes\%prog_id%" /v "EditFlags" /t REG_DWORD /d 4259840 /f
	call :reg add "HKLM\SOFTWARE\Classes\%prog_id%" /v "FriendlyTypeName" /d "%friendly_name%" /f
	call :reg add "HKLM\SOFTWARE\Classes\%prog_id%\DefaultIcon" /d "%icon_path%" /f
	call :add_verbs "HKLM\SOFTWARE\Classes\%prog_id%"

	goto :EOF

:update_extension
	set extension=%~1
	set prog_id=%~2
	set mime_type=%~3
	set perceived_type=%~4

	:: Add information about the file extension, if not already present
	if not [%mime_type%] == [] call :reg_set_opt "HKLM\SOFTWARE\Classes\%extension%" "Content Type" "%mime_type%"
	if not [%perceived_type%] == [] call :reg_set_opt "HKLM\SOFTWARE\Classes\%extension%" "PerceivedType" "%perceived_type%"
	call :reg add "HKLM\SOFTWARE\Classes\%extension%\OpenWithProgIds" /v "%prog_id%" /f

	:: Add type to SupportedTypes
	call :reg add "HKLM\SOFTWARE\Classes\Applications\mpv.exe\SupportedTypes" /v "%extension%" /f

	:: Add type to the Default Programs control panel
	call :reg add "HKLM\SOFTWARE\Clients\Media\mpv\Capabilities\FileAssociations" /v "%extension%" /d "%prog_id%" /f

	goto :EOF

:add_type
	set mime_type=%~1
	set perceived_type=%~2
	set friendly_name=%~3
	set extension=%~4

	echo Adding "%extension%" file type

	:: Add ProgId
	set prog_id=io.mpv%extension%
	call :add_progid "%prog_id%" "%friendly_name%"

	:: Add extensions
	:extension_loop
		call :update_extension "%extension%" "%prog_id%" "%mime_type%" "%perceived_type%"

		:: Trailing parameters are additional extensions
		shift /4
		set extension=%~4
		if not [%extension%] == [] goto extension_loop

	goto :EOF
