@echo off
title Clash Exit Switch
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0toggle-proxy.ps1" %*
