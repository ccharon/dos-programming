{ This program will search for the first network drive provided by mTCP 
Netdrive and set the FRSTNDRV environment variable to the drive letter of the
network drive.  (for example, FRSTNDRV=D:) 

It uses the DOS IOCTL function to read the control characters of a drive, and
checks if the drive is a network drive. The environment variable FRSTNDRV will
be set to the drive letter of the network drive. 
    
If no network drive is found, the program will print 'Netdrive not found!'.}
Program FindFirstNetdrive;

Uses
    Enviro,
    Dos;

Type
    TPointer = Record
        Offset: Word;
        Segment: Word;
    End;

Const
    ENV_FRSTNDRV = 'FRSTNDRV';


{ Extract a string from a memory location. If it is a netdrive, it will be 'NETDRIVE' }
Function ExtractNetDrive(Ptr: TPointer): String;
Var
    RawData: Array[0..7] of Byte;
    StrData: String;
    I: Integer;
Begin
    StrData := '';

    { Subtract 10 bytes from the offset, because I was told so :P }
    Dec(Ptr.Offset, 10);

    { Read 8 bytes from the memory location }
    For I := 0 To 7 Do
        RawData[I] := Mem[Ptr.Segment:Ptr.Offset + I];

    { Convert the raw data to a string, replacing non-printable characters with '.' }
    For I := 0 To 7 Do
    Begin
        If (RawData[I] >= 32) and (RawData[I] <= 126) Then 
            StrData := StrData + Chr(RawData[I]) 
        Else
            StrData := StrData + '.';
    End;

    ExtractNetDrive := StrData;
End;


{ Read control characters from a drive, using int 21h, ah=44h, al=04h call }
Function IsNetdrive(Drive: Char): Boolean;
Var
    Regs: Registers;
    Buffer: array[0..7] of Byte;
    Ptr: TPointer;
    StrData: String;

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
            { The buffer contains 2 Pointers, consisting of 16bit Offset + 16bit Segment }
            { The first pointer is the one that is needed }
            Ptr.Offset := Buffer[0] + (Buffer[1] shl 8);
            Ptr.Segment := Buffer[2] + (Buffer[3] shl 8);

            StrData := ExtractNetDrive(Ptr);

            If StrData = 'NETDRIVE' Then
               IsNetdrive := True;
        End;
    End;
End;


{ Set the environment variable }
Function SetEnvVar(Drive: Char): Boolean;
Begin
    SetEnvVar := False;

    If FindEnv Then
        If SetEnv(ENV_FRSTNDRV, Drive + ':') Then
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
                WriteLn('Error setting environment variable ', ENV_FRSTNDRV, '=', Drive, ':');
            
            Halt(0);
        End;
    End;
    Writeln('Netdrive not found!');
End.
