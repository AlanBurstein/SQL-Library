IF OBJECT_ID('dbo.substringExtract8K') IS NOT NULL DROP FUNCTION dbo.substringExtract8K;
GO
CREATE FUNCTION dbo.substringExtract8K
(
  @string       varchar(8000), 
  @searchString varchar(100)
)
/****************************************************************************************
Purpose:
 Given a string (@string) and a substring to look for (@searchString), substringExtract8K
 will return the position of each instance of @searchString.

Compatibility: 
 SQL Server 2008+ and Azure SQL Database

Syntax:
--===== Autonomous
 SELECT rn, position, token
 FROM dbo.substringExtract8K(@string,@searchString,@Start,@End);

--===== Against a table using APPLY
 SELECT rn, position, token
 FROM dbo.SomeTable s
 CROSS APPLY dbo.substringExtract8K(s.SomeString,@searchString,@Start,@End);

Parameters:
 @string       = varchar(8000); the input string
 @searchString = varchar(100); the string to search for

Returns:
 itemNumber    = bigint; the instance of the search string; for example, 2 is the 
                 second time the search string appears in the input string
 position      = bigint; the search string's position in the input string
 token         = varchar(8000); the search string        

Developer Notes:
 1. This is what is referred to as an "inline" scalar UDF." Technically it's an inline
    table valued function (iTVF) but performs the same task as a scalar valued user 
    defined function (UDF); the difference is that it requires the APPLY table operator 
    to accept column values as a parameter. For more about "inline" scalar UDFs see this
    article by SQL MVP Jeff Moden: http://www.sqlservercentral.com/articles/T-SQL/91724/ 
    and for more about how to use APPLY see the this artilce by SQL MVP Paul White:
    http://www.sqlservercentral.com/articles/APPLY/69953/.
    
    Note the above syntax example and usage examples below to better understand how to
    use the function. Although the function is slightly more complicated to use than a
    scalar UDF it will yeild notably better performance for many reasons. For example, 
    unlike a scalar UDFs or multi-line table valued functions, the inline scalar UDF does
    not restrict the query optimizer's ability generate a parallel query execution plan.

 2. Generally gets a parallel query execution plan and performs about 3-4 times better 
    when it does

 3. Requires NGrams8k

 4. substringExtract8K is deterministic. For more about deterministic functions see:
    https://msdn.microsoft.com/en-us/library/ms178091.aspx

Usage Examples:
 --===== 1. Locate all instances and the position of of the string, "The "; not case-sensitive
  SELECT itemNumber, position, token 
	FROM dbo.substringExtract8K('The cat and the dog.','the ');

 --===== 2. Locate all instances and the position of of the string, "The "; case-sensitive solution
 WITH A AS (SELECT * FROM dbo.substringExtract8K('The cat and the dog.','the '))
 SELECT itemNumber, position, token 
 FROM A 
 WHERE token COLLATE Latin1_General_BIN = 'the ';

 --===== 3. Locate the location of the 2nd through 4th instance of the text, "xx"
 SELECT Instance = itemNumber, position 
 FROM dbo.substringExtract8K('1: xx 2: xx 3: xx 4: xx 5: xx;','xx')
 WHERE itemNumber BETWEEN 2 AND 4;

 --===== 4. Locate all strings in a table that contain 3 instances of "xx":
 DECLARE @string TABLE (vID int primary key, val varchar(100) NOT NULL);
 DECLARE @pattern varchar(1000) = 'xx';
 INSERT @string VALUES (1,'??xx99xx88xx'),(2,'xxx!xx'),(3,'x12345xx');

 SELECT vID, val
 FROM @string s
 CROSS APPLY dbo.substringExtract8K(val, @pattern)
 GROUP BY vID, val
 HAVING COUNT(*) >2;

-----------------------------------------------------------------------------------------
Revision History:
 Rev 00.00 - 20150518 - Alan Burstein - Initial Development
 Rev 00.01 - 20160326 - Changed return types to int for rn and position, updated 
                        documentation - Alan Burstein
 Rev 00.02 - 20171129 - Alan Burstein - changed name fr findString8K to substringExtract8K
*****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN
SELECT 
  itemNumber = CAST(ROW_NUMBER() OVER (ORDER BY v.p) AS int),
  position   = CAST(v.p AS int),
  token
FROM dbo.ngrams8k(@string,DATALENGTH(@searchString)) ng
CROSS APPLY (VALUES (ng.position)) v(p) 
WHERE token = @searchString
GO