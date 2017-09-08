IF OBJECT_ID('dbo.RemoveDupChar8K') IS NOT NULL
DROP FUNCTION dbo.RemoveDupChar8K
GO
CREATE FUNCTION dbo.RemoveDupChar8K(@string varchar(8000), @char char(1))
RETURNS TABLE WITH SCHEMABINDING AS RETURN
/****************************************************************************************
Purpose:
 Replaces multiple spaces with one space.

Compatibility: 
 SQL Server 2005+

Syntax:
 SELECT t.string, rd.newString
 FROM dbo.someTable t
 CROSS APPLY dbo.RemoveDupChar8K(@string) rd

Parameters:
 @string - varchar(8000); the input string to clean duplicate spaces from

Return Types:
 inline Table Value Function returns:
 newString = varchar(8000)

Developer Notes:
 1. The code is based originated from the comments from this SQLServerCentral.com thread: 
    https://goo.gl/ZhYLJT but removes ANY character. After a lot of performance testing I
    concluded that there virtually no performance impact in modifying this code to accept
    a parameter the duplicate character to elimininate. 

 2. RemoveDupChar8K is an Inline Table Valued Function (iTVF) that performs the same
    task as a scalar user defined function (UDF) except that it requires the APPLY table 
    operator. Note the usage examples below and See this article for more details: 
    http://www.sqlservercentral.com/articles/T-SQL/91724/
	
    As an iTVF, the function will be slightly more complicated to use than a scalar UDF 
    but will yeild much better performance. Also, unlike a scalar UDF, RemoveDupChar8K
    doesn't prevent the query optimizer from generating a parallel execution plan. When
    testing against a scalar udf using identical logic, RemoveDupChar8K was ~30% faster.
		
Examples:

--===== #1: Remove Duplicate Spaces
 DECLARE @string varchar(8000) = '1 space 2 space  whitespace    blue space     !'
 SELECT NewString FROM dbo.RemoveDupChar8K(@string, char(32));

--===== #2: Against a table
 DECLARE @sometable table (someText varchar(100));
 INSERT @sometable VALUES('Set-Based is great!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');

 SELECT t.someText, rd.newString
 FROM @sometable t
 CROSS APPLY dbo.RemoveDupChar8K(t.someText, '!') rd;
----------------------------------------------------------------------------------------
Revision History:
 Rev 00 - 20170907 - Initial Creation - Alan Burstein
****************************************************************************************/
SELECT NewString = 
 replace(replace(replace(replace(replace(replace(replace(
 @string COLLATE LATIN1_GENERAL_BIN,
  replicate(@char,33), @char), --33
  replicate(@char,17), @char), --17
  replicate(@char,9 ), @char), -- 9
  replicate(@char,5 ), @char), -- 5
  replicate(@char,3 ), @char), -- 3 
  replicate(@char,2 ), @char), -- 2
  replicate(@char,2 ), @char); -- 2
GO

/* SANITY CHECK

declare @sometable table (string varchar(8000), stringLen smallint identity);
insert @sometable
select top(8000) replicate('_', row_number() over (order by (select 1))) 
from sys.all_columns a, sys.all_columns b;

-- Testing
select 
  oldString    = string,
	oldStringLen = stringLen,
	newString,
	newStringLen = len(newString)
from @sometable t
cross apply dbo.RemoveDupChar8K(t.string, '_')
order by stringLen;

  --'_________________________________','_'), -- 33
  --'_________________','_'), --17
  --'_________','_'), -- 9
  --'_____','_'), -- 5
  --'___','_'), -- 3 
  --'__','_'), -- 2
  --'__','_'); -- 2
*/;

/* Performance Testing

USE tempdb;
GO
IF OBJECT_ID('dbo.SpaceTest') IS NOT NULL DROP TABLE dbo.SpaceTest;
GO
CREATE TABLE dbo.SpaceTest
    (
    Data VARCHAR(4000) NOT NULL
    );
GO
INSERT  dbo.SpaceTest
SELECT  TOP (10000)
        SPACE(4000)
FROM    master.sys.allocation_units A1,
        master.sys.allocation_units A2,
        master.sys.allocation_units A3,
        master.sys.allocation_units A4;
GO

SET NOCOUNT ON;
SET STATISTICS TIME ON;
GO

DECLARE @BitBucket VARCHAR(4000);

SELECT @BitBucket = --dbo.fn_CleanUp_MichaelMeierruth_MKII(Data)
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Data COLLATE LATIN1_GENERAL_BIN,
      '                                 ',' '),
      '                 ',' '),
      '         ',' '),
      '     ',' '),
      '   ',' '),
      '  ',' '),
      '  ',' ')
FROM dbo.SpaceTest;
GO 3

DECLARE @BitBucket VARCHAR(4000);

SELECT @BitBucket = rd.newString
FROM dbo.SpaceTest s
CROSS APPLY dbo.RemoveDupChar8K(s.[Data], char(32)) rd
GO 3

SET STATISTICS TIME OFF;

DROP TABLE dbo.SpaceTest;
*/;

/* Results:
Beginning execution loop
 SQL Server Execution Times:
   CPU time = 125 ms,  elapsed time = 120 ms.

 SQL Server Execution Times:
   CPU time = 125 ms,  elapsed time = 118 ms.

 SQL Server Execution Times:
   CPU time = 110 ms,  elapsed time = 115 ms.
Batch execution completed 3 times.


Beginning execution loop
 SQL Server Execution Times:
   CPU time = 109 ms,  elapsed time = 119 ms.

 SQL Server Execution Times:
   CPU time = 125 ms,  elapsed time = 126 ms.

 SQL Server Execution Times:
   CPU time = 125 ms,  elapsed time = 125 ms.
Batch execution completed 3 times.
*/