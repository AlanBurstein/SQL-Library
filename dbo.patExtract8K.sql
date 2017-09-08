use sqlDevToolboxAB;
go
set ansi_nulls, quoted_identifier on;
go

if object_id('dbo.patExtract8K') is not null drop function dbo.patExtract8K;
go
create function dbo.patExtract8K
(
  @string  varchar(8000),
  @pattern varchar(50)
)
/****************************************************************************************
Description:
 This can be considered a T-SQL inline table valued function (iTVF) equivalent of 
 Microsoft's mdq.RegexExtract: https://goo.gl/HpAvKZ except:

   1. It includes each matching substring's position in the string
   2. It accepts varchar(8000) instead of nvarchar(4000) for the input string, varchar(50)
      instead of nvarchar(4000) for the pattern
   3. You have specify what text we're searching for as an exclusion; e.g. for numeric 
      characters you should search for '[^0-9]' instead of '[0-9]'.
   4. The mask parameter is not required and therefore does not exist. 
   5. There is is no parameter for naming a "capture group"

 Using the variable below, both of the following queries will return the same result:
	 DECLARE @string nvarchar(4000) = N'123 Main Street';
	 
   SELECT item FROM dbo.patExtract8K(@string, '[^0-9]');
   SELECT mdq.RegexExtract(@string, N'(?<number>(\d+))(?<street>(.*))', N'number', 1);

 Alternatively, you can think of patExtract8K as Chris Morris' PatternSplitCM (found here:
 http://www.sqlservercentral.com/articles/String+Manipulation/94365/) but only returns the
 rows where [matched]=0. The following two sets of queries return the same result:

   select itemNumber, item 
   from dbo.patExtract8K('xx123xx555xx999', '[^0-9]');
   
   select itemNumber = row_number() over (order by itemNumber), item 
   from dbo.patternSplitCM('xx123xx555xx999', '[^0-9]')
   where [matched] = 0;

   select itemNumber, item 
   from dbo.patExtract8K('xx123xx555xx999', '[0-9]');
   
   select itemNumber = row_number() over (order by itemNumber), item 
   from dbo.patternSplitCM('xx123xx555xx999', '[0-9]')
   where [matched] = 0;

Compatibility:
 SQL Server 2008+

Syntax:
 --===== Autonomous
 SELECT pe.ItemNumber, pe.ItemIndex, pe.Item
 FROM dbo.patExtract8K(@string,@pattern) pe;

 --===== Against a table using APPLY
 SELECT t.someString, pe.itemIndex, pe.item
 FROM dbo.SomeTable t
 CROSS APPLY dbo.patExtract8K(t.someString, @pattern) pe;

Parameters:
 @string        = varchar(8000); the input string
 @searchString  = varchar(50); pattern to searhc for

Returns:
 itemNumber = bigint; the instance or ordinal position of the matched substring
 itemIndex  = bigint; the location of the matched substring within the input string
 item       = varchar(8000); the returned text

Developer Notes:
 1. Requires NGrams8k

 2. Is not case sensitive (use a case sensitive collation for case sensitive comparisons)

 3. dbo.patExtract8K is deterministic. For more about deterministic functions see:
    https://msdn.microsoft.com/en-us/library/ms178091.aspx

Examples:
 --===== (1) Basic extact all groups of numbers:
    with temp(id, txt) as
   (
     select * from (values
     (1, 'hello 123 fff 1234567 and today;""o999999999 tester 44444444444444 done'),
     (2, 'syat 123 ff tyui( 1234567 and today 999999999 tester 777777 done'),
     (3, '&**OOOOO=+ + + // ==?76543// and today !!222222\\\tester{}))22222444 done'))t(x,xx)
   )
   select
     [temp.id] = t.id,
     pe.itemNumber,
     pe.itemIndex,
     pe.item
   from temp t
   cross apply dbo.patExtract8K(t.txt, '[^0-9]') pe;

---------------------------------------------------------------------------------------
Revision History:
 Rev 00 - 20170801 - Initial Development - Alan Burstein
****************************************************************************************/
returns table with schemabinding as return
select
  itemNumber = row_number() over (order by (position)),
  itemIndex  = position,
  item       = substring(token,1,isnull(nullif(patindex('%'+@pattern+'%', token),0),8000)-1)
from
(
  select 
    position,
  	token = substring(@string, position, 8000)
  from dbo.NGrams8k(@string, 1)
  where token not like @pattern 
  and (position = 1 or substring(@string,checksum(position-1),1) like @pattern)
) filteredUnigram;
GO


