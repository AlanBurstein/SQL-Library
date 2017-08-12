IF OBJECT_ID('dbo.alphaOnly8K') IS NOT NULL DROP FUNCTION dbo.alphaOnly8K;
GO
CREATE FUNCTION dbo.alphaOnly8K(@pString varchar(8000))
RETURNS TABLE WITH SCHEMABINDING AS RETURN
/****************************************************************************************
Purpose:
 Given a VARCHAR(8000) or less string, returns only the alphabetical digits from the 
 input string (@pString).

Compatibility: 
 SQL Server 2008+, Azure SQL Database, Azure SQL Data Warehouse & Parallel Data Warehouse

Parameters:
 @pString = varchar(8000); Input string to be cleaned

Returns:
 AlphaOnly - varchar(8000) 

Syntax:
--===== Autonomous
 SELECT ca.AlphaOnly
 FROM dbo.AlphaOnly(@pString) ca;
--===== CROSS APPLY example
 SELECT ca.AlphaOnly
 FROM dbo.SomeTable st
 CROSS APPLY dbo.AlphaOnly(st.SomeVarcharCol) ca;
Programmer's Notes:
 1. Based on Jeff Moden/Eirikur Eiriksson's DigitsOnlyEE function. For more details see:
    https://goo.gl/Qo8rpy
 2. This is an iTVF (Inline Table Valued Function) that performs the same task as a 
    scalar user defined function (UDF) accept that it requires the APPLY table operator. 
    Note the usage examples below and see this article for more details: 
    https://goo.gl/3utbgx 
    The function will be slightly more complicated to use than a scalar UDF but will yeild
    much better performance. For example - unlike a scalar UDF, this function does not 
    restrict the query optimizer's ability generate a parallel query plan. Initial testing
    showed that the function generally gets a 
 3. AlphaOnly runs 2-4 times faster when using make_parallel() (provided that you 
    have two or more logical CPU's and MAXDOP is not set to 1 on your SQL Instance).
 4. CHECKSUM returns an INT and will return the exact number given if given an INT to 
    begin with. It's also faster than a CAST or CONVERT and is used as a performance 
    enhancer by changing the bigint of ROW_NUMBER() to a more appropriately sized INT.
 5. Another performance enhancement is using a WHERE clause calculation to prevent 
    the relatively expensive XML PATH concatentation of empty strings normally 
    determined by a CASE statement in the XML "loop".
 6. Note that AlphaOnly returns an nvarchar(max) value. If you are returning small 
    numbers consider casting or converting yout values to a numeric data type if you are 
    inserting the return value into a new table or using it for joins or comparison 
    purposes.
 8. AlphaOnly is deterministic; for more about deterministic and nondeterministic
    functions see https://msdn.microsoft.com/en-us/library/ms178091.aspx
    
Usage Examples:
--===== 1. Basic use against a literal
 SELECT ao.AlphaOnly 
 FROM dbo.AlphaOnly('xxx123abc999!!!') ao;
--===== 2. Against a table 
 DECLARE @sampleTxt TABLE (txtID int identity, txt varchar(100));
 INSERT @sampleTxt(txt) VALUES ('!!!A555A!!!'),(NULL),('AAA.999');
 SELECT txtID, OldTxt = txt, AlphaOnly
 FROM @sampleTxt st
 CROSS APPLY dbo.AlphaOnly(st.txt);
---------------------------------------------------------------------------------------
Revision History:
 Rev 00 - 20170411 - Inital Creation - Alan Burstein
****************************************************************************************/ 
WITH 
E1(N) AS (SELECT N FROM (VALUES ($),($),($),($),($),($),($),($),($),($)) x(n)), 
iTally(N) AS 
( 
  SELECT TOP (LEN(ISNULL(@pString,CHAR(32)))) 
    (CHECKSUM(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)))) 
  FROM E1 a CROSS JOIN E1 b CROSS JOIN E1 c CROSS JOIN E1 d 
) 
SELECT AlphaOnly = 
( 
  SELECT SUBSTRING(@pString,N,1) 
  FROM iTally 
  WHERE ((ASCII(SUBSTRING(@pString,N,1)) - 65) & 0x7FFF) < 26 
  OR    ((ASCII(SUBSTRING(@pString,N,1)) - 97) & 0x7FFF) < 26 
  FOR XML PATH('') 
);
GO