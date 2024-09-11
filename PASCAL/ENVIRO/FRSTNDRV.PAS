{ Search for the first network drive provided by mTCP Netdrive and set the 
  FRSTNDRV environment variable to the drive letter of the network drive.  
  (for example, FRSTNDRV=D:) 

  It uses the DOS IOCTL function to read the control characters of a drive, 
  and checks if the drive is a netdrive. The environment variable FRSTNDRV is 
  set to the drive letter of the netdrive. }
Program FindFirstNetdrive;

Uses
    Enviro, { Unit to handle environment variables }
    Dos;    { Unit to handle DOS calls }

Type
    FarPointer = Record
        Ofs: Word;
        Seg: Word;
    End;

Const
    NETDRIVE_ID   = 'NETDRIVE';
    NETDRIVE_ENV  = 'FRSTNDRV';
    MIN_PRINTABLE = 32;
    MAX_PRINTABLE = 126;


{ Compare the bytes at the pointer with a given string }
Function MemEqualsStr(Ptr: FarPointer; Str: String): Boolean;
Var
    I: Integer;

Begin
    MemEqualsStr := True;
    
    For I := 0 To Length(Str) - 1 Do
    Begin        
        If Mem[Ptr.Seg:Ptr.Ofs + I] <> Ord(Str[I + 1]) Then
        Begin
            MemEqualsStr := False;
            Exit;
        End;
    End;
End;


{ Read control characters from a drive, using int 21h, ah=44h, al=04h call }
Function IsNetdrive(Drive: Char): Boolean;
Var
    Regs: Registers;
    Buffer: Array[0..7] of Byte;
    Ptr: FarPointer;

Begin
    IsNetdrive := False;
    FillChar(Buffer, SizeOf(Buffer), #0); { Clear the buffer }

    Regs.AX := $4404;                     { IOCTL, read control characters }
    Regs.BL := Ord(Drive) - Ord('A') + 1; { drive selection }
    Regs.CX := 8;                         { number of bytes to transfer }
    Regs.DS := Seg(Buffer);               { buffer for control characters }
    Regs.DX := Ofs(Buffer);               { buffer for control characters }
    Intr($21, Regs);

    If (Regs.Flags and FCarry) = 0 Then
    Begin
        { call succeeded, check if AX equals 8 (number of bytes read) }
        If Regs.AX = 8 Then
        Begin
            { The buffer contains 2 Pointers, consisting of 16bit Offset 
              + 16bit Segment. The first pointer is the one that is needed }
            Ptr.Ofs := Buffer[0] + (Buffer[1] shl 8);
            Ptr.Seg := Buffer[2] + (Buffer[3] shl 8);

            { Subtract bytes, M. Brutman put the NETDRIVE_ID string and a 2
              bytes version number in a data structure before the pointer }
            Dec(Ptr.Ofs, Length(NETDRIVE_ID) + 2);

            IsNetdrive := MemEqualsStr(Ptr, NETDRIVE_ID);
        End;
    End;
End;


{ Set the environment variable }
Function SetEnvVar(Drive: Char): Boolean;
Begin
    SetEnvVar := False;

    If FindEnv Then 
        SetEnvVar := SetEnv(NETDRIVE_ENV, Drive + ':');
End;


{ Main routine }
Var
    Drive: Char;

Begin
    For Drive := 'A' To 'Z' Do
    Begin
        If IsNetdrive(Drive) Then
        Begin
            If Not SetEnvVar(Drive) Then
                WriteLn('Error updating ', NETDRIVE_ENV, '=', Drive, ':');
            Halt(0);
        End;
    End;
    WriteLn('Netdrive not found!');
End.