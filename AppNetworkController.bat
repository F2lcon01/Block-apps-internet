@echo off
:: App Network Controller v2.5 - Double-click to run
cd /d "%~dp0"
powershell -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Start-Process powershell -ArgumentList '-NoProfile','-STA','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File','%~dp0AppNetworkController.ps1' -Verb RunAs"
exit
