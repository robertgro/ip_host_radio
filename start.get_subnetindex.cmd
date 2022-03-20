@echo off
::DEBUG
powershell -ExecutionPolicy Unrestricted -File get_subnetindex.ps1 -maxrange 10
::PROD
::powershell -ExecutionPolicy Unrestricted -File get_subnetindex.ps1