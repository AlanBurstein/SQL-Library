IF OBJECT_ID('dbo.firstOfDay') IS NOT NULL DROP FUNCTION dbo.firstOfDay;
GO
CREATE FUNCTION dbo.firstOfDay (@date datetime, @days smallint)
/*****************************************************************************************
Purpose:
 Accepts an input date (@date) firstOfDay will return the beginning of the day in datetime
 format. When @days is zero the function returns the beginning of today, when @days is a
 possitive interger greater than zero it returns the beginning of the day that many days
 ahead, when it's a negative value it returns the beginning of the day that many days ago. 

Compatibility:
 SQL Server 2005+, Azure SQL Database

Syntax:
--===== Autonomous use
 SELECT f.dayStart
 FROM dbo.firstOfDay(@date, @days) f;

--===== Use against a table
 SELECT st.someDateCol, f.dayStart
 FROM SomeTable st
 CROSS APPLY dbo.firstOfDay(st.someDateCol, 5) f;

Parameters:
 @date = datetime; Input date to evaluate. 
 @days = smallint; Number of days ahead (when positive) or days back (when negative) to go

Return Types:
 Inline Table Valued Function returns:
   dayStart = datetime; the rerturn value in the form of YYYY-MM-DD 00:00:00.000
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
 
 3. When @date or @days is NULL the function will return a NULL value

Examples:
--==== Basic use ->
  SELECT f.dayStart FROM dbo.firstOfDay(getdate(),   0) f; -- start of today
  SELECT f.dayStart FROM dbo.firstOfDay(getdate(),   1) f; -- start of the day tomorrow
  SELECT f.dayStart FROM dbo.firstOfDay(getdate(), -10) f; -- start of the day 10 days ago

--==== against a table ->
  DECLARE @table TABLE (someDate date NULL);
  INSERT @table VALUES ('20180106'),(NULL),('20170511');
  
  SELECT t.someDate, f.dayStart
  FROM @table t
  CROSS APPLY dbo.firstOfDay(t.someDate, -10) f;

--==== RESULTS:
  someDate    dayStart
  ----------  -----------------------
  2018-01-06  2017-12-27 00:00:00.000
  NULL        NULL
  2017-05-11  2017-05-01 00:00:00.000

---------------------------------------------------------------------------------------
Revision History:
 Rev 00 - 20180614 - Initial Creation - Alan Burstein
****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN
SELECT dayStart = dateadd(dd, datediff(dd, 0, @date) + @days, 0);
GO







