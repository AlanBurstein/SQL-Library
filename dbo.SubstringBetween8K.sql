IF OBJECT_ID('dbo.SubstringBetween8K') IS NOT NULL DROP FUNCTION dbo.SubstringBetween8K;
GO
CREATE FUNCTION dbo.SubstringBetween8K
(
  @string        varchar(8000),
  @searchString1 varchar(1000),
  @searchString2 varchar(1000),
  @s1Pos         tinyint,
  @s2Pos         tinyint
)
/****************************************************************************************
Purpose:
 Takes an input string (@string) and returns the substring that exists between the 

 Takes in input string (@string) and returns the text between the @s1Pos'th instance of
 @searchString1 and the @s2Pos'th instance of @searchString2. The location of the 
 delimiters is defined by @s1Pos and @s2Pos. For example, the query below will return 
 everything between the first instance of 'abc' and the 2nd instance of 'xyz':

 select newString
 from dbo.SubstringBetween8K('xyz abc 123 abc 999 xyz', 'abc', 'xyz', 1, 2);
 -- returns  "123 abc 999" (no quotes)

Compatibility: 
 SQL Server 2008+ and Azure SQL Database

Syntax:
--===== Autonomous
 SELECT sb.newString
 FROM dbo.SubstringBetween8K(@string, @searchString1, @searchString2, @s1pos, @s2pos) sb;

Parameters:
  @string        = varchar(8000); Input string to parse
  @searchString1 = varchar(1000),
  @searchString2 = varchar(1000),
  @s1Pos         = tinyint; the instance of @searchString1 to search for; this is where the
                   output should start. For example, if @searchString1="xxx" and @s1pos=3
                   then the will begin right after the 3rd instance of "xxx". If there are
                   not 3 instances of "xxx" then the function will return a NULL. 
  @s2Pos         = tinyint; the instance of @searchString2 to search for; where the output
                   should end.

Developers Notes:
1.  Slower than dbo.SubstringBetween8K...
 
2.  This is what is referred to as an "inline" scalar UDF." Technically it's an inline
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

 2. Requires NGrams8k

 3. If no match is found the function will return a NULL.

 4. Is not case sensitive

 5. Tends to perform better with a parallel query plan. If the opimizer is not generating
    a parallel plan consider Adam Machanic's make_parallel() function (provided that you 
	are on a machine with two or more logical CPUs). make_parallel can be found here: 
 http://sqlblog.com/blogs/adam_machanic/archive/2013/07/11/next-level-parallel-plan-porcing.aspx

 6. @S1Pos and @S2Pos must be greater than 0. If the run with OPTION(Recompile) the
    function will produce a trivial execution plan when @S1Pos <= 0 or @S2Pos <= 0.

 7. SubstringBetween8K is deterministic. For more about deterministic functions see:
    https://msdn.microsoft.com/en-us/library/ms178091.aspx

Examples: 
 DECLARE @String varchar(1000) = 'xxx123xxx555xxx123456xxx999xxx';

 SELECT NewString -- Everything between the 1st and 3rd "xxx"
 FROM dbo.SubstringBetween8K(@String,'xxx','xxx',1,3); -- Returns: 123xxx555

 SELECT NewString -- everything between the 3rd "xxx" and 1st "999"
 FROM dbo.SubstringBetween8K(@String,'xxx','999',3,1); -- Returns: 123456xxx
 
 SELECT NewString -- Everything between the 1st "xxx" and 1st "123"
 FROM dbo.SubstringBetween8K(@String,'123','xxx',1,1); -- Returns: NULL

 SELECT NewString -- Passing invalid parameter, note the execution plan
 FROM dbo.SubstringBetween8K(@String,'xxx','xxx',0,3); -- Returns: NULL 

----------------------------------------------------------------------------------------
Revision History:
 Rev 00 - 20160309 - Completely re-designed - Alan Burstein
****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN
WITH
FindString1 AS -- collect all instances of @SearchString1
(
  SELECT rn = ROW_NUMBER() OVER (ORDER BY position), position
  FROM dbo.NGrams8k(@String,DATALENGTH(@SearchString1))
  WHERE token = @SearchString1
),
FindString2 AS
(
  SELECT rn = ROW_NUMBER() OVER (ORDER BY position), position
  FROM dbo.NGrams8k(@String,DATALENGTH(@SearchString2))
  WHERE token = @SearchString2
),
loc(x, p) AS
( -- ISNULL(MAX(),NULL) will return a NULL when there's no matches (instead of 0 rows)
  SELECT 1, MAX(position)+DATALENGTH(@SearchString1)
  FROM FindString1 
  WHERE rn = @S1Pos
  UNION ALL
  SELECT 2, MAX(position)
  FROM FindString2 
  WHERE rn = @S2Pos
),
pos(s,e) AS -- Unpivot the values to put start position(s) & end position(e) in one row
(
  SELECT MAX(CASE x WHEN 1 THEN p END), MAX(CASE x WHEN 2 THEN p END)
  FROM loc
)
SELECT NewString = ISNULL(MAX(SUBSTRING(@string,s,e-s)),NULL) -- Always return something
FROM pos
WHERE (@S1Pos > 0 AND @S2Pos > 0) AND 0 <= e-s;
GO