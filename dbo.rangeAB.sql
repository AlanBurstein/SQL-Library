/*
IF OBJECT_ID('samd.addCommasToNumber') IS NOT NULL DROP FUNCTION samd.addCommasToNumber;
IF OBJECT_ID('dates.isoWeekCalendarAB','IF') IS NOT NULL DROP FUNCTION dates.isoWeekCalendarAB
IF OBJECT_ID('dates.getDimDateAB','IF') IS NOT NULL DROP FUNCTION dates.getDimDateAB;
IF OBJECT_ID('samd.patternSplit8K') IS NOT NULL DROP FUNCTION samd.patternSplit8K;
IF OBJECT_ID('dbo.randomNumbers') IS NOT NULL DROP FUNCTION dbo.randomNumbers;
GO
*/;

IF OBJECT_ID('dbo.rangeAB') IS NOT NULL DROP FUNCTION dbo.rangeAB;
GO
CREATE FUNCTION dbo.rangeAB
(
  @low  bigint, 
  @high bigint, 
  @gap  bigint,
  @row1 bit
)
/****************************************************************************************
Purpose:
 Creates up to 65,610,000 sequential numbers beginning with @low and ending with @high.
 Used to replace iterative methods such as loops, cursors and recursive CTEs to solve SQL
 problems. Based on Itzik Ben-Gan's getnums function with some tweeks and enhancements 
 and added functionality. The logic for getting rn to begin at 0 or 1 is based comes from 
 Jeff Moden's fnTally function. 

 The name range because it's similar to clojure's range function. I chose rangeAB because 
 "range" is a reserved SQL keyword.

Compatibility: 
 SQL Server 2008+ and Azure SQL Database

Syntax:
 SELECT rn, op, n1, n2 FROM dbo.rangeAB(@low,@high,@gap,@row1);

Parameters:
 @low  = a bigint that represents the lowest value for n1.
 @high = a bigint that represents the highest value for n1.
 @gap  = a bigint that represents how much n1 and n2 will increase each row; @gap also
         represents the difference between n1 and n2.
 @row1 = a bit that represents the first value of rn. When @row = 0 then rn begins
         at 0, when @row = 1 then rn will begin at 1.
 
Return Types:
 Inline Table Valued Function returns:
 rn = bigint; a row number that works just like T-SQL ROW_NUMBER() except that it can 
      start at 0 or 1 which is dictated by @row1.
 op = bigint; returns the "opposite number that relates to rn. When rn begins with 0 and
      ends with 10 then 10 is the opposite of 0, 9 the opposite of 1, etc. When rn begins
      with 1 and ends with 5 then 1 is the opposite of 5, 2 the opposite of 4, etc...
 n1 = bigint; a sequential number starting at the value of @low and incrimentingby the
      value of @gap until it is less than or equal to the value of @high.
 n2 = bigint; a sequential number starting at the value of @low+@gap and  incrimenting 
      by the value of @gap.

------------------------------------------------------------------------------------------
Developer Notes:

 1. The lowest and highest possible numbers returned are whatever is allowable by a 
    bigint. The function, however, returns no more than 65,610,000 rows (8100^2). An 
    additional cross join to L1 in the ITALLY cte will increase the limit to 
    531,441,000,000 rows (8100^3.) We limited the number of CROSS JOINS to two for a 
    cleaner execution plan but a third could be added with no performance penalty. 
 2. @gap does not affect rn, rn will begin at @row1 and increase by 1 until the last row
    unless its used in a query where a filter is applied to rn.
 3. @gap must be greater than 0 or the function will not return any rows.
 4. Keep in mind that when @row1 is 0 then the highest row-number will be the number of
    rows returned minus 1
 5. If you only need is a sequential set beginning at 0 or 1 then, for best performance
    use the RN column. Use N1 and/or N2 when you need to begin your sequence at any 
    number other than 0 or 1 or if you need a gap between your sequence of numbers. 
 6. Although @gap is a bigint it must be a positive integer or the function will
    not return any rows.
 7. The function will not return any rows when one of the following conditions are true:
      * any of the input parameters are NULL
      * @high is less than @low 
      * @gap is not greater than 0
    To force the function to return all NULLs instead of not returning anything you can
    add the following code to the end of the query:

      UNION ALL 
      SELECT NULL, NULL, NULL, NULL
      WHERE NOT (@high&@low&@gap&@row1 IS NOT NULL AND @high >= @low AND @gap > 0)

    This code was excluded as it adds a ~5% performance penalty.
 8. There is no performance penalty for sorting by rn ASC; there is a large performance 
    penalty for sorting in descending order WHEN @row1 = 1; WHEN @row1 = 0
    If you need a descending sort the use op in place of rn then sort by rn ASC. 

Best Practices:
--===== 1. Using RN (rownumber)
 -- (1.1) The best way to get the numbers 1,2,3...@high (e.g. 1 to 5):
 SELECT RN FROM dbo.rangeAB(1,5,1,1);
 -- (1.2) The best way to get the numbers 0,1,2...@high-1 (e.g. 0 to 5):
 SELECT RN FROM dbo.rangeAB(0,5,1,0);

--===== 2. Using OP for descending sorts without a performance penalty
 -- (2.1) The best way to get the numbers 5,4,3...@high (e.g. 5 to 1):
 SELECT op FROM dbo.rangeAB(1,5,1,1) ORDER BY rn ASC;
 -- (2.2) The best way to get the numbers 0,1,2...@high-1 (e.g. 5 to 0):
 SELECT op FROM dbo.rangeAB(1,6,1,0) ORDER BY rn ASC;

--===== 3. Using N1
 -- (3.1) To begin with numbers other than 0 or 1 use N1 (e.g. -3 to 3):
 SELECT N1 FROM dbo.rangeAB(-3,3,1,1);
 -- (3.2) ROW_NUMBER() is built in. If you want a ROW_NUMBER() include RN:
 SELECT RN, N1 FROM dbo.rangeAB(-3,3,1,1);
 -- (3.3) If you wanted a ROW_NUMBER() that started at 0 you would do this:
 SELECT RN, N1 FROM dbo.rangeAB(-3,3,1,0);

--===== 4. Using N2 and @gap
 -- (4.1) To get 0,10,20,30...100, set @low to 0, @high to 100 and @gap to 10:
 SELECT N1 FROM dbo.rangeAB(0,100,10,1);
 -- (4.2) Note that N2=N1+@gap; this allows you to create a sequence of ranges.
 --       For example, to get (0,10),(10,20),(20,30).... (90,100):
 SELECT N1, N2 FROM dbo.rangeAB(0,90,10,1);
 -- (4.3) Remember that a rownumber is included and it can begin at 0 or 1:
 SELECT RN, N1, N2 FROM dbo.rangeAB(0,90,10,1);

Usage Examples:
--===== 1. Generating Sample data (using rangeAB to create "dummy rows")
 -- The query below will generate 10,000 ids and random numbers between 50,000 and 500,000
 SELECT
   someId    = r.rn,
   someNumer = ABS(CHECKSUM(NEWID())%450000)+50001 
 FROM rangeAB(1,10000,1,1) r;

--===== 2. Create a series of dates; rn is 0 to include the first date in the series
 DECLARE @startdate DATE = '20180101', @enddate DATE = '20180131';

 SELECT r.rn, calDate = DATEADD(dd, r.rn, @startdate)
 FROM dbo.rangeAB(1, DATEDIFF(dd,@startdate,@enddate),1,0) r;
 GO

--===== 3. Splitting (tokenizing) a string with fixed sized items
 -- given a delimited string of identifiers that are always 7 characters long
 DECLARE @string VARCHAR(1000) = 'A601225,B435223,G008081,R678567';

 SELECT
   itemNumber = r.rn, -- item's ordinal position 
   itemIndex  = r.n1, -- item's position in the string (it's CHARINDEX value)
   item       = SUBSTRING(@string, r.n1, 7) -- item (token)
 FROM dbo.rangeAB(1, LEN(@string), 8,1)  r;
 GO

--===== 4. Splitting (tokenizing) a string with random delimiters
 DECLARE @string VARCHAR(1000) = 'ABC123,999F,XX,9994443335';

 SELECT
   itemNumber = ROW_NUMBER() OVER (ORDER BY r.rn), -- item's ordinal position 
   itemIndex  = r.n1+1, -- item's position in the string (it's CHARINDEX value)
   item       = SUBSTRING
               (
                 @string,
                 r.n1+1,
                 ISNULL(NULLIF(CHARINDEX(',',@string,r.n1+1),0)-r.n1-1, 8000)
               ) -- item (token)
 FROM dbo.rangeAB(0,DATALENGTH(@string),1,1) r
 WHERE SUBSTRING(@string,r.n1,1) = ',' OR r.n1 = 0;
 -- logic borrowed from: http://www.sqlservercentral.com/articles/Tally+Table/72993/

--===== 5. Grouping by a weekly intervals
 -- 5.1. how to create a series of start/end dates between @startDate & @endDate
 DECLARE @startDate DATE = '1/1/2015', @endDate DATE = '2/1/2015';
 SELECT 
   WeekNbr   = r.RN,
   WeekStart = DATEADD(DAY,r.N1,@StartDate), 
   WeekEnd   = DATEADD(DAY,r.N2-1,@StartDate)
 FROM dbo.rangeAB(0,datediff(DAY,@StartDate,@EndDate),7,1) r;
 GO

 -- 5.2. LEFT JOIN to the weekly interval table
 BEGIN
  DECLARE @startDate datetime = '1/1/2015', @endDate datetime = '2/1/2015';
  -- sample data 
  DECLARE @loans TABLE (loID INT, lockDate DATE);
  INSERT @loans SELECT r.rn, DATEADD(dd, ABS(CHECKSUM(NEWID())%32), @startDate)
  FROM dbo.rangeAB(1,50,1,1) r;

  -- solution 
  SELECT 
    WeekNbr   = r.RN,
    WeekStart = dt.WeekStart, 
    WeekEnd   = dt.WeekEnd,
    total     = COUNT(l.lockDate)
  FROM dbo.rangeAB(0,datediff(DAY,@StartDate,@EndDate),7,1) r
  CROSS APPLY (VALUES (
    CAST(DATEADD(DAY,r.N1,@StartDate) AS DATE), 
    CAST(DATEADD(DAY,r.N2-1,@StartDate) AS DATE))) dt(WeekStart,WeekEnd)
  LEFT JOIN @loans l ON l.lockDate BETWEEN  dt.WeekStart AND dt.WeekEnd
  GROUP BY r.RN, dt.WeekStart, dt.WeekEnd ;
 END;
 
--===== 6. Identify the first vowel and last vowel in a along with their positions
 DECLARE @string VARCHAR(200) = 'This string has vowels';

 SELECT TOP(1) position = r.rn, letter = SUBSTRING(@string,r.rn,1)
 FROM dbo.rangeAB(1,LEN(@string),1,1) r
 WHERE SUBSTRING(@string,r.rn,1) LIKE '%[aeiou]%'
 ORDER BY r.rn;

 -- To avoid a sort in the execution plan we'll use op instead of rn
 SELECT TOP(1) position = r.op, letter = SUBSTRING(@string,r.op,1)
 FROM dbo.rangeAB(1,LEN(@string),1,1) r
 WHERE SUBSTRING(@string,r.rn,1) LIKE '%[aeiou]%'
 ORDER BY r.rn;

---------------------------------------------------------------------------------------
Revision History: 
 Rev 00 - 20140518 - Initial Development - Alan Burstein
 Rev 01 - 20151029 - Added 65 rows to make L1=465; 465^3=100.5M. Updated comment section
                   - Alan Burstein
 Rev 02 - 20180613 - Complete re-design including opposite number column (op)
****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN
WITH L1(N) AS 
(
  SELECT 1
  FROM (VALUES
   (0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),
   (0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),
   (0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),
   (0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),
   (0),(0)) T(N) -- 90 values 
),
L2(N)  AS (SELECT 1 FROM L1 a CROSS JOIN L1 b), -- 8100 (90^2); belwo: 65,610,000 (8100^2)
iTally AS (SELECT rn = ROW_NUMBER() OVER (ORDER BY (SELECT 1)) FROM L2 a CROSS JOIN L2 b)
SELECT
  rn = 0,
  op = (@high-@low)/@gap,
  n1 = @low,
  n2 = @gap+@low
WHERE @row1 = 0 AND @high&@low&@gap IS NOT NULL AND @high >= @low AND @gap > 0
UNION ALL -- ISNULL required in the TOP statement for error handling purposes
SELECT TOP (ABS((ISNULL(@high,0)-ISNULL(@low,0))/ISNULL(@gap,0)+ISNULL(@row1,1)))
  rn = i.rn,
  op = (@high-@low)/@gap+(2*@row1)-i.rn,
  n1 = (i.rn-@row1)*@gap+@low,
  n2 = (i.rn-(@row1-1))*@gap+@low
FROM iTally i
WHERE @high&@low&@gap&@row1 IS NOT NULL AND @high >= @low AND @gap > 0
ORDER BY rn;
GO