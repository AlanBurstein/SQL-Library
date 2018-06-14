IF OBJECT_ID('dbo.getDimDateAB','IF') IS NOT NULL DROP FUNCTION dbo.getDimDateAB;
GO
CREATE FUNCTION dbo.getDimDateAB
(
  @startDate  date, 
  @endDate    date,
  @descending bit   -- 0 for ascending order, 1 for descending
)
/****************************************************************************************
Purpose:
 Takes a start date and end date input parameter (@startDate & @endDate) and returns a 
 virtual "date dimension table" beginning with @startDate and ending with @endDate. 
 
Compatibility: 
 SQL Server 2008+ and Azure SQL Database

Syntax:
 SELECT * FROM dbo.GetDimDateAB(@startDate,@endDate);

Parameters:
 @startDate      = The first date in the sequence of dates.
 @endDate        = The last date in the sequence of dates.
 @Descending     = If @Descending is 0 then the result set is sorted in Ascending order,
                   when its 1 the result set is sorted in descending order. The advantage
                   of using the @Descending parameter is that the results are returned in
                   the desired order without a sort operator in the query plan.

Returns:
 SeqNbr         = bigint; a sequential number beginning with 1; can be used to sort by
 DateID         = int; a sequential number that represents a dateid formatted as YYYYMMDD
 DateValue      = date; date field formatted as YYYY-MM-DD
 CalYearNbr     = int; that represents only the calendar year portion of DateValue
 DayOfYearNbr   = int; represents the day of the year 1 through (365 | 366)
 QuarterNbr     = tinyint; represents the quarter (1,2,3 or 4)
 MonthNbr       = tinyint; represents the month number of the year (1,2,3,4...12)
 MonthTxt       = nvarchar(30); the text value for the represented month 
 DayOfMonthNbr  = tinyint; represents the day of the month (1... EOMonth)
 WeekOfYearNbr  = tinyint; represents the week of the year (stars on Saturday)
 ISOWeekNbr     = tinyint; represents the ISO week (starts on Monday)
 DayOfWeekNbr   = tinyint; represents the day of week (Sunday=1)
 DayOfWeekTxt   = nvarchar(30); text value for the day of the week (Monday, Tuesday...)
 MonthYearTxt   = nvarchar(35); text value for the month of the year
 YearQuarterTxt = nvarchar(8); text value that represents the year+quarter 
                  (e.g. Y2000Q1 for Quarter #1, Year 2000)
 IsLeapYear     = bit; true/false for if the YearNbr is a leap year
 IsWeekend      = bit; true/false for if the current row is a weekend
 IsEndOfMonth   = bit; true/false for if the current row represents the end of month

Developer Notes: 
 1. Uses GetNumsAB
 2. @endDate must be equal or greater than @startDate
 3. The function does not include an presentation ORDER BY clause but the observed
    behaivior is that the function returns it's result set sorted by in ascending
	order. To guarantee an ascending sort order sort by SeqNbr; sorting 
	by any other field will result in a very expensive sort operator in the query plan.
	Sorting by SeqNbr will also generate a sort operator in the query plan.
 4. Performs at about 1/2 as fast as a well-indexed dim_date or calendar table but 
    requires no space and generates 0 reads, scans, etc. 
   
Examples:
 --===== 1. Get a datedim table between the dates 1/1/2000 and 3/1/2000:
 SELECT * FROM dbo.GetDimDateAB('1/1/2000','1/15/2000',0) ORDER BY SeqNbr; -- Ascending
 SELECT * FROM dbo.GetDimDateAB('1/1/2000','1/15/2000',1) ORDER BY SeqNbr; -- Descending

 --===== 2. Same as Example 1 but filtered for weekdays only (assuming @@datefirst = 7):
 SELECT * 
 FROM dbo.GetDimDateAB('1/1/2000', '1/16/2000', 0)
 WHERE DayOfWeekNbr BETWEEN 2 AND 5;

---------------------------------------------------------------------------------------
Revision History:
 Rev 00 - 20150518 - Alan Burstein - Initial Development
 Rev 01 - 20180608 - Alan Burstein - Removed fiscal year, fixed 
****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN
SELECT
  SeqNbr         = rn,
  DateID         = CAST(REPLACE(DateValue,'-','') AS int),
  DateValue,
  CalYearNbr     = YEAR(DateValue),
  DayOfYearNbr   = DATEPART(DAYOFYEAR,DateValue),
  QuarterNbr     = CAST(((DATEPART(M,DateValue)-1)/3)+1 AS tinyint),
  MonthNbr       = CAST(MONTH(DateValue) AS tinyint),
  MonthTxt       = DATENAME(M,DateValue),
  MonthTxt3      = LEFT(DATENAME(M,DateValue),3),
  DayOfMonthNbr  = CAST(DATEPART(D,DateValue) AS tinyint),
  WeekOfYearNbr  = CAST(DATEPART(WEEK,DateValue) AS tinyint),
  ISOWeekNbr     = CAST(DATEPART(ISO_WEEK,DateValue) AS tinyint),
  DayOfWeekNbr   = CAST(DATEPART(W,DateValue) AS tinyint),
  DayOfWeekTxt   = DATENAME(W,DateValue),
  DayOfWeekTxt3  = LEFT(DATENAME(W,DateValue),3),
  MonthYearTxt   = DATENAME(M,DateValue)+' '+CAST(DATEPART(YEAR,DateValue) AS char(4)),
  YearQuarterTxt = 'Y'+CAST(YEAR(DateValue) AS char(4))+' '+
                   'Q'+CAST(((DATEPART(M,DateValue)-1)/3)+1 AS char(1)),
  IsLeapYear     =
    CASE 
      WHEN (YEAR(DateValue) & 3 )   > 0 THEN 0 -- Anything with 1st or 2nd bits set is not a leap year
      WHEN (YEAR(DateValue) % 400 ) = 0 THEN 1 -- Anything divisible by 400 is a leap year
      WHEN (YEAR(DateValue) % 100 ) = 0 THEN 0 -- When year%100=0 and year%400<>0 then its not a leap year
      WHEN (YEAR(DateValue) % 4 )   = 0 THEN 1 -- When year%100<>0 and year%400<>0 and year%4=0 then its a leap year
      ELSE 0
    END,
  IsWeekend      = CASE WHEN DATENAME(WEEKDAY,DateValue) IN ('Saturday','Sunday') THEN 1 ELSE 0 END,
  IsEndOfMonth   = DATEDIFF(MM,DateValue, DATEADD(dd,1,DateValue))
FROM
( 
  SELECT 
    rn, 
    DateValue = DATEADD(dd,CASE @descending WHEN 0 THEN rn ELSE op END,@startDate)
  FROM dbo.rangeAB(1, SIGN(DATEDIFF(dd,@startDate,@endDate)) -- ensures that @endDate > @startDate
                      * DATEDIFF(dd,@startDate,@endDate)+1, 1, 0)
) base;
GO