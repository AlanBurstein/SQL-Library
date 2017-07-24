IF OBJECT_ID('dbo.PatExclude8K', 'IF') IS NOT NULL DROP FUNCTION dbo.PatExclude8K;
GO
CREATE FUNCTION dbo.PatExclude8K
(
    @String  varchar(8000),
	@Pattern varchar(50)
) 
/*****************************************************************************************
 Purpose:
 Given a string (@String) and a pattern (@Pattern) of characters to remove, 
 remove the patterned characters from the string.

Usage:
--===== Basic Syntax Example
 SELECT CleanedString 
 FROM dbo.PatExclude8K(@String,@Pattern);

--===== Remove all but Alpha characters
 SELECT CleanedString 
 FROM dbo.SomeTable st
 CROSS APPLY dbo.PatExclude8K(st.SomeString,'%[^A-Za-z]%');

--===== Remove all but Numeric digits
 SELECT CleanedString
 FROM dbo.SomeTable st
 CROSS APPLY dbo.PatExclude8K(st.SomeString,'%[^0-9]%');

 Programmer Notes:
 1. @Pattern is not case sensitive (the function can be easily modified to make it so)
 2. There is no need to include the "%" before and/or after your pattern since since we 
	are evaluating each character individually

 Revision History:
 Rev 00 - 10/27/2014 Initial Development - Alan Burstein

 Rev 01 - 10/29/2014 Mar 2007 - Alan Burstein
		- Redesigned based on the dbo.STRIP_NUM_EE by Eirikur Eiriksson
		  (see: http://www.sqlservercentral.com/Forums/Topic1585850-391-2.aspx)
		- change how the cte tally table is created 
		- put the include/exclude logic in a CASE statement instead of a WHERE clause
		- Added Latin1_General_BIN Colation
        - Add code to use the pattern as a parameter.

 Rev 02	- 20141106
		- Added final performane enhancement (more cudo's to Eirikur Eiriksson)
		- Put 0 = PATINDEX filter logic into the WHERE clause

 Rev 03 - 20150516 - Alan Burstein
        - Updated code to deal with special XML characters

 Rev 04 - 20170427 - Alan Burstein - Changed final .value logic for text()
*****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN
WITH
E1(N) AS (SELECT N FROM (VALUES (1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) AS X(N)),
itally(N) AS 
(
  SELECT TOP(CONVERT(INT,LEN(@String),0)) ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
  FROM E1 T1 CROSS JOIN E1 T2 CROSS JOIN E1 T3 CROSS JOIN E1 T4
) 
SELECT NewString =
((
  SELECT SUBSTRING(@String,N,1)
  FROM iTally
  WHERE 0 = PATINDEX(@Pattern,SUBSTRING(@String COLLATE Latin1_General_BIN,N,1))
  FOR XML PATH(''),TYPE
).value('text()[1]','varchar(8000)'));
GO