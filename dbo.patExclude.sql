IF OBJECT_ID('dbo.patExclude', 'IF') IS NOT NULL DROP FUNCTION dbo.patExclude;
GO
CREATE FUNCTION dbo.patExclude
(
  @string  varchar(max),
	@pattern varchar(50)
) 
/*****************************************************************************************
Purpose:
 Given a string (@string) and a pattern (@pattern) patExclude removes any character in
 @string that matches the @pattern. This is the varchar(max) version of patExclude8k
 located here: http://www.sqlservercentral.com/scripts/T-SQL/117890/

Compatibility: 
 SQL Server 2008+;

Syntax:
--===== Basic Syntax (against parameters)
 SELECT px.newString
 FROM dbo.patExclude(@string,@pattern) px;

--===== Basic Syntax (against a table)
 SELECT px.newString
 FROM dbo.someTable t
 CROSS APPLY dbo.patExclude(t.someString,@pattern) px;

Parameters:
  @string  = varchar(8000); input string to clean
  @pattern = varchar(50);   pattern that matches characters you wish to remove 

Return Types:
 Inline Table Valued Function returns:
   newString = varchar(8000); Transformed string free of characters that match @pattern

-----------------------------------------------------------------------------------------
Usage:

--===== Remove all but alpha characters
 SELECT px.newString 
 FROM dbo.SomeTable st
 CROSS APPLY dbo.patExclude(st.SomeString,'%[^0-9a-zA-Z]%') px;

--===== Remove all but numeric characters and dots
 SELECT newString
 FROM dbo.SomeTable st
 CROSS APPLY dbo.patExclude(st.SomeString,'%[^0-9.]%');

----------------------------------------------------------------------------------------
Runnable Examples:
	
--remove letters
 SELECT newString FROM dbo.patExclude('abc123!', '[a-z]'); -- Returns: 123!

-- remove numbers
 SELECT newString FROM dbo.patExclude('abc123!', '[0-9]'); -- Returns: abc!

-- only return letters and numbers
 SELECT newString FROM dbo.patExclude('###abc123!!!', '[^0-9a-z]'); -- Returns: abc123

-- Remove spaces
 SELECT newString FROM dbo.patExclude('XXX 123 ZZZ', ' '); -- Returns: XXX123ZZZ

-- only return letters and "!, ? or ."
 SELECT newString 
 FROM dbo.patExclude('123# What?!... ', '[^A-Za-z!?.]')  -- Returns: What?!...

----------------------------------------------------------------------------------------
Developer Notes:

 1.  Requires NGrams2b located here: https://goo.gl/T3DDiY
		 
 2.  dbo.patExclude is the varchar(max) version of patExclude8k which is limited to 
     varchar(8000)vand performs better because varchar(max) data types add a lot of
     overhead. 
		 
 3.  This function is what is referred to as an "inline" scalar UDF." Technically it's an
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
		 
 4.  patExclude generally performs better with a parallel execution plan but the optimizer 
     is sometimes stingy about assigning one. Consider performance testing using 
     Traceflag 8649 in Development environments and Adam Machanic's make_parallel in 
     production environments. 
		 
 5.  patExclude returns NULL when supplied with a NULL input strings and/or NULL pattern;
 		 
 6.  @pattern is not case sensitive (the function can be easily modified to make it so)
		 
 7.  There is no need to include the "%" before and/or after your pattern since since we 
	   are evaluating each character individually
		 
 8.  Latin1_General_BIN used in the PATINDEX statement improves performance and causes the
     function to perform case sensitive comparisons. This can be safely removed or changed.
		 
 9.  Outer CASE statement added to handle empty inputs and NULLs. Note the correct output
     for the following queries:

     SELECT f.newString FROM dbo.patExclude('','[0-9]') f;
     SELECT f.newString FROM dbo.patExclude(NULL,'') f;
     SELECT f.newString FROM dbo.patExclude('',NULL) f;
 
 10. patExclude is deterministic; for more about deterministic and nondeterministic 
     functions see https://msdn.microsoft.com/en-us/library/ms178091.aspx

----------------------------------------------------------------------------------------
Revision History:
 Rev 00 - 20171214 - Initial Development - Alan Burstein
 Rev 01 - 20180614 - Added COALESCE to correctly handle 0-len input strings 
                   - Alan Burstein
*****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN
SELECT newString = CASE WHEN @pattern IS NOT NULL THEN 
  COALESCE((
  SELECT ng.token+'' -- token+''+PATH('')+ no ROOT clause only returns the token (no xml)
  FROM dbo.NGrams2b(ISNULL(@string,''),1) ng
  WHERE 0 = PATINDEX(@pattern, ng.token COLLATE Latin1_General_BIN)
  ORDER BY ng.position   -- spoon
  FOR XML PATH(''), TYPE -- TYPE & value clauses handle special XML characters such as "&"
).value('text()[1]','varchar(max)'), @string) END;

GO
