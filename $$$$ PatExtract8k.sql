
/*

!!!! NEXT - UNION THE CM VERSION !!!!
*/


declare
  @string  varchar(8000) = 'He paid $10 then $12.50 then another 5 bucks!',
  @pattern varchar(50)  = '[$0-9.]';

-- (1) Original Pattern Split CM
select
  itemNumber = row_number() over (order by min(p)),
  itemIndex  = min(p),
  item       = substring
               (
                 @string,
                 min(p), 
                 1+max(p)-min(p)
               ),
  [matched]
from
(
	select position, y.[matched], grouper = position - row_number() over (order by y.[matched], position)
	from dbo.NGrams8k(@string, 1) as ng
  cross apply (select case when token like @pattern then 1 else 0 end) y([matched])
) as d(p,[matched], g)
group by [matched], d.g;

-- (2) First version of PatExtract
select
  itemNumber = row_number() over (order by min(p)),
	itemIndex  = min(p), -- note: if you want to include the position in the string in the output
  item       = substring
               (
                 @string,
                 min(p), 
                 1+max(p)-min(p)
               )
from
(
	select position, grouper = position - row_number() over (order by position)
	from dbo.NGrams8k(@string, 1) as ng
	where token like @pattern
) as d(p,g)
group by d.g;
go

-- (3)First stab at a new pattern based splitter leveraging LEAD
declare
  @string  varchar(8000) = 'He paid $10 then $12.50 then another 5 bucks!',
  @pattern varchar(50)  = '[$0-9.]';

select 
  itemNumber = row_number() over (order by position),
  itemIndex  = position,
  item       = substring
               (
                 @string,
                 position, 
                 lead(position,1,8000) over (order by position) - position
               ),
  isMatch
from
(
  select position, token, isMatch = 
      case
        when token like @pattern 
          and (position = 1 or not (substring(@string,position-1,1) like @pattern)) then 1
        when token not like @pattern 
          and (position = 1 or      substring(@string,position-1,1) like @pattern)  then 0
      end
  from dbo.NGrams8k(@string, 1)
) unigram
where isMatch is not null;
go

-- EXAMPLES 
declare
  @string  varchar(8000) = 'He paid $10 then $12.50 then another 5 bucks!',
  @pattern varchar(50)  = '[^$0-9.]';

select * from dbo.patternExtract8K(@string, '[$^0-9.,]');
select * from dbo.patternExtract8K(@string, '[0-9]');

select * from dbo.patternExtract8K(@string, @pattern);
go

declare 
  @string  varchar(100) = ',,xxx,,,,yyy..zzz;,555.123.9999,22',
	@pattern varchar(50)  = '[0-9a-z]'; -- this is the expected format
	;
--select stuff(@pattern, 2, 0, '^')
--select 
--  row_number() over (order by itemIndex),
--	*
--from
--(
--  select itemIndex, item from dbo.patExtract8K(@string, '[0-9a-z]')
--  union all
--  select itemIndex, item from dbo.patExtract8K(@string, stuff(@pattern, 2, 0, '^'))
--) split

select
 itemNumber       = cast(row_number() over (order by itemIndex) as smallint),
 matchGroupNumber = patternSplit.itemNumber,
 itemIndex, 
 item,
 isMatch
from
(
  select itemNumber, itemIndex, item, isMatch = 1 
	from dbo.patExtract8K(@string, @pattern)
  union all
  select itemNumber, itemIndex, item, isMatch = 0 
	from dbo.patExtract8K(@string, stuff(@pattern, 2, 0, '^'))
) patternSplit
option (recompile);
 


--');




select * from dbo.patExtract8K(@string, '[^0-9a-z]');
select * from dbo.patExtract8K(@string, '[0-9a-z]');

GO


if object_id('dbo.patSplit8K') is not null drop function dbo.patSplit8K;
go
create function dbo.patSplit8K
(
  @string   varchar(8000),
	@pattern  varchar(50)
)
returns table with schemabinding as return
select
 itemNumber       = cast(row_number() over (order by itemIndex) as smallint),
 matchGroupNumber = patternSplit.itemNumber,
 itemIndex, 
 item,
 isMatch
from
(
  select itemNumber, itemIndex, item, isMatch = 1 
	from dbo.patExtract8K(@string, @pattern)
  union all
  select itemNumber, itemIndex, item, isMatch = 0 
	from dbo.patExtract8K(@string, stuff(@pattern, 2, 0, '^'))
) patternSplit
go


declare @string varchar(100) = ',,xxx,,,,yyy..!!!zzz;,555.123.9999,22';

--select * from dbo.patSplit8K(@string, '[0-9a-z]', null);

select * from dbo.patSplit8K(@string, '[^0-9a-z]', '[0-9a-z]');
select * from dbo.PatternSplitCM(@string, '[0-9a-z]');

go

select * from dbo.PatternSplitCM(@string, '[0-9a-z]');




