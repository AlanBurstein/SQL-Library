IF OBJECT_ID('dbo.removeDupeSpaces8K') IS NOT NULL
DROP FUNCTION dbo.removeDupeSpaces8K
GO
CREATE FUNCTION dbo.removeDupeSpaces8K(@string varchar(8000))
/****************************************************************************************
Purpose:
 Replaces multiple spaces with one space.

Compatibility: 
 SQL Server 2005+

Syntax:
 SELECT t.string, rd.newString
 FROM dbo.someTable t
 CROSS APPLY dbo.removeDupeSpaces8K(@string) rd

Parameters:
 @string - varchar(8000); the input string to clean duplicate spaces from

Return Types:
 inline Table Value Function returns:
 newString = varchar(8000)

Developer Notes:
 1. The code is based on Paul White's code from this SQLServerCentral.com thread:
    https://goo.gl/ZhYLJT

 2. I turned this code into an iTVF (Inline Table Valued Function) that performs the same
    task as a scalar user defined function (UDF) except that it requires the APPLY table 
    operator. Note the usage examples below and See this article for more details: 
    http://www.sqlservercentral.com/articles/T-SQL/91724/
	
    As an iTVF, the function will be slightly more complicated to use than a scalar UDF 
    but will yeild much better performance. For example - unlike a scalar UDF, this 
    function doesn't prevent the query optimizer from generating a parallel execution plan.

 3. After extensive testing I was able to determine that an iTVF version of this function 
    was about 30% faster than the scalar equivalent. 
		
Examples:
--=====
 DECLARE @string varchar(8000) = '1 space 2 space  whitespace    blue space     !'
 SELECT NewString FROM dbo.removeDupeSpaces8K(@string);

----------------------------------------------------------------------------------------
Revision History:
 Rev 00 - 20150501 - Initial Creation - Alan Burstein
 Rev 01 - 20170907 - Added COLLATE LATIN1_GENERAL_BIN to address the collation problem 
                     mentioned here: https://goo.gl/ZhYLJT
****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN
SELECT newString = 
  replace(replace(replace(replace(replace(replace(replace(
  ltrim(rtrim(@string COLLATE LATIN1_GENERAL_BIN)),
  '                                 ',' '),
  '                 ',' '),
  '         ',' '),
  '     ',' '),
  '   ',' '),
  '  ',' '),
  '  ',' ');
GO