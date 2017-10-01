IF OBJECT_ID('dbo.NReplace8K') IS NOT NULL DROP FUNCTION dbo.NReplace8K;
GO
CREATE FUNCTION dbo.NReplace8K
(
  @string        varchar(8000),
  @searchString  varchar(256),
  @instance      int,
  @replaceString varchar(256)
)
/****************************************************************************************
Purpose:
 Takes an input string (@string) and replaces the (@instance)th instance of the search 
 string (@searchString) with a replacement string (@replaceString). If there is no match 
 the input string is returned unchanged.

Compatibility: 
 SQL Server 2008+ and Azure SQL Database

Syntax:
 --===== Autonomous
 SELECT NewString 
 FROM dbo.NReplace8K(@string,@SearchString,@instance,@replaceString);

 --===== Against a table using APPLY
 SELECT s.String, nr.NewString 
 FROM dbo.SomeTable s
 CROSS APPLY dbo.NReplace8K(s.String,@SearchString,@instance,@replaceString) nr;

Parameters:
 @string        = Input string
 @searchString  = Literal to search for
 @instance      = The insance of the the search string 
 @replaceString = What to replace the search string with

Returns:
 NewString = varchar(8000); the new value created byy NReplace8K

Developer Notes:
 1. This is an "inline" scalar UDF." Technically it's an inline table valued function 
    (iTVF) but performs the same task as a scalar valued user defined function (UDF); 
    the difference is that it requires the APPLY table operator to accept column values
    as a parameter. For more about "inline" scalar UDFs see this article by SQL MVP Jeff 
    Moden: http://www.sqlservercentral.com/articles/T-SQL/91724/ and for more about how 
    to use APPLY see the this artilce by SQL MVP Paul White:
    http://www.sqlservercentral.com/articles/APPLY/69953/.
    
    Note the above syntax example and usage examples below to better understand how to
    use the function. Although the function is slightly more complicated to use than a
    scalar UDF it will yeild notably better performance for many reasons. For example, 
    unlike a scalar UDFs or multi-line table valued functions, the inline scalar UDF does
    not restrict the query optimizer's ability generate a parallel query execution plan.

 2. Requires NGrams8k

 3. Returns NULL on NULL input
 
 4. If no match is found the function will return the orignal string.

 5. Is not case sensitive

 6. Tends to perform better with a parallel query plan. If the opimizer is not generating
    a parallel plan consider Adam Machanic's make_parallel() function (provided that you 
	  are on a machine with two or more logical CPUs). make_parallel can be found here: 
 http://sqlblog.com/blogs/adam_machanic/archive/2013/07/11/next-level-parallel-plan-porcing.aspx

 7. NReplace8K is deterministic. For more about deterministic functions see:
    https://msdn.microsoft.com/en-us/library/ms178091.aspx

-- Examples (ran all the code together or copy/paste the variables as needed):
 --===== (1) Replace the second instance of "xx" with the text, "<Replaced>":
 DECLARE @string1 varchar(100) = 'xx123xx9xx!!!xx?xx';
 SELECT NewString FROM dbo.NReplace8K(@string1, 'xx',3,'<Replaced>');

 --===== (2) Replace the first and second instance of "xx" with a double-underscore:
 DECLARE @string2 varchar(100) = 'xx123xx9xx!!!xx?xx';
 SELECT ns2.NewString
 FROM dbo.NReplace8K(@string2, 'xx',1,'__') ns1
 CROSS APPLY dbo.NReplace8K(ns1.NewString, 'xx',1,'__') ns2;

 --===== (3) Replace the 2nd, 3rd and 4th instance of "xx" with text:
 SELECT ns3.NewString 
 FROM dbo.NReplace8K(@string, 'xx',2,'<2nd>') ns1
 CROSS APPLY dbo.NReplace8K(ns1.NewString, 'xx',2,'<3rd>') ns2
 CROSS APPLY dbo.NReplace8K(ns2.NewString, 'xx',2,'<4th>') ns3;

---------------------------------------------------------------------------------------
Revision History:
 Rev 00 - 20170901 - Initial Development - Alan Burstein
 Rev 01 - 20170930 - Changed CTE logic to subquery, tested NULL & blank input -
          Alan Burstein
****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN
SELECT NewString = ISNULL((
    SELECT STUFF(@string,position,DATALENGTH(@searchString),@replaceString)
    FROM 
    (  SELECT rn = ROW_NUMBER() OVER (ORDER BY position), position 
       FROM dbo.NGrams8k(@string,DATALENGTH(@searchString))
       WHERE token = @searchString ) as p
    WHERE rn = @instance), @string);
GO