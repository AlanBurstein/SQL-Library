IF OBJECT_ID('dbo.firstOfWeek') IS NOT NULL DROP FUNCTION dbo.firstOfWeek;
GO
CREATE FUNCTION dbo.firstOfWeek (@date datetime, @weeks smallint)
/*****************************************************************************************
Purpose:
 Accepts an input date (@date) firstOfWeek will return the beginning of the work week 
 (Monday) in datetime format. When @weeks is zero the function returns the beginning of 
 the week, when @weeks is a positive interger greater than zero it returns the beginning 
 of the week that many weeks ahead, when it's a negative value it returns the beginning of 
 the week that many weeks ago. 

Compatibility:
 SQL Server 2005+, Azure SQL Database

Syntax:
--===== Autonomous use
 SELECT f.weekStart
 FROM dbo.firstOfWeek(@date, @weeks) f;

--===== Use against a table
 SELECT st.someDateCol, f.weekStart
 FROM SomeTable st
 CROSS APPLY dbo.firstOfWeek(st.someDateCol, 5) f;

Parameters:
 @date = datetime; Input date to evaluate. 
 @weeks = smallint; Number of weeks ahead (when positive) or weeks back (when negative)

Return Types:
 Inline Table Valued Function returns:
   weekStart = datetime; the rerturn value in the form of YYYY-MM-DD 00:00:00.000
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
 
 3. When @date or @weeks is NULL the function will return a NULL value

Examples:
--==== Basic use ->
  DECLARE @date datetime = getdate();

  SELECT f.weekStart FROM dbo.firstOfWeek(@date,  0) f; -- start of this week
  SELECT f.weekStart FROM dbo.firstOfWeek(@date,  1) f; -- start of next week
  SELECT f.weekStart FROM dbo.firstOfWeek(@date, -1) f; -- start of last week

--==== against a table ->
  DECLARE @table TABLE (someDate date NULL);
  INSERT @table VALUES ('20180106'),(NULL),('20170511');
  
  SELECT t.someDate, f.weekStart
  FROM @table t
  CROSS APPLY dbo.firstOfWeek(t.someDate, -10) f;

--==== Returns:
  someDate    weekStart
  ----------  -----------------------
  2018-01-06  2017-10-23 00:00:00.000
  NULL        NULL
  2017-05-11  2017-02-27 00:00:00.000

---------------------------------------------------------------------------------------
Revision History:
 Rev 00 - 20180614 - Initial Creation - Alan Burstein
****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN
SELECT weekStart = dateadd(wk,datediff(wk,0,@date)+@weeks,0);
GO






