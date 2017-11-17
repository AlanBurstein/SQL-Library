
IF OBJECT_ID('dbo.patindexAB') IS NOT NULL DROP FUNCTION dbo.patindexAB;
GO
CREATE FUNCTION dbo.patindexAB
(
  @pattern        varchar(1000),
  @expression     varchar(8000),
  @start_position int
)
/****************************************************************************************
Purpose:
 A variation of PATINDEX that includes a start position parameter that behaves just like
 the optional CHARINDEX start_position parameter. 
 
Compatibility: 
 SQL Server 2008+, Azure SQL Database, Azure SQL Data Warehouse & Parallel Data Warehouse

Syntax:
--===== Autonomous use:
 SELECT px.pIndex
 FROM dbo.patindexAB(@pattern, @string, @start) px;

--===== Against a table:
 SELECT s.SomeString, px.pIndex
 FROM dbo.SomeTable s
 CROSS APPLY dbo.patindexAB(@pattern, s.SomeString, @start) px;

Parameters:
 @pattern = A character expression containing the sequence to find. Wildcard characters
            can be used; however, the % character must come before and follow pattern 
            (except when searching for first or last characters). @pattern is limited to
            8000 characters.
 @string  = The string to evaluate such as a variable, literal, expression or column.
 @start   = An integer expression at which the search starts. If @start less than 1 the
            the search starts at the beginning of @string.

Returns: 
 pIndex = int; the starting position of @pattern within @string with the search beginning
          at @start. 

------------------------------------------------------------------------------------------
Developer Notes:
!!!!!!!! NOTE THAT select charindex('',''), patindex('','') RETURNS: 0,1


 1. As of 20170930, I have not tested this on varchar(max), or nvarchar. patindexAB was 
    written for varchar(8000) but can be easily modified for nvarchar or varchar(max).

 2. Except for the additional @start parameter, patindexAB was developed to behave exactly
    like PATINDEX. For more about PATINDEX see: https://goo.gl/4wH5sF

 3. Note the last expression in the function: 
    @start*LEN(LEFT(@string,0))*LEN(LEFT(@pattern,0))*0

    This expression guarantees that patindexAB returns NULL when any parameter is null and
    is necessary to make the claim that patindexAB's @start behaves EXEACTLY like 
    CHARINDEX's start_position parameter when the function receives a NULL input. 

		This expression can be changed to just 0  for a 10-15% performance gain but the function
    will return a 0 instead of a NULL when @string, @pattern or @start are NULL. This is 
    acceptable if you are sure that @string, @pattern and @start will never be null.
 
 4. patindexAB is deterministic; for more about determinism see: https://goo.gl/kzqkk7

 5. Sanity Check
    Using getnumsAB (found here: https://goo.gl/xJK6xk) the following test can be ran to
    compare patindexAB's @start to CHARINDEX's start_position when:
      A. @start is negative, positive, 0 or NULL
      B. @string has a value, is blank or is NULL
      C. @start has a value, is blank or is NULL          

  --===== The Query:
    select N, s.string, p.pattern, [charindex] = charindex(p.pattern, s.string, N), pIndex
    from (values ('xx1x1xxx'),(null),('')) s(string)
    cross join (values ('1'),(null),('')) p(pattern)
    cross apply (select n1 from dbo.GetNumsAB(-2, 6, 1, 1) union all select null ) as t(n)
    cross apply dbo.patindexAB('%'+p.pattern+'%', s.string, N)
    order by isnull(t.N,10), p.pattern desc, s.string;

------------------------------------------------------------------------------------------
Examples:
--===== against a variable; find a number followed by two letters
 DECLARE @string varchar(100) = 'this is the 1st book I bought';
  SELECT position 
  FROM dbo.patindexAB('%[0-9][a-z][a-z]%',@string,1);

--===== against a table; find the first instance of "Mr." or "Dr." in a table.
 DECLARE @table TABLE (SomeID int, SomeString varchar(100));
 INSERT @table VALUES(1, 'Hello Mr. Jones'),(2, 'Oh, Hi Dr. Smith!'),(3, 'Hey Steve');

 SELECT t.SomeID, Position
 FROM @table t
 CROSS APPLY dbo.patindexAB('%[MD]r.%', t.SomeString, 1);

------------------------------------------------------------------------------------------
Revision History:
 Rev 00 - 20160310 - Alan Burstein - Initial Development
 Rev 01 - 20171001 - Alan Burstein - Changed the ISNULL value from 0 to: 
                                     @start*LEN(LEFT(@string,0))*0
                                     This will cause the functino to return a NULL when
                                     @string or @start are null. 
****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN
SELECT pIndex = ISNULL(NULLIF(PATINDEX(v.pat,SUBSTRING(v.ex,v.sp,8000)),0)+
								CASE WHEN v.sp<1 THEN 0 ELSE (v.sp * SIGN(LEN(LEFT(v.pat,1))))-1 END, -- outermost parentheses not required
                0 * LEN(LEFT(v.ex,0)) * LEN(LEFT(v.pat,0)) * v.sp ) -- designed so that the isnull expression returns 0 or NULL
FROM (VALUES (@pattern, @expression, @start_position)) v(pat,ex,sp)
GO -- note, also testing non-matches

-- SANITY CHECK 1
------------------------------------------------------------------------------------------
-- Run with both where clauses; the 1st to demo no hits, 2nd to compare start_position
select
  N,
  s.string,
  p.pattern,
  p.expressionToFind,
  [charindex] = charindex(p.expressionToFind, s.string, N),
  [patindex]  = patindex(p.pattern, s.string),
	pIndex
from (values ('xx1x1xxx'),(null),('')) s(string)
cross apply (values (-2),(-1),(0),(1),(2),(3),(4),(5),(6),(null)) as t(n)
cross join  (values ('1','%1%'),('x','%x%'),(null,null),('',''),('z','%z%'))
  as p(expressionToFind, pattern)
cross apply dbo.patindexAB(p.pattern, s.string, N)
where charindex(p.expressionToFind, s.string, N) <> pIndex and s.string + p.pattern <> '' 
--where patindex(p.pattern, s.string) <> pIndex 
order by isnull(t.N,10), p.pattern desc, s.string;

-- !!! THE FIRST AND SECOND WHERE CLAUSES ABOVE HELP UNDERSTAND THE ONLY DIFF:
-- patindexAB('','',<1+>) = charindex('','',<anything>) = 0 when start_position > 0; patindexAB('','',<0->)=0
-- note: select charindex('',''), patindex('','') = 0,1
;

-- SANITY CHECK 2: PATINDEXAB OVERLAPP TEST
------------------------------------------------------------------------------------------
-- We want charindex & pIndex to be = (patindex wont be; it has no start_position.) 
-- Also, when string and pattern are blank, pindex is 0 by design (see above)
select string = 'abc123', * 
from (values (1),(3),(4),(5),(6)) x(n)
cross join (values ('%[0-9][0-9][0-9]%'), ('%[0-9][0-9]%'), ('%[0-9]%')) p(p)
cross apply dbo.patindexAB(p.p, 'abc123',  x.n)
order by x.n;

-- MORE!!!
------------------------------------------------------------------------------------------
SELECT * FROM dbo.patindexAB('%[^a-z]%', 'abc123',  -10);
SELECT patindex('%[^a-z]%', 'abc123');

SELECT * FROM dbo.patindexAB('[^a-z]%', 'abc123',  -10);
SELECT patindex('[^a-z]%', 'abc123');
GO

-- PERFORMANCE TEST
------------------------------------------------------------------------------------------
set nocount on;
if object_id('tempdb..#strings') is not null drop table #strings;
go

declare @rows int = 100000;

select top (@rows) 
  somestring = 
    isnull(cast(replicate(newid(), abs(checksum(newid())%2)+1) as varchar(100)),'')
into #strings
from sys.all_columns a, sys.all_columns b;
go

print 'charindex'+char(13)+char(10)+replicate('-',50);
go
declare @st datetime = getdate(), @x tinyint;
  select @x = charindex('-A', somestring)
  from #strings;
print datediff(ms, @st, getdate());
go 5

print char(13)+char(10)+'patindex'+char(13)+char(10)+replicate('-',50);
go
declare @st datetime = getdate(), @x tinyint;
  select @x = patindex('%-A%', somestring)
  from #strings;
print datediff(ms, @st, getdate());
go 5

print char(13)+char(10)+'patindexAB'+char(13)+char(10)+replicate('-',50);
go
declare @st datetime = getdate(), @x tinyint;
  select @x = pIndex
  from #strings
  cross apply dbo.patindexAB('%-A%', somestring,0);
print datediff(ms, @st, getdate());
go 5



/*
charindex
--------------------------------------------------
Beginning execution loop
60
53
54
Batch execution completed 3 times.

patindex
--------------------------------------------------
Beginning execution loop
70
67
66
Batch execution completed 3 times.

patindexAB
--------------------------------------------------
Beginning execution loop
90
90
86
Batch execution completed 3 times.
*/

