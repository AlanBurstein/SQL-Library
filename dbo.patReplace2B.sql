IF OBJECT_ID('dbo.patReplace2B', 'IF') IS NOT NULL DROP FUNCTION dbo.patReplace2B;
GO
CREATE FUNCTION dbo.patReplace2B
(
  @string  varchar(max),
  @pattern varchar(50),
  @replace varchar(20)
) 
/*****************************************************************************************
Purpose:
 Given a string (@string), a pattern (@pattern), and a replacement character (@replace)
 patReplace2B will replace any character in @string that matches the @Pattern parameter 
 with the character, @replace.

Usage:
--===== Basic Syntax Example
 SELECT pr.NewString
 FROM dbo.patReplace2B(@String,@Pattern,@Replace);

--===== Replace numeric characters with a "*"
 SELECT pr.NewString
 FROM dbo.patReplace2B('My phone number is 555-2211','[0-9]','*') pr;

--==== Using againsts a table
 DECLARE @table TABLE(OldString varchar(40));
 INSERT @table VALUES 
 ('Call me at 555-222-6666'),
 ('phone number: (312)555-2323'),
 ('He can be reached at 444.665.4466');
 SELECT t.OldString, pr.NewString
 FROM @table t
 CROSS APPLY dbo.patReplace2B(t.oldstring,'[0-9]','*') pr;

 Programmer Notes:
 1. Required SQL Server 2008+
 2. @Pattern IS case sensitive but can be easily modified to make it case insensitive
 3. There is no need to include the "%" before and/or after your pattern since since we 
    are evaluating each character individually
 4. Certain special characters, such as "$" and "%" need to be escaped with a "/"
    like so: [/$/%]

Revision History:
 Rev 00 - 10/27/2014 Initial Development - Alan Burstein

 Rev 01 - 10/29/2014 Mar 2007 - Alan Burstein
        - Redesigned based on the dbo.STRIP_NUM_EE by Eirikur Eiriksson
          (see: http://www.sqlservercentral.com/Forums/Topic1585850-391-2.aspx)
        - change how the cte tally table is created 
        - put the include/exclude logic in a CASE statement instead of a WHERE clause
        - Added Latin1_General_BIN Colation
        - Add code to use the pattern as a parameter.

 Rev 02 - 20141106
        - Added final performane enhancement (more cudo's to Eirikur Eiriksson)
        - Put 0 = PATINDEX filter logic into the WHERE clause

Rev 03  - 20150516
        - Updated to deal with special XML characters

Rev 04  - 20170320
        - changed @replace from char(1) to varchar(1) to address how spaces are handled

2b(max) - 20171116 - varchar(max) version created using ngrams2b
*****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN
WITH
E1(n) AS (SELECT 1 FROM (VALUES (1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) AS E(n)), -- 10
E3(n) AS (SELECT 1 FROM E1 a CROSS JOIN E1 b CROSS JOIN E1 c CROSS JOIN E1 d), -- 10,000
iTally(N) AS 
(
  SELECT TOP (LEN(@String)) ROW_NUMBER() OVER (ORDER BY (SELECT 1))
  FROM E3 a CROSS JOIN E3 b CROSS JOIN E3 c CROSS JOIN E3 d --100,000,000,000,000
)
SELECT NewString = ((
  SELECT
    CASE 
      WHEN PATINDEX(@Pattern,SUBSTRING(@String COLLATE Latin1_General_BIN,N,1)) = 0
      THEN SUBSTRING(@String,N,1)
      ELSE @replace
    END
  FROM iTally
  FOR XML PATH(''), TYPE
).value('.[1]','varchar(8000)'));
GO