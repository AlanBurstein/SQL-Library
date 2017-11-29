if object_id('dbo.edgeNgrams8k', 'IF') is not null drop function dbo.edgeNgrams8k;
go
create function dbo.edgeNgrams8k(@string varchar(8000))
/*****************************************************************************************
Purpose
  edgeNgrams8k is an inline table valued function (itvf) that accepts a varchar(8000) 
  input string (@string) and returns a series of character-level left and right edge 
  n-grams. An edge n-gram (referred to herin as an "edge-gram" for brevity) is a type of 
  n-gram (see https://en.wikipedia.org/wiki/N-gram). Instead of a contiguous series of 
  n-sized tokens (n-grams), however, an edge n-gram is a series of tokens that that begin 
  with the input string's first character then increases by one character, the next in the
  string, unitl the token is as long as the input string. 
		
  Left edge-grams start at the beginning of the string and grow from left-to-right. Right
  edge-grams begin at the end of the string and grow from right-to-left. Note this query
  and the result-set:

  select * from dbo.edgeNgrams8k('ABC');

  tokenlen   leftToken    rightTokenIndex  righttoken
  ---------- ------------ ---------------- ----------
  1          A            3                C
  2          AB           2                BC
  3          ABC          1                ABC

Developer Notes:
 1. For more about N-Grams in SQL Server see: https://goo.gl/QrLMtw
    For more about Edge N-Grams see the documentation by Elastic here: https://goo.gl/YX4G51

 2. dbo.edgeNgrams8k is deterministic. For more about determinism see: 
    https://goo.gl/VXhQkd

 3. If you need to sort this data without getting a sort in your execution plan you can 
    sort by tokenLen for ascending order, or by rightTokenIndex for descending order.

------------------------------------------------------------------------------------------
Usage Examples:
  I need to turn /A/B/C/D/E into:
  /A
  /A/B
  .....
  /A/B/C/D/E

  select leftToken 
	from dbo.edgeNgrams8k('/A/B/C/D/E')
  where tokenLen % 2 = 0;

------------------------------------------------------------------------------------------
History:
 20171125 - Initial Development - Developed by Alan Burstein  
*****************************************************************************************/
returns table with schemabinding as return
with iTally(n) as 
(
  select top (len(@string)) row_number() over (order by (select $))
  from (values (1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) a(x), -- 10^1 = 10
       (values (1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) b(x), -- 10^2 = 100
       (values (1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) c(x), -- 10^3 = 1000
       (values (1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) d(x)  -- 10^4 = 10000
)
select top (convert(bigint, len(@string), 0))
  tokenlen        = n,
  leftToken       = substring(@string,1,n),
  rightTokenIndex = len(@string)+1-n,
  righttoken      = substring(@string,len(@string)+1-n, n)
from itally;
go


