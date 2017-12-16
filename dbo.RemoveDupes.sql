IF OBJECT_ID('dbo.RemoveDupes') IS NOT NULL DROP FUNCTION dbo.RemoveDupes;
GO
CREATE FUNCTION dbo.RemoveDupes(@string varchar(max), @preserved varchar(50))
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
 FROM dbo.RemoveDupes(@string, @preserved) rd;
--===== Against a table
 SELECT st.SomeColumn1, rd.CleanedString
 FROM SomeTable st
 CROSS APPLY dbo.RemoveDupes(st.SomeColumn1, @preserved) rd;

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

 3. RemoveDupes is deterministic; for more about deterministic and nondeterministic
    functions see https://msdn.microsoft.com/en-us/library/ms178091.aspx

---------------------------------------------------------------------------------------
Examples:

DECLARE @string varchar(8000) = '!!!aa###bb!!!';
--===== Remove all duplicate characters
  SELECT CleanedString FROM dbo.RemoveDupes(@string,''); -- Returns: !a#b!

--===== Remove all non-alphabetical duplicates
  SELECT CleanedString FROM dbo.RemoveDupes(@string,'[a-z]'); -- Returns: !aa#bb!

--===== Remove only alphabetical duplicates
  SELECT CleanedString FROM dbo.RemoveDupes(@string,'[^a-z]'); -- Returns: !!!a###b!!!
---------------------------------------------------------------------------------------
Revision History:
 Rev 00 - 20170930 - Initial Creation - Alan Burstein
 Rev 01 - 20171215 - Changed Name to removeDupes from RemoveDupes, added ORDER BY Clause,
                     changed return value to newString from "cleanedString"
****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN
SELECT newString =
( SELECT ng.token+''
  FROM dbo.ngrams2B(@string,1) ng
  WHERE ng.token <> SUBSTRING(@string,ng.position+1,1) -- exclude chars equal to the next
  OR ng.token LIKE @preserved -- preserve characters that match the @preserved pattern
  ORDER BY ng.position  -- your spoon
  FOR XML PATH(''),TYPE -- XML safe concatination
).value('(text())[1]','varchar(max)'); -- using Wayne Sheffield’s concatenation logic
GO