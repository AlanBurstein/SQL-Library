USE sqlDevToolboxAB
GO
IF OBJECT_ID('dbo.SubstringBetweenChar8K') IS NOT NULL 
  DROP FUNCTION dbo.SubstringBetweenChar8K;
GO
CREATE FUNCTION dbo.SubstringBetweenChar8K
(
  @string    varchar(8000),
  @start     tinyint,
  @stop      tinyint,
  @delimiter char(1)
)
/*****************************************************************************************
Purpose:
 Takes in input string (@string) and returns the text between two instances of a delimiter
 (@delimiter); the location of the delimiters is defined by @start and @stop.
 For example: if @string = 'xx.yy.zz.abc', @start=1, @stop=3, and @delimiter = '.' the
 function will return the text: yy.zz; this is the text between the first and third
 instance of "." in the string "xx.yy.zz.abc".

Compatibility:
 SQL Server 2008+

Syntax:
--===== Autonomous use
 SELECT sb.token, sb.position, sb.tokenLength
 FROM dbo.SubstringBetweenChar8K(@string, @start, @stop, @delimiter); sb;

--===== Use against a table
 SELECT sb.token, sb.position, sb.tokenLength
 FROM SomeTable st
 CROSS APPLY dbo.SubstringBetweenChar8K(st.SomeColumn1, 1, 2, '.') sb;

Parameters:
 @string    = varchar(8000); Input string to parse
 @start     = tinyint; the first instance of @delimiter to search for; this is where the
              output should start. When @start is 0 then the function will return
              everything from the beginning of @string until @end.
 @stop      = tinyint; the last instance of @delimiter to search for; this is where the
              output should end. When @end is 0 then the function will return everything
              from @start until the end of the string.
 @delimiter = char(1); this is the delimiter use to determine where the output starts/ends

Return Types:
 Inline Table Valued Function returns:
   token     = varchar(8000); the substring between the two instances of @delimiter 
               defined by @start and @stop
 position    = smallint; the location of where the substring begins
------------------------------------------------------------------------------------------
Developer Notes:
 1. Requires NGrams8K. The code for NGrams8K can be found here:
    http://www.sqlservercentral.com/articles/Tally+Table/142316/

 2. This function is what is referred to as an "inline" scalar UDF." Technically it's an
    inline table valued function (iTVF) but performs the same task as a scalar valued user
    defined function (UDF); the difference is that it requires the APPLY table operator
    to accept column values as a parameter. For more about "inline" scalar UDFs see this
    article by SQL MVP Jeff Moden: http://www.sqlservercentral.com/articles/T-SQL/91724/
    and for more about how to use APPLY see the this article by SQL MVP Paul White:
    http://www.sqlservercentral.com/articles/APPLY/69953/.

    Note the above syntax example and usage examples below to better understand how to
    use the function. Although the function is slightly more complicated to use than a
    scalar UDF it will yield notably better performance for many reasons. For example,
    unlike a scalar UDFs or multi-line table valued functions, the inline scalar UDF does
    not restrict the query optimizer's ability generate a parallel query execution plan.

 3. dbo.SubstringBetweenChar8K is deterministic; for more about deterministic and
    nondeterministic functions see https://msdn.microsoft.com/en-us/library/ms178091.aspx

Examples:
-- beginning of string to 2nd delimiter, 2nd delimiter to end of the string
DECLARE @string varchar(100) = 'abc.defg.hi.jk.lmnop.qrs.tuv';
SELECT string=@string, token, position FROM dbo.SubstringBetweenChar8K(@string,0,2, '.');
SELECT string=@string, token, position FROM dbo.SubstringBetweenChar8K(@string,2,0, '.');

-- Between the 1st & 2nd, then 2nd & 5th delimiters
SELECT string=@string, token, position FROM dbo.SubstringBetweenChar8K(@string,1,2, '.');
SELECT string=@string, token, position FROM dbo.SubstringBetweenChar8K(@string,2,5, '.');

-- dealing with NULLS, delimiters that don't exist and when @first = @last
SELECT string=@string, token, position FROM dbo.SubstringBetweenChar8K(@string,2,10,'.');
SELECT string=@string, token, position FROM dbo.SubstringBetweenChar8K(@string,1,NULL,'.');
SELECT string=@string, token, position FROM dbo.SubstringBetweenChar8K(@string,NULL,1,'.');
---------------------------------------------------------------------------------------
Revision History:
 Rev 00 - 20160720 - Initial Creation - Alan Burstein
 Rev 01 - 20160821 - Re-wrote a single-char version (this); removed tokenLen
****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN
WITH
chars AS
(
 SELECT instance = 0, position = 0 WHERE @start = 0
 UNION ALL
 SELECT ROW_NUMBER() OVER (ORDER BY position), position
 FROM dbo.NGrams8k(@string,1)
 WHERE token = @delimiter
 UNION ALL
 SELECT -1, DATALENGTH(@string)+1 WHERE @stop = 0
)
SELECT 
  token = SUBSTRING
          (
            @string,
            MIN(position)+1,
            NULLIF(MAX(position),MIN(position)) - MIN(position)-1
          ),
  position = CAST
      		(
            CASE WHEN NULLIF(MAX(position),MIN(position)) - MIN(position)-1 > 0
            THEN MIN(position)+1 END AS smallint
          )
FROM chars
WHERE instance IN (@start, NULLIF(@stop,0), -1);
GO