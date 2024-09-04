Program TestEnviro;

Uses
  Enviro, { Include the Enviro unit }
  Dos,    { Include the Dos unit for DOS-related functions }
  Crt;    { Include the Crt unit for screen handling }

Var
  VariableName: String;
  VariableValue: String;
  NewValue: String;
  Success: Boolean;

Begin
  ClrScr; { Clear the screen }

  { Initialize the environment block }
  If FindEnv Then
  Begin
    WriteLn('Environment block found.');

    { Set a new environment variable }
    VariableName := 'TEST_VAR';
    NewValue := 'HelloWorld';
    Success := SetEnv(VariableName, NewValue);
    If Success Then
      WriteLn('Environment variable set successfully.')
    Else
      WriteLn('Failed to set environment variable.');

    { Read the environment variable }
    Success := ReadVar(VariableName, VariableValue);
    If Success Then
      WriteLn('Environment variable ', VariableName, ' = ', VariableValue)
    Else
      WriteLn('Failed to read environment variable.');

    { Update the environment variable }
    NewValue := 'NewValue';
    Success := UpdateVar(VariableName, NewValue, VariableValue);
    If Success Then
      WriteLn('Environment variable updated successfully.')
    Else
      WriteLn('Failed to update environment variable.');

    { Delete the environment variable }
    Success := DeleteVar(VariableName);
    If Success Then
      WriteLn('Environment variable deleted successfully.')
    Else
      WriteLn('Failed to delete environment variable.');
  End
  Else
    WriteLn('Failed to find environment block.');

  ReadLn; { Wait for user input before closing }
End.
