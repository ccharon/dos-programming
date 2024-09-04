# Create / Read / Update / Delete MSDOS Env Variables

using ENVIRO.PAS as a Unit allows you to directly manipulate your Environment. I wanted to have this to create backups containing a date in their filename.

exanple:

```
@echo off
GENDATE.EXE
echo %DATEYMD%
```
no need to write a set statement into a batch file and call it
