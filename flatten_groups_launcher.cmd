@echo off
REM ������ ���������� ����� Active Directory ��� identity (����������� �� ASA �� ��. ������)
REM �������������� ���� �����, ��������� � CSV-����� groups.txt ��������� �������: �������� ������������� �� �������� ������ � ���� ��������� � ��� ����� � ������� ������� ������. 
REM �������������, �� �������� � �������� ������ � ��������� ���������, ������� �� ������� ������.
REM
REM ������� �.�. 2014
REM
REM �������� Powershell-������ flatten_groups.ps1
REM
REM ��� ������������: 
REM   ��� ������ ���� �����, ������� ���� �������������, �������� � ���������������� ���� c:\scripts\groups.txt ������ ����:
REM   source_group,target_group
REM

SET SCRIPT=C:\scripts\flatten_groups.ps1
SET LOG=c:\scripts\flatten_groups_log.txt
SET CONFIG=c:\scripts\groups.txt

ECHO. >> %LOG% 2>&1
ECHO Started: %DATE% %TIME% >> %LOG% 2>&1
%SystemRoot%\system32\windowspowershell\v1.0\powershell.exe -command "&{%SCRIPT% %CONFIG% -verbose}" >> %LOG% 2>&1
ECHO Finished: %DATE% %TIME% >> %LOG% 2>&1