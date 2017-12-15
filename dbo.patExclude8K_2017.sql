IF OBJECT_ID('dbo.patExclude8K_2017', 'IF') IS NOT NULL 
  DROP FUNCTION dbo.patExclude8K_2017;
GO
CREATE FUNCTION dbo.patExclude8K_2017
(
  @string  varchar(8000),
	@pattern varchar(50)
) 
/*****************************************************************************************
Note:
 This function only runs on SQL Server 2017 or higher

Purpose:
 Given a string (@string) and a pattern (@pattern) patExclude8K_2017 removes any character
 in @string that matches the @pattern.

Compatibility:
 SQL Server 2017+ (Leverages STRING_AGG)

Syntax:
--===== Basic Syntax (against parameters)
 SELECT px.cleanedString
 FROM dbo.patExclude8K_2017(@string,@pattern) px;

--===== Basic Syntax (against a table)
 SELECT px.cleanedString
 FROM dbo.someTable t
 CROSS APPLY dbo.patExclude8K_2017(t.someString,@pattern) px;

Parameters:
  @string  = varchar(8000); input string to clean
  @pattern = varchar(50);   pattern that matches characters you wish to remove 

Return Types:
 Inline Table Valued Function returns:
   newString = varchar(8000); Transformed string free of characters that match @pattern

-----------------------------------------------------------------------------------------
Usage:

--===== Remove all but alpha characters
 SELECT px.cleanedString 
 FROM dbo.SomeTable st
 CROSS APPLY dbo.patExclude8K_2017(st.SomeString,'%[^0-9a-zA-Z]%') px;

--===== Remove all but numeric characters and dots
 SELECT CleanedString
 FROM dbo.SomeTable st
 CROSS APPLY dbo.patExclude8K_2017(st.SomeString,'%[^0-9.]%');

----------------------------------------------------------------------------------------
Runnable Examples:
	
--remove letters
 SELECT newString FROM dbo.patExclude8K_2017('abc123!', '[a-z]'); -- Returns: 123!

-- remove numbers
 SELECT newString FROM dbo.patExclude8K_2017('abc123!', '[0-9]'); -- Returns: abc!

-- only return letters and numbers
 SELECT newString FROM dbo.patExclude8K_2017('###abc123!!!', '[^0-9a-z]');
Returns: abc123

-- Remove spaces
 SELECT newString FROM dbo.patExclude8K_2017('XXX 123 ZZZ', ' '); -- Returns: XXX123ZZZ

-- only return letters and "!, ? or ."
 SELECT newString 
 FROM dbo.patExclude8K_2017('123# What?!... ', '[^A-Za-z!?.]')  -- Returns: What?!...
----------------------------------------------------------------------------------------
Developer Notes:

 1. Requires nGrams8k located here: https://goo.gl/T3DDiY. 
 
 2. patExclude8K_2017 is identical to patExclude8K but leverages SQL Server 2017's 
    STRING_AGG (https://goo.gl/G7Urrb) for concatination

 3. patExclude8K_2017 is what is referred to as an "inline" scalar UDF." Technically it's 
    an inline table valued function (iTVF) but performs the same task as a scalar valued 
    user defined function (UDF); the difference is that it requires the APPLY table 
    operator to accept column values as a parameter. For more about "inline" scalar UDFs 
    see this article by SQL MVP Jeff Moden: https://goo.gl/vTYf1S; and for more about how 
    to use APPLY see the this article by SQL MVP Paul White: https://goo.gl/ryCYqk

    Note the above syntax example and usage examples below to better understand how to
    use the function. Although the function is slightly more complicated to use than a
    scalar UDF it will yield notably better performance for many reasons. For example,
    unlike a scalar UDFs or multi-line table valued functions, the inline scalar UDF does
    not restrict the query optimizer's ability generate a parallel query execution plan.

 4. patExclude8K_2017 generally performs better with a parallel execution plan
 
 5. @pattern is not case sensitive (the function can be easily modified to make it so)

 6. There is no need to include the "%" before and/or after your pattern since since we 
	  are evaluating each character individually

 7. Latin1_General_BIN used in the PATINDEX statement improves performance and causes the
    function to perform case sensitive comparisons. This can be safely removed or changed.
 
 8. patExclude8K_2017 is deterministic; for more about deterministic and nondeterministic 
    functions see https://msdn.microsoft.com/en-us/library/ms178091.aspx

----------------------------------------------------------------------------------------
Revision History:
 Rev 00 - 20141027 Initial Development - Alan Burstein

 Rev 01 - 20141029 - Alan Burstein
		- Redesigned based on the dbo.STRIP_NUM_EE by Eirikur Eiriksson
		  (see: http://www.sqlservercentral.com/Forums/Topic1585850-391-2.aspx)
		- change how the cte tally table is created 
		- put the include/exclude logic in a CASE statement instead of a WHERE clause
		- Added Latin1_General_BIN Colation
    - Added code to use the pattern as a parameter.

 Rev 02	- 20141106
		- Added final performane enhancement (more cudo's to Eirikur Eiriksson)
		- Put 0 = PATINDEX filter logic into the WHERE clause

 Rev 03 - 20150516 - Alan Burstein
        - Updated code to deal with special XML characters

 Rev 04 - 20170427 - Alan Burstein - Changed final .value logic for text()

 Rev 05 - 20170909 - Alan Burstein - Replaced inline tally table unigram logic w/ ngrams8k
                                   - Updated comments/documentation

 Rev 06 - 20171214 - Alan Burstein - Added ORDER BY clause, updated documentation
*****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN
SELECT newString = STRING_AGG(ng.token,'') WITHIN GROUP (ORDER BY position) -- your spoon
FROM dbo.ngrams8k(@string,1) ng
WHERE 0 = PATINDEX(@pattern, token COLLATE Latin1_General_BIN);
GO