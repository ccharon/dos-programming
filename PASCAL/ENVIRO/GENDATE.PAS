Program GenDate;

Uses
  Enviro,
  Dos;

Var
  Year, Month, Day, DayOfWeek: Word;
  Converted: String;

  DateYYYYMMDD: String;

Begin
  GetDate(Year, Month, Day, DayOfWeek);

  Str(Year, DateYYYYMMDD);

  If Month < 10 Then
     DateYYYYMMDD := DateYYYYMMDD + '0';

  Str(Month, converted);
  DateYYYYMMDD := DateYYYYMMDD + converted;

  If Day < 10 Then
     DateYYYYMMDD := DateYYYYMMDD + '0';

  Str(Day, converted);
  DateYYYYMMDD := DateYYYYMMDD + converted;


  If FindEnv Then
    SetEnv('DATEYMD', DateYYYYMMDD);

End.