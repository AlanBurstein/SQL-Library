IF OBJECT_ID('dbo.firstOfQuarter') IS NOT NULL DROP FUNCTION dbo.firstOfQuarter;
GO
CREATE FUNCTION dbo.firstOfQuarter (@date datetime, @quarters smallint)
/*****************************************************************************************
Purpose:
 Accepts an input date (@date) firstOfQuarter will return the beginning of the quarter in 
 datetime format. When @quarters is zero the function returns the beginning of the current
 quarter, when @quarters is a positive integer greater than zero it returns the beginning 
 of the quarter that many quarters ahead, when it's a negative value it returns the 
 beginning of the quarter that many quarters ago. 

Compatibility:
 SQL Server 2005+, Azure SQL Database

Syntax:
--===== Autonomous use
 SELECT f.quarterStart
 FROM dbo.firstOfQuarter(@date, @quarters) f;

--===== Use against a table
 SELECT st.someDateCol, f.quarterStart
 FROM SomeTable st
 CROSS APPLY dbo.firstOfQuarter(st.someDateCol, 5) f;

Parameters:
 @date     = datetime; Input date to evaluate. 
 @quarters = smallint; Number of quarters ahead (when positive) or quarters back 
            (when negative)

Return Types:
 Inline Table Valued Function returns:
   quarterStart = datetime; the return value in the form of YYYY-MM-DD 00:00:00.000
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
 
 3. When @date or @quarters is NULL the function will return a NULL value

Examples:
--==== Basic use ->
  DECLARE @date datetime = getdate();

  SELECT f.quarterStart FROM dbo.firstOfQuarter(@date,  0) f; -- first of this quarter
  SELECT f.quarterStart FROM dbo.firstOfQuarter(@date,  1) f; -- first of next quarter
  SELECT f.quarterStart FROM dbo.firstOfQuarter(@date, -1) f; -- first of last quarter

--==== against a table ->
BEGIN
  DECLARE @table TABLE (someDate date NULL);
  INSERT @table VALUES ('20180106'),('20180516'),('20171211');

  --  THIS quarter
  SELECT q = 'current', t.someDate, f.quarterStart
  FROM @table t
  CROSS APPLY dbo.firstOfQuarter(t.someDate, 0) f;

  -- NEXT quarter
  SELECT q = 'next', t.someDate, f.quarterStart
  FROM @table t
  CROSS APPLY dbo.firstOfQuarter(t.someDate, 1) f;

  -- 2 QUARTERS BACK
  SELECT q = '2 Back', t.someDate, f.quarterStart
  FROM @table t
  CROSS APPLY dbo.firstOfQuarter(t.someDate, -2) f;
END;

--==== Returns:
  q       someDate   quarterStart
  ------- ---------- -----------------------
  current 2018-01-06 2018-01-01 00:00:00.000
  current 2018-05-16 2018-04-01 00:00:00.000
  current 2017-12-11 2017-10-01 00:00:00.000
  
  q       someDate   quarterStart
  ----    ---------- -----------------------
  next    2018-01-06 2018-04-01 00:00:00.000
  next    2018-05-16 2018-07-01 00:00:00.000
  next    2017-12-11 2018-01-01 00:00:00.000
  
  q       someDate   quarterStart
  ------  ---------- -----------------------
  2 Back  2018-01-06 2017-07-01 00:00:00.000
  2 Back  2018-05-16 2017-10-01 00:00:00.000
  2 Back  2017-12-11 2017-04-01 00:00:00.000

---------------------------------------------------------------------------------------
Revision History:
 Rev 00 - 20180614 - Initial Creation - Alan Burstein
****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN
SELECT quarterStart = dateadd(qq, datediff(qq, 0, @date) + @quarters, 0)
GO