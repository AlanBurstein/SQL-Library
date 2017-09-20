if object_id('dbo.stringCompare8k','IF') is not null drop function dbo.stringCompare8k;
go
create function dbo.stringCompare8k(@string1 varchar(8000), @string2 varchar(8000))
returns table with schemabinding as return
/****************************************************************************************
Purpose
 Sometimes you need to determine why two strings are not equal (e.g. different whitespace
 characters, special XML characters, etc). This function returns the char value for each 
 character in two input strings, indicates if the character is a reserved XML The function
 is compatible with both UNICODE and ASCII characters. 

Compatibility: 
 SQL Server 2008+ and Azure SQL Database

Syntax:
--===== Autonomous use
 SELECT sc.position, sc.s1, sc.s2, sc.s1c, sc.s2c, sc.s1x, sc.s2x, sc.isMatch
 FROM dbo.stringCompare8k(@string1,@string2) sc;

--===== Against a table(s)
 SELECT sc.position, sc.s1, sc.s2, sc.s1c, sc.s2c, sc.s1x, sc.s2x, sc.isMatch
 FROM dbo.sometable1 s1
 CROSS APPLY dbo.stringCompare8k(s1.somevalue, s2.somevalue) sc;

Parameters:
  @string1         = varchar(8000); First input string
  @string2         = varchar(8000); Second input string
 
Returns:
 position = bigint; the position of the character in the string
 s1       = nchar(1); the character for that Position in @String1
 s2       = nchar(1); the character for that Position in @String2
 s1c      = int; the CHAR or NCHAR value of String1Char
 s2c      = int; the CHAR or NCHAR value of String2Char
 s1x      = bit; boolean value indicates if String1Char is special XML character
 s2x      = bit; boolean value indicates if String2Char is special XML character
 isMatch  = bit; boolean value indicates if String1Char & String2Char match

Developer Notes:
 1. stringCompare8k requires ngrams8K: https://goo.gl/643HRD
 2. stringCompare8k is not case/accent sensitive

Examples:
 --===== (1) Basic use: determine what makes these two strings different
 SELECT position, s1, s2, s1c, s2c, s1x, s2x, isMatch
 FROM dbo.StringCompare8k('Mexico', 'Mexixo');

 --===== (2) Though these will look the same, they're different (compare s1b to S2b)
 DECLARE @string1 varchar(10) = CHAR(9)+'cat', @string2 varchar(10) = ' cat';
 SELECT position, s1, s2, s1c, s2c, s1x, s2x, isMatch
 FROM dbo.StringCompare8k(@string1, @string2);

 --===== (3) Calculate the Hamming Distance between two equal length strings:
 DECLARE @string1 varchar(100) = 'their', @string2 varchar(100) = 'theer';
 SELECT 
   string1 = @string1,
	 string2 = @string2,
   HD      = IIF(LEN(@string1)=LEN(@string2), SUM(ABS(IsMatch-1)), NULL)
 FROM dbo.stringCompare8k(@string1, @string2);

 --===== (4) Find difference where typical equal comparison would show equal
   -- below is a special Unicode "1" and a normal "1". 
 DECLARE @N1 NVARCHAR(10) = N'１', @N2 NVARCHAR(10) = N'1';
 SELECT *, [AreSame?] = IIF(@N1 = @N2, 'same', 'not same')
 FROM dbo.StringCompare8k(@N1, @N2);

---------------------------------------------------------------------------------------
Revision History:
 Rev 00 - 20170919 - Initial development - Alan Burstein
****************************************************************************************/
select position,              -- unigram position for both input strings
       s1,                    -- position.character for string1
       s2,                    -- position.character for string2
       s1c     = unicode(s1), -- position.character.unicode for string1
       s2c     = unicode(s2), -- position.character.unicode for string1=2
       s1x     = case when len((select s1+'' for xml path(''))) > 1 then 1 else 0 end,
       s2x     = case when len((select s2+'' for xml path(''))) > 1 then 1 else 0 end,
       isMatch = convert(bit, charindex(s1, isnull(s2,'')))
from
(  select
    ng.position,
    s1   = ng.token collate Latin1_General_BIN,
    s2   = nullif(substring(string2, position, 1),'') --null more readable than blank
  from
  (  select 
      string1 = case when l.s1 >  l.s2 then @string1 else @string2 end,
      string2 = case when l.s1 <= l.s2 then @string1 else @string2 end
      from (values (isnull(@string1,''), isnull(@string2,''))) s(string1, string2)
      cross apply (values (datalength(string1), datalength(string2))) l(s1,s2)
  ) as sortByLength
  cross apply dbo.ngrams8k(string1, 1) ng
) as extractUnigrams;
go
