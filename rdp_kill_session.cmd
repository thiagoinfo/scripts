@echo off
FOR /F %%H IN (%1) DO (call :kill_rdp_session %%H)
goto :end

:kill_rdp_session
SET SERVER=%1
echo Connecting to: %SERVER%

FOR /L %%N IN (2,1,8) DO logoff %%N /server:%SERVER% /v

goto :eof

:end

