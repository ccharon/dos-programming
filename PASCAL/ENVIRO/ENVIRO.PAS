{ Enviro provides functions to interact with the environment block of the   }
{ current process. It includes functionality to find the environment block, }
{ check for the existence, set new values and delete environment variables. }

Unit Enviro;

Interface

Var 
  EnvSeg   : word;  { Segment address of the environment block }
  EnvOfs   : word;  { Offset within the segment where the environment block starts }
  EnvSize  : word;  { Size of the environment block in bytes }

Function FindEnv: Boolean;
Function SetEnv(Variable,NewVal : String): boolean;

Function CreateVar(Variable, NewVal: String): Boolean;
Function ReadVar(Variable : String;Var Value : String): Boolean;
Function UpdateVar(Variable, NewVal, OldVal: String): Boolean;
Function DeleteVar(Variable : String): Boolean;

Implementation

Uses dos;

Type MemoryControlBlock = 
    Record
      Blocktag   :  byte;
      BlockOwner :  word;
      BlockSize  :  word;
      misc       :  ARRAY[1..3] Of byte;
      ProgramName:  ARRAY[1..8] Of CHAR;
    End;

  ProgramSegmentPrefix = 
    Record
      PSPtag     :  word;
      misc       :  ARRAY[1..21] Of word;
      Environment:  word
    End;

Var 
  MCB      : ^MemoryControlBlock; { Pointer to the Memory Control Block }
  r        : Registers;           { DOS registers for interrupt calls }
  Found    : Boolean;             { Flag indicating if the MCB was found }
  Segment  : Word;                { Segment address of the environment block }
  EnvPtr   : Word;                { Pointer to the environment block }
  Startofs : Word;                { Starting offset of the environment block }

Const 
  { Program Segment Prefix (PSP) signatures, to identify the PSP in memory }
  PSP_SIGNATURE_1 = $20CD; { Almost all versions of DOS use this signature }
  PSP_SIGNATURE_2 = $27CD; { DOS MODE uses this in some versions  }

  NULL_TERMINATOR = $0000; { Null terminator for strings in the environment block }

  MCB_END_MARKER = $5A; { End marker for the Memory Control Block list }



{ Function FindEnvMCB: This function attempts to locate the Memory Control }
{ Block (MCB) associated with the environment block of the current process. }
{ It checks various conditions to verify the MCB and sets the global variable }
{ Found to True if the MCB is found. It returns True if the MCB is found, }
{ otherwise, it returns False. }
Function FindEnvMCB: Boolean;

Var 
  MCBenv   :  ^MemoryControlBlock;       { Pointer to environment Memory Control Block }
  MCBowner :  ^MemoryControlBlock;       { Pointer to the owner Memory Control Block }
  MCBsize  :  LongInt;                   { size of the Memory Control Block in bytes }
  PSP      :  ^ProgramSegmentPrefix;     { Pointer to the Program Segment Prefix }

  i        :  Word;                      { Loop counter variable }

Begin
  FindEnvMCB := False;                   { Initialize the function result to False }

  MCBsize := LongInt(MCB^.BlockSize) SHL 4; { Calculate the size of the block in bytes }
  
  If (MCB^.BlockOwner <> 0) Then { is there a block owner}
    Begin
      PSP := Ptr(MCB^.BlockOwner,0); { Get the adddress of the PSP of the block owner }
      
      If ((PSP^.PSPtag = PSP_SIGNATURE_1) Or (psp^.PSPtag = PSP_SIGNATURE_2)) Then { Check if the PSP signature matches }
        Begin
          MCBenv := Ptr(psp^.Environment-1,0); { Get the MCB of the environment block }

          If ((MCB^.Blockowner <> (Segment + 1)) {MCB owner is not the current segment }
              And (PSP^.Environment = (Segment + 1)) { and the environment segment matches }
              And (MCB^.BlockOwner = MCBenv^.BlockOwner)) Then { and the MCB owner matches the environment MCB owner }
            Begin
              EnvSize := MCBenv^.BlockSize SHL 4; { Calculate the size of the environment block }
              EnvSeg := PSP^.Environment;        { Set the environment segment }
              EnvOfs := 0;                       { Set the environment offset to 0 }
              
              i := 0;
              While (i <= EnvSize) And (MemW[EnvSeg:i] <> NULL_TERMINATOR) Do 
                inc(i); { Find the end of the environment block }
              
              inc(i,2); { Move past the null terminator }
              
              FindEnvMCB := (i > EnvSize) Or (Mem[EnvSeg:i] <> $01); { Check if the environment block is valid }
            End;
        End;
    End;
End;


{ locates the environment block for the current process. It sets the global }
{ variables EnvSeg, EnvOfs, and EnvSize to the segment, offset, and size of }
{ the environment block, respectively. It returns True if the environment   }
{ block is found, otherwise, it returns False.                              }
Function FindEnv: Boolean;

Begin

{ INT 21h Function 52h is a undocumented DOS function call that returns a "list of lists" }
{ containing Memory Control Blocks (MCBs), Device Driver List ... }
  r.AH := $52;
  Intr($21, r);
  Segment := MemW[r.ES:r.BX - 2];

  { search for the environment block }
  Repeat
    MCB := Ptr(Segment, 0);
    Found := FindEnvMCB;
    Segment := Segment + MCB^.BlockSize + 1;
  Until Found Or (MCB^.Blocktag = MCB_END_MARKER );

  FindEnv := Found;
End;


{ sets a new value for a specified environment variable. It takes two         }
{ parameters: the name of the environment variable (Variable) and the new     }
{ value to be set (NewVal). If the environment variable already exists, it    }
{ updates its value. If it does not exist, it creates a new environment       }
{ variable with the specified value. The function returns True if the         }
{ operation is successful, otherwise, it returns False.                       }
Function SetEnv(Variable, NewVal: String): Boolean;

Var 
  OldVal: String;
  SaveEnvSize: Word;

Begin
  SaveEnvSize := EnvSize;
  SetEnv := True;

  { Adjust environment size for DOS version 4 }
  If Lo(DosVersion) = 4 Then
    Dec(EnvSize, 10);

  { Check if the environment variable already exists }
  If ReadVar(Variable, OldVal) Then
    SetEnv := UpdateVar(Variable, NewVal, OldVal)
  Else
    SetEnv := CreateVar(Variable, NewVal);

  { Restore the original environment size }
  EnvSize := SaveEnvSize;
End;


{ Checks if a specified environment variable exists and retrieves its value.  }
{ It takes two parameters: the name of the environment variable (Variable)    }
{ and a variable to store its value (Value). If the environment variable is   }
{ found, the function sets Value to its value and returns True. If the        }
{ environment variable is not found, it returns False.}
Function ReadVar(Variable: String; Var Value: String): Boolean;

Var 
  Temp: String;
  ch: Char; { Character read from the environment block }
  i: Word;   
  FoundIt: Boolean;

Begin
  Variable := Variable + '=';
  FoundIt := False;
  i := EnvOfs;

  Repeat
    Temp := '';
    StartOfs := i;

    { Read from the env block until a null char or end of block }
    Repeat
      ch := Char(Mem[EnvSeg:i]);
      If ch <> #0 Then Temp := Temp + ch;
      Inc(i);
    Until (ch = #0) Or (i > EnvSize);

    { Check if the current environment variable matches the requested variable }
    If ch = #0 Then
      Begin
        FoundIt := (Pos(Variable, Temp) = 1);
        If FoundIt Then
          Value := Copy(Temp, Length(Variable) + 1, 255);
      End;
  Until (FoundIt) Or (i > EnvSize);

  ReadVar := FoundIt;
End;

{ Creates a new environment variable with the specified value. It takes two   }
{ parameters: the name of the environment variable (Variable) and the value   }
{ to be set (NewVal). It appends the new variable to the environment block    }
{ and returns True if the operation is successful. If there is not enough     }
{ space to add the new variable, it returns False.                            }
Function CreateVar(Variable, NewVal: String): Boolean;

Var 
  StartPtr, EndPtr: Pointer;  { Pointers for memory manipulation }
  i: Word;

Begin
  CreateVar := True;
  i := EnvOfs;

  { Find the end of the environment block }
  While (i <= EnvSize) And (MemW[EnvSeg:i] <> NULL_TERMINATOR) Do
    Inc(i);

  If i < EnvSize Then
    Begin
      Inc(i);
      Variable := Variable + '=' + NewVal + #0;
      StartPtr := Ptr(EnvSeg, i);
      EndPtr := Ptr(EnvSeg, i + Length(Variable));

      { Check if there is enough space to add the new variable }
      If Ofs(EndPtr^) > EnvSize Then
        CreateVar := False
      Else
        Begin
          Move(StartPtr^, EndPtr^, EnvSize - Ofs(EndPtr^));
          Move(Variable[1], StartPtr^, Length(Variable));
        End;
    End
  Else
    CreateVar := False;
End;


{ Updates the value of an existing environment variable. It takes three       }
{ parameters: the name of the environment variable (Variable), the new value  }
{ to be set (NewVal), and the old value of the environment variable (OldVal). }
{ It updates the value of the environment variable and returns True if the    }
{ operation is successful. If there is not enough space to update the value,  }
{ it returns False.                                                           }
Function UpdateVar(Variable, NewVal, OldVal: String): Boolean;

Var 
  StartPtr, EndPtr: Pointer;  { Pointers for memory manipulation }

Begin
  UpdateVar := True;
  StartPtr := Ptr(EnvSeg, StartOfs + Length(Variable) + 1);

  If Length(OldVal) = Length(NewVal) Then
    { If the old and new values are of the same length, simply overwrite }
    Move(NewVal[1], StartPtr^, Length(NewVal))

  Else If Length(OldVal) > Length(NewVal) Then
    { If the new value is shorter, overwrite and shift remaining data }
         Begin
           Move(NewVal[1], StartPtr^, Length(NewVal));
           StartPtr := Ptr(EnvSeg, StartOfs + Length(Variable) + Length(OldVal) + 1);
           EndPtr := Ptr(EnvSeg, StartOfs + Length(Variable) + Length(NewVal) + 1);
           Move(StartPtr^, EndPtr^, EnvSize - Ofs(StartPtr^));
         End

  Else
    { If the new value is longer, shift data and then overwrite }
    Begin
      EndPtr := Ptr(EnvSeg, StartOfs + Length(Variable) + Length(NewVal) - Length(OldVal) + 1);
      If Ofs(EndPtr^) > EnvSize Then
        UpdateVar := False
      Else
        Begin
          Move(StartPtr^, EndPtr^, EnvSize - Ofs(EndPtr^));
          Move(NewVal[1], StartPtr^, Length(NewVal));
        End;
    End;
End;

{ deletes a specified environment variable. It takes one parameter: the name  }
{ of the environment variable (Variable). If the environment variable exists, }
{ it deletes it and returns True. If the environment variable does not exist, }
{ it returns False.                                                           }
Function DeleteVar(Variable: String): Boolean;

Var 
  StartPtr : Pointer; 
  EndPtr   : Pointer; 

  Temp: String;

Begin
  DeleteVar := False;
  
  If ReadVar(Variable, Temp) Then
    Begin
      StartPtr := Ptr(EnvSeg, StartOfs);
      EndPtr := Ptr(EnvSeg, StartOfs + Length(Temp) + Length(Variable) + 1);

      Move(EndPtr^, StartPtr^, EnvSize - Ofs(EndPtr^));  
      
      DeleteVar := True;
    End
End;


Begin
End.
