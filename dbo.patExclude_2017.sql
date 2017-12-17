IF OBJECT_ID('dbo.patExclude_2017', 'IF') IS NOT NULL DROP FUNCTION dbo.patExclude_2017;
GO
CREATE FUNCTION dbo.patExclude_2017
(
  @string  varchar(max),
	@pattern varchar(50)
) 
/*****************************************************************************************
Purpose:
 Given a string (@string) and a pattern (@pattern) patExclude_2017 removes any character in
 @string that matches the @pattern. This is the varchar(max) version of patExclude8k_2017
 located here: <UPDATE ME>

Compatibility: 
 SQL Server 2008+;

Syntax:
--===== Basic Syntax (against parameters)
 SELECT px.newString
 FROM dbo.patExclude_2017(@string,@pattern) px;

--===== Basic Syntax (against a table)
 SELECT px.newString
 FROM dbo.someTable t
 CROSS APPLY dbo.patExclude_2017(t.someString,@pattern) px;

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
 CROSS APPLY dbo.patExclude_2017(st.SomeString,'%[^0-9a-zA-Z]%') px;

--===== Remove all but numeric characters and dots
 SELECT newString
 FROM dbo.SomeTable st
 CROSS APPLY dbo.patExclude_2017(st.SomeString,'%[^0-9.]%');

----------------------------------------------------------------------------------------
Runnable Examples:
	
--remove letters
 SELECT newString FROM dbo.patExclude_2017('abc123!', '[a-z]'); -- Returns: 123!

-- remove numbers
 SELECT newString FROM dbo.patExclude_2017('abc123!', '[0-9]'); -- Returns: abc!

-- only return letters and numbers
 SELECT newString FROM dbo.patExclude_2017('###abc123!!!', '[^0-9a-z]'); -- Returns: abc123

-- Remove spaces
 SELECT newString FROM dbo.patExclude_2017('XXX 123 ZZZ', ' '); -- Returns: XXX123ZZZ

-- only return letters and "!, ? or ."
 SELECT newString 
 FROM dbo.patExclude_2017('123# What?!... ', '[^A-Za-z!?.]')  -- Returns: What?!...

----------------------------------------------------------------------------------------
Developer Notes:

 1. Requires nGrams2b located here: https://goo.gl/T3DDiY

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

 3. patExclude_2017 generally performs better with a parallel execution plan
 
 4. @pattern is not case sensitive (the function can be easily modified to make it so)

 5. There is no need to include the "%" before and/or after your pattern since since we 
	  are evaluating each character individually

 6. Latin1_General_BIN used in the PATINDEX statement improves performance and causes the
    function to perform case sensitive comparisons. This can be safely removed or changed.
 
 7. patExclude_2017 is deterministic; for more about deterministic and nondeterministic 
    functions see https://msdn.microsoft.com/en-us/library/ms178091.aspx

----------------------------------------------------------------------------------------
Revision History:
 Rev 00 - 20171214 - Initial Development - Alan Burstein
*****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN
SELECT newString = STRING_AGG(ng.token,'') WITHIN GROUP (ORDER BY position) -- spoon
FROM dbo.ngrams2B(@string,1) ng
WHERE 0 = PATINDEX(@pattern, token COLLATE Latin1_General_BIN);
GO