# Create / Read / Update / Delete MSDOS Env Variables

The Unit and Test compile and work under Turbo Pascal 7.0 for MSDOS.

Using ENVIRO.PAS as a Unit in your own programs allows you to directly manipulate your Environment. I wanted to have this to create backups containing a date in their filename or folder.

example: (see TEST.BAT)

```
@echo off
GENDATE.EXE
echo %DATEYMD%
```
no need to write a set statement into a batch file and call it.

it was tested on a real 386 MSDOS 6.22 machine and on 86Box. it works with command.com as command interpreter. 4dos does not work.

it does not work on dosbox(-x) (but it might if you would use a real msdos installation)
