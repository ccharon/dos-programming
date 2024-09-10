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
    TPointer = Record
        Ofs: Word;
        Seg: Word;
    End;


{ Extract a string from memory. If it is a netdrive, it will be 'NETDRIVE' }
Function ExtractNetDrive(Ptr: TPointer): String;
Var
    Data: Byte;
    StrData: String;
    I: Integer;

Begin
    StrData := '';

    { Subtract 10 bytes from the offset, M. Brutman put the string 'NETDRIVE'
      and a 2 bytes version number in a data structure before the pointer }
    Dec(Ptr.Ofs, 10);

    { Read 8 bytes from memory, replace non-printable characters with . }
    For I := 0 To 7 Do
    Begin
        Data := Mem[Ptr.Seg:Ptr.Ofs + I];

        If (Data < 32) or (Data > 126) Then
            Data := Ord('.');

        StrData := StrData + Chr(Data);
    End;
    
    ExtractNetDrive := StrData;
End;


{ Read control characters from a drive, using int 21h, ah=44h, al=04h call }
Function IsNetdrive(Drive: Char): Boolean;
Var
    Regs: Registers;
    Buffer: Array[0..7] of Byte;
    Ptr: TPointer;

Begin
    IsNetdrive := False;
    FillChar(Buffer, SizeOf(Buffer), #0); { Clear the buffer }

    Regs.AX := $4404; { IOCTL, Read control characters }
    Regs.BL := Ord(Drive) - Ord('A') + 1; { Drive selection }
    Regs.CX := 8; { Number of bytes to transfer }
    Regs.DS := Seg(Buffer); { buffer to store the control characters }
    Regs.DX := Ofs(Buffer); { buffer to store the control characters }
    Intr($21, Regs);

    If (Regs.Flags and FCarry) = 0 Then
    Begin
        { Call succeeded, check if AX equals 8 }
        If Regs.AX = 8 Then
        Begin
            { The buffer contains 2 Pointers, consisting of 16bit Offset 
              + 16bit Segment. The first pointer is the one that is needed }
            Ptr.Ofs := Buffer[0] + (Buffer[1] shl 8);
            Ptr.Seg := Buffer[2] + (Buffer[3] shl 8);

            If ExtractNetDrive(Ptr) = 'NETDRIVE' Then
               IsNetdrive := True;
        End;
    End;
End;


{ Set the environment variable }
Function SetEnvVar(Drive: Char): Boolean;
Begin
    SetEnvVar := False;

    If FindEnv Then
        If SetEnv('FRSTNDRV', Drive + ':') Then
            SetEnvVar := True;
End;


Var
    Drive: Char;

Begin
    For Drive := 'A' To 'Z' Do
    Begin
        If IsNetdrive(Drive) then
        Begin
            If Not SetEnvVar(Drive) Then
                WriteLn('Error updating FRSTNDRV=', Drive, ':');
            
            Halt(0);
        End;
    End;
    Writeln('Netdrive not found!');
End.
