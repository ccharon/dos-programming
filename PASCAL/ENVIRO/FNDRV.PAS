{ this program is used to find the drive with the specified label }
{ it takes a label as a parameter and searches all drives for the label }
{ if the label is found, it is stored as an environment variable }
Program EnumerateDrives;

Uses
    Enviro,
    Dos;

Type
    { Record to store volume information for int 21h, ah=44h, al=0Dh call}
    VolumeInfo = Record
        InfoLevel: Word;
        SerialNumber: LongInt;
        VolumeLabel: Array[1..11] of Char;
    End;

Const
    ENV_FNDRV = 'FNDRV';


{ Trim leading and trailing spaces from a string }
Function Trim(Str: String): String;
Var
    I, StartPos, EndPos: Integer;
Begin
    StartPos := 1;
    EndPos := Length(Str);

    While (StartPos <= EndPos) and (Str[StartPos] = ' ') Do
        Inc(StartPos);

    While (EndPos >= StartPos) and (Str[EndPos] = ' ') Do
        Dec(EndPos);

    Trim := Copy(Str, StartPos, EndPos - StartPos + 1);
End;


{ Get the label of a drive, using int 21h, ah=44h, al=0Dh call }
Function GetDriveLabel(Drive: Char): String;
Var
    Regs: Registers;
    VolInfo: VolumeInfo;
    TempLabel: String;
    I: Integer;

Begin
    FillChar(VolInfo, SizeOf(VolInfo), #0);  
    TempLabel := '';

    Regs.AH := $44; { IOCTL }
    Regs.AL := $0D; { Generic IOCTL for block devices }
    
    Regs.BX := Ord(Drive) - Ord('A') + 1; { Drive selection }
    
    Regs.CH := $08; { Main code always $08 }
    Regs.CL := $66; { Get media ID }

    { DS:DX points to the record to store the volume information }
    Regs.DS := Seg(VolInfo);
    Regs.DX := Ofs(VolInfo);
    
    Intr($21, Regs);

    If (Regs.Flags and FCarry) = 0 Then
    Begin
        For I := 1 To 11 Do
        Begin
            If VolInfo.VolumeLabel[I] = #0 Then
                Break;
            TempLabel := TempLabel + VolInfo.VolumeLabel[I];
        End;
        GetDriveLabel := Trim(TempLabel);
    End
    Else
    Begin
        GetDriveLabel := '@NO@LABEL!#';
    End;
End;


{ Check if a drive label is valid }
Function IsValidLabel(LabelStr: String): Boolean;
Var
    I: Integer;
Begin
    IsValidLabel := False;

    
    If (Length(LabelStr) >= 1) and (Length(LabelStr) <= 11) Then
    Begin
        For I := 1 To Length(LabelStr) Do
        Begin
            If Not (LabelStr[I] In ['A'..'Z', '0'..'9', '_', '-', '$', '#', '@', '!']) Then
                Exit;
        End;
        IsValidLabel := True; 
    End;
End;


{ Set the FNDRV environment variable }
Function SetFNDRVEnv(Drive: Char): Boolean;
Begin
    SetFNDRVEnv := False;

    If FindEnv Then
        if SetEnv(ENV_FNDRV, Drive + ':') Then
            SetFNDRVEnv := True;
End;


{ Validate the command line parameters }
Function ValidateParameters: Boolean;
Var
    Param1: String;

Begin
    ValidateParameters := False;
    
    If ParamCount <> 2 Then Exit;

    Param1 := ParamStr(1);
    If Length(Param1) <> 2 Then Exit;
    If (Param1[1] <> '/') or (UpCase(Param1[2]) <> 'L') Then Exit;
    
    If Not IsValidLabel(ParamStr(2)) Then Exit;

    ValidateParameters := True;
End;


{ Set the current drive, using int 21h, ah=0Eh call }
Procedure SetDrive(Drive: Char);
Var
  Regs: Registers;

Begin
  Regs.AX := $0E00;
  Regs.DL := Ord(Drive) - Ord('A');
  Intr($21, Regs);
End;


{ Get the current drive, using int 21h, ah=19h call }
Function GetCurrentDrive: Char;
Var
  Regs: Registers;

Begin
  Regs.AX := $1900;
  Intr($21, Regs);
  GetCurrentDrive := Chr(Regs.AL + Ord('A'));
End;


{ Main program }
Var
    SavedDrive: Char;
    Drive: Char;
    SearchLabel: String;

Begin
    if Not ValidateParameters Then
    Begin
        WriteLn('Find Drive by Label. Writes the first drive letter with the specified label');
        WriteLn('to the FNDRV environment variable. Which then can be used by other programs.');
        WriteLn;
        WriteLn('FNDRV /L LABEL');
        WriteLn;
        WriteLn(' /L LABEL The label to search for.');
        WriteLn;
        WriteLn('A drive label must be 1 to 11 characters long, and can');
        WriteLn('only contain A-Z, a-z, 0-9, and the characters _ - $ # @ !');
        WriteLn;
        WriteLn('Example Use in a batch file:');
        WriteLn;
        WriteLn('@echo off');
        WriteLn('FNDRV /L MYLABEL');
        WriteLn('echo FNDRV is set to %FNDRV%');
        WriteLn;
        Halt(1);
    End;

    SearchLabel := ParamStr(2);

    { Get the current drive, to restore on exit }
    SavedDrive := GetCurrentDrive;

    { Enumerate all drives, looking for the specified label }
    For Drive := 'A' To 'Z' Do
    Begin
        SetDrive(Drive);
        If GetCurrentDrive = Drive Then
        Begin
            If GetDriveLabel(Drive) = SearchLabel Then
            Begin
                WriteLn('Found label ', SearchLabel, ', setting ', ENV_FNDRV, '=', Drive, ':');
                
                If Not SetFNDRVEnv(Drive) Then
                    WriteLn('Error setting environment variable FNDRV');
                
                SetDrive(SavedDrive);
                Halt(0);
            End;
        End;
    End;

    SetDrive(SavedDrive);
    WriteLn('Label ', SearchLabel, ' not found. ', ENV_FNDRV, ' not set.');
    Halt(0);
End.