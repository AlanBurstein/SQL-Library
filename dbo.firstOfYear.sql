IF OBJECT_ID('dbo.firstOfYear') IS NOT NULL DROP FUNCTION dbo.firstOfYear;
GO
CREATE FUNCTION dbo.firstOfYear (@date datetime, @years smallint)
/*****************************************************************************************
Purpose:
 Accepts an input date (@date) firstOfYear will return the beginning of the year in 
 datetime format. When @years is zero the function returns the beginning of the current
 year, when @years is a positive integer greater than zero it returns the beginning of the 
 year that many years ahead, when it's a negative value it returns the beginning of the 
 year that many years ago.

Compatibility:
 SQL Server 2005+, Azure SQL Database

Syntax:
--===== Autonomous use
 SELECT f.yearStart
 FROM dbo.firstOfYear(@date, @years) f;

--===== Use against a table
 SELECT st.someDateCol, f.yearStart
 FROM SomeTable st
 CROSS APPLY dbo.firstOfYear(st.someDateCol, 5) f;

Parameters:
 @date  = datetime; Input date to evaluate. 
 @years = smallint; Number of years ahead (when positive) or years back 
            (when negative)

Return Types:
 Inline Table Valued Function returns:
   yearStart = datetime; the return value in the form of YYYY-MM-DD 00:00:00.000
------------------------------------------------------------------------------------------
Developer Notes:

 1. The idea for this function came from Lynn Pettis on SQLServerCentral.com. See:
    http://www.sqlservercentral.com/blogs/lynnpettis/2009/03/25/some-common-date-routines/

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
 
 3. When @date or @years is NULL the function will return a NULL value

 4. Note that tinyint would be more appropriate for @years as there should be no need to
    go back more than 256 years. Tinyint, however, does not support negative numbers which
    are this function requires when users want to return previous years. 

 4. firstOfYear is deterministic; for more about deterministic and nondeterministic 
    functions see https://msdn.microsoft.com/en-us/library/ms178091.aspx

Examples:
--==== Basic use ->
  DECLARE @date datetime = getdate();

  SELECT f.yearStart FROM dbo.firstOfYear(@date,  0) f; -- first of this year
  SELECT f.yearStart FROM dbo.firstOfYear(@date,  1) f; -- first of next year
  SELECT f.yearStart FROM dbo.firstOfYear(@date, -1) f; -- first of last year

--==== against a table ->
BEGIN
  DECLARE @table TABLE (someDate date NULL);
  INSERT @table VALUES ('20180106'),('20100516'),('20171211'),(NULL);

  -- start of previous year
  SELECT t.someDate, f.yearStart
  FROM @table t
  CROSS APPLY dbo.firstOfYear(t.someDate, -1) f;
END;

--==== Returns:
someDate    yearStart
----------  -----------------------
2018-01-06  2017-01-01 00:00:00.000
2010-05-16  2009-01-01 00:00:00.000
2017-12-11  2016-01-01 00:00:00.000
NULL        NULL

---------------------------------------------------------------------------------------
Revision History:
 Rev 00 - 20180614 - Initial Creation - Alan Burstein
****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN
SELECT yearStart = dateadd(yy, datediff(yy, 0, @date) + @years, 0)
GO



