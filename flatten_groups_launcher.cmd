@echo off
REM Скрипт подготовки групп Active Directory для identity (авторизация на ASA по уч. записи)
REM Синхронизирует пары групп, указанные в CSV-файле groups.txt следующим образом: копирует пользователей из исходной группы и всех вложенных в нее групп в целевую плоскую группу. 
REM Пользователей, не входящих в исходную группу и вложенные подгруппы, удаляет из целевой группы.
REM
REM Маринин М.В. 2014
REM
REM Вызывает Powershell-скрипт flatten_groups.ps1
REM
REM Как использовать: 
REM   для каждой пары групп, которые надо реплицировать, добавить в конфигурационный файл c:\scripts\groups.txt строку вида:
REM   source_group,target_group
REM

SET SCRIPT=C:\scripts\flatten_groups.ps1
SET LOG=c:\scripts\flatten_groups_log.txt
SET CONFIG=c:\scripts\groups.txt

ECHO. >> %LOG% 2>&1
ECHO Started: %DATE% %TIME% >> %LOG% 2>&1
%SystemRoot%\system32\windowspowershell\v1.0\powershell.exe -command "&{%SCRIPT% %CONFIG% -verbose}" >> %LOG% 2>&1
ECHO Finished: %DATE% %TIME% >> %LOG% 2>&1