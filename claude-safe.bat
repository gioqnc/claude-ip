@echo off
title Claude Safe Launcher
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0claude-safe.ps1" %*
