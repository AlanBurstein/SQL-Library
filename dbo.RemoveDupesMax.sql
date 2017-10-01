IF OBJECT_ID('dbo.RemoveDupesMax') IS NOT NULL DROP FUNCTION dbo.RemoveDupesMax;
GO
CREATE FUNCTION dbo.RemoveDupesMax(@string varchar(max), @preserved varchar(50))
/*****************************************************************************************
Purpose:
 A purely set-based inline table valued function (iTVF) that accepts and input strings
 (@string) and a pattern (@preserved) and removes all duplicate characters in @string that
 do not match the @preserved pattern.

Compatibility:
 SQL Server 2008+

Syntax:
--===== Autonomous use
 SELECT rd.CleanedString
 FROM dbo.RemoveDupesMax(@string, @preserved) rd;
--===== Use against a table
 SELECT st.SomeColumn1, rd.CleanedString
 FROM SomeTable st
 CROSS APPLY dbo.RemoveDupesMax(st.SomeColumn1, @preserved) rd;

Parameters:
 @string    = varchar(max); Input string to be "cleaned"
 @preserved = varchar(50); the pattern to preserve. For example, when @preserved='[0-9]'
 only non-numeric characters will be removed

Return Types:
 Inline Table Valued Function returns:
 CleanedString = varchar(max); the string with duplicate characters removed
---------------------------------------------------------------------------------------
Developer Notes:
 1. Requires NGrams2B. The code for NGrams2B can be found here:
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

 3. RemoveDupesMax is deterministic; for more about deterministic and nondeterministic
    functions see https://msdn.microsoft.com/en-us/library/ms178091.aspx

---------------------------------------------------------------------------------------
Examples:

DECLARE @string varchar(8000) = '!!!aa###bb!!!';
--===== Remove all duplicate characters
  SELECT CleanedString FROM dbo.RemoveDupesMax(@string,''); -- Returns: !a#b!

--===== Remove all non-alphabetical duplicates
  SELECT CleanedString FROM dbo.RemoveDupesMax(@string,'[a-z]'); -- Returns: !aa#bb!

--===== Remove only alphabetical duplicates
  SELECT CleanedString FROM dbo.RemoveDupesMax(@string,'[^a-z]'); -- Returns: !!!a###b!!!
---------------------------------------------------------------------------------------
Revision History:
 Rev 00 - 20170930 - Initial Creation - Alan Burstein
****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN
SELECT CleanedString =
( SELECT token+''
  FROM dbo.NGrams2B(@string,1)
  WHERE token <> SUBSTRING(@string,position+1,1) -- exclude chars equal to the next char
  OR token LIKE @preserved -- preserve characters that match the @preserved pattern
  FOR XML PATH(''),TYPE
).value('(text())[1]','varchar(8000)'); -- using Wayne Sheffield’s concatenation logic
GO