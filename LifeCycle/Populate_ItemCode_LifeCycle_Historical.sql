USE [Sandbox]
GO
/****** Object:  StoredProcedure [dbo].[Populate_ItemCode_LifeCycle_Historical]    Script Date: 11/25/2019 1:50:42 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER procedure [dbo].[Populate_ItemCode_LifeCycle_Historical]
	@EndDate DATE
as


set nocount on;

/******************************************************************
ITEM CODE LIFE CYCLE V2


For the each item, we will need to pull data for all events that
affect its shelf life cycle.

Events:

1 - Item Create Date
2 - Shelf Scan Record Historical Record
3 - Shelf Scan Current Record
4 - Transfer
5 - Sale

Item Type:

1 - Used
2 - Distribution


Salable:
0 - If an item is scanned to the back room, transferred, or sold
1 - If an item is created or scanned to salable shelf 


compare to 

execute Data_ExtractsHelper.dbo.PLC_CreateLifeCycleRecordForItemCode 1525410, '2019-02-14 00:00:00.000'

select *
from Data_Extracts.dbo.ItemCode_LifeCycle
where ItemCode = 1525410

******************************************************************/

/******************************************************************
Updating the processing table

--update processing row for reprocessing
create table #updates (itemcode int primary key)

--Get items that have been scanned since the item life cycle was set as complete
insert into #updates (itemcode)
select lc.ItemCode
from Data_Extracts.dbo.ItemCode_LifeCycle lc
join Base_Analytics.dbo.ShelfScan ss
	on lc.ItemCode = ss.ItemCodeSips
where (lc.LifeCycle_Complete = 1 and ss.ScannedOn > lc.InsertTime)
group by lc.ItemCode

insert into #updates (itemcode)
select lc.ItemCode
from Data_Extracts.dbo.ItemCode_LifeCycle lc
join Base_Analytics.dbo.Transfers t
	on t.SipsItemCode = lc.ItemCode
left join #updates u
	on u.itemcode = lc.ItemCode
where t.TransferCompleteDate > lc.InsertTime
	and lc.LifeCycle_Complete = 1
	and u.itemcode is null
group by lc.ItemCode

--update the scanned items as unprocessed and delete the rows
--from the life cycle table
update Data_ExtractsHelper.dbo.ProductLifeCycle_Processing
	set Processed = 0
where ItemCode in (select itemcode from #updates)

drop table #updates


--Set the items currently having life cycle complete flag set to 0
update Data_ExtractsHelper.dbo.ProductLifeCycle_Processing
	set Processed = 0
from Data_ExtractsHelper.dbo.ProductLifeCycle_Processing p
join Data_Extracts.dbo.ItemCode_LifeCycle lc
	on lc.ItemCode = p.ItemCode
where lc.LifeCycle_Complete = 0


--delete all rows in the life cycle table where the item code is set to
--be reprocessed
delete from Data_Extracts.dbo.ItemCode_LifeCycle
from Data_Extracts.dbo.ItemCode_LifeCycle lc
join Data_ExtractsHelper.dbo.ProductLifeCycle_Processing p
	on p.ItemCode = lc.ItemCode
where p.Processed = 0


--insert new items
insert into Data_ExtractsHelper.dbo.ProductLifeCycle_Processing (ItemCode, Processed)
select pu.ItemCode, 0
from Base_Analytics.dbo.Products_Used pu
left join Data_ExtractsHelper.dbo.ProductLifeCycle_Processing lc
	on lc.ItemCode = pu.ItemCode
where lc.ItemCode is null

--update existing items that have changed catalog id
update Data_Extracts.dbo.ItemCode_LifeCycle
	set CatalogID = pu.CatalogId
from Data_Extracts.dbo.ItemCode_LifeCycle lc
join Base_Analytics.dbo.Products_Used pu
	on pu.ItemCode = lc.ItemCode
where isnull(lc.CatalogID, 0) <> isnull(pu.CatalogId, 0)	

******************************************************************/

while (select count(ItemCode) from Sandbox.dbo.ProductLifeCycle_Processing_Historical where Processed = 0) > 0

begin


/************************************************************
Prepare the processing table
************************************************************/
create table #processing (itemcode int primary key)

insert into #processing (itemcode)
select top 1000000 ItemCode
from Sandbox.dbo.ProductLifeCycle_Processing_Historical with(nolock)
--where ItemCode = 14047
where Processed = 0;
	

--drop table #processing

/************************************************************
Build the data
************************************************************/


--Events Table
create table #EventTypes (EventType smallint, EventName varchar(50))
insert into #EventTypes (EventType, EventName) values (1, 'Item Create Date')
,(2, 'Shelf Scan Record Historical Record')
,(3, 'Shelf Scan Current Record')
,(4, 'Transfer')
,(5, 'Sale');

--create the product life cycle table where all events are stored
--we use this to order events so that we can get timespans between events that cause the item to move in and out of different states of salability
create table #ProductLifeCycle (EventID int primary key identity(0,1), ItemCode varchar(20), SkuExtension varchar(20), 
	ItemType smallint, EventType smallint, Salable tinyint, OnlineSalable tinyint, FinalEvent tinyint, EventDate datetime2(3), 
	Processed bit, CatalogID bigint, CurrentStatus char(1), Sale_Price money, Sale_MarketType smallint);

create nonclustered index ix_#ProductLifeCycle_ItemCode_Processed on #ProductLifeCycle (ItemCode, Processed);

--Product Data
insert into #ProductLifeCycle (ItemCode, SkuExtension, ItemType, EventType, Salable, OnlineSalable, FinalEvent, EventDate, Processed, CatalogID, CurrentStatus)
select pu.ItemCode
		,pu.SipsID [SkuExtension] --for now let's store the SIPSID in here
		,1 [ItemType]
		,1 [EventType]
		,1 [Salable]
		,0 [OnlineSalable]
		,case when pu.Active <> 'Y' then 1 else 0 end [FinalEvent]
		,DateInStock [EventDate]
		,0 [Processed]
		,CatalogId
		,pu.Active [CurrentStatus]
from Sandbox.dbo.Products_Used_Historical pu
join #processing p
	on p.itemcode = pu.ItemCode;


--ShelfScan
--WAM: added EndDate cutoff, added ranking of scan dates to allow for the flagging of the last ShelfItemScanID as current.
with #cte_scans (ShelfItemScanID, ItemCodeSips, CurrentScan, SubjectKey, ScannedOn, ListOnline)
as
(
select
	ss.ShelfItemScanID,
	ss.ItemCodeSips,
	ls.CurrentScan,
	ss.SubjectKey,
	ss.ScannedOn,
	ss.ListOnline
from Base_Analytics_Cashew..ShelfScan ss
	left outer join
		(
		select 
			ss.ItemCodeSips,
			MAX(ss.ScannedOn) [ScannedOn],
			CASE 
				WHEN (MAX(ss.ScannedOn) > MAX(t.TransferCompleteDate))
				AND (MAX(ss.ScannedOn) > MAX(s.OrderDate))
				THEN 1
				ELSE 0
				END [CurrentScan]
		FROM Base_Analytics_Cashew..ShelfScan ss
			left join Base_Analytics_Cashew..Transfers t
				on ss.ItemCodeSips = t.SipsItemCode
				and t.TransferCompleteDate < @EndDate
			left join Base_Analytics_Cashew..Sales s
				on ss.ItemCodeSips = s.SipsItemCode
				and s.OrderDate < @EndDate
		where ss.SkuExtension is null
			and ss.ScannedOn < @EndDate
		group by ss.ItemCodeSips
		) ls 
			on ss.ItemCodeSips = ls.ItemCodeSips
			and ss.ScannedOn = ls.ScannedOn
)
insert into #ProductLifeCycle (ItemCode, SkuExtension, ItemType, EventType, Salable, OnlineSalable, FinalEvent, EventDate, Processed)
select 	ss.ItemCodeSips [ItemCode]
		,null [SkuExtention] 
		,1 [ItemType]
		,case when ss.CurrentScan = 1 then 3 else 2 end [EventType]
		--subject key 5 is backroom (only salable if it is in the store)
		,case when ss.SubjectKey <> 5 then 1 else 0 end [Salable]
		--checking whether it is available for online listing
		,case when ListOnline = 1 then 1 else 0 end [OnlineSalable]	
		,0 [FinalEvent]	
		,ScannedOn [EventDate]
		,0 [Processed]
from #cte_scans ss
join #processing p
	on p.itemcode = ss.ItemCodeSips
where ss.ScannedOn < @EndDate;


--Transfers for used items (from Sips application)
insert into #ProductLifeCycle (ItemCode, SkuExtension, ItemType, EventType, Salable, OnlineSalable, FinalEvent, EventDate, Processed)
select SipsItemCode [ItemCode]
		,null [SkuExtension]
		,1 [ItemType]
		,4 [EventType]
		,0 [Salable]
		,0 [OnlineSalable]
		--in the case of a store to store transfer(3) this is not a final event
		--If the items is trashed / donated / something other than store which is a final event
		,case when TransferType = 3 then 0 else 1 end [FinalEvent]
		,TransferCompleteDate [EventDate]	
		,0 [Processed]	
from Base_Analytics_Cashew.dbo.Transfers t
join #processing p
	on p.itemcode = t.SipsItemCode
where StatusCode = 1
	and t.TransferCompleteDate < @EndDate;


--Sales for used items
--If there is more than 1 sale value, get the last one (by using first_value, desc: I know, weird right, but try using last_value...)
insert into #ProductLifeCycle (ItemCode, SkuExtension, ItemType, EventType, Salable, OnlineSalable, FinalEvent, EventDate, Processed, Sale_Price, Sale_MarketType)
select SipsItemCode [ItemCode]
		,null [SkuExtension]
		,1 [ItemType]
		,5 [EventType]
		,0 [Salable]
		,0 [OnlineSalable]
		,1 [FinalEvent]	
		,first_value(s.OrderDate) over (partition by s.SipsItemCode order by s.OrderDate desc) [EventDate]
		,0 [Processed]
		,first_value(s.EnteredPrice) over (partition by s.SipsItemCode order by s.OrderDate desc) [Sale_Price]
		,first_value(s.MarketTypeID) over (partition by s.SipsItemCode order by s.OrderDate desc) [Sale_MarketType]
from Base_Analytics_Cashew.dbo.Sales s
join #processing p
	on p.itemcode = s.SipsItemCode
where IsRefund = 'N'
	and s.OrderStatus in ('Active', 'Shipped', 'shipped')
	and s.MarketTypeID in (1, 2, 4, 5)
	and s.OrderDate < @EndDate;
	
	


/************************************************************
Analyze the data
************************************************************/

--First, get the data we can before individual product life cycle rows need to be processed for each item code
create table #attribute_processing (ItemCode int primary key, First_RecordDate datetime2(3), Last_RecordDate datetime2(3), Seconds_Total int,
			Seconds_ScannedDate int, Seconds_Salable_Priced int, Seconds_Salable_Scanned int, Seconds_OnlineSalable int,
			--Last_Event_Salable_Priced bit, Last_Event_Salable_Scanned bit, Last_Event_OnlineSalable bit,
			Last_Event_Type smallint, Cycle_EndDate datetime2(3), First_ScanDate datetime2(3), Last_ScanDate datetime2(3), Current_ScanRecord bit,
			Current_ScanRecord_Salable bit, Current_ScanRecord_OnlineSalable bit, Total_Scan_Count int, CatalogID bigint, Last_SaleDate datetime2(3),
			Last_TransferDate datetime2(3), Final_Event_Detected bit, Current_Item_Status char(1), Sale_Price money, Sale_MarketType smallint)


declare @CurrentDate datetime2(3);
set @CurrentDate = current_timestamp;

insert into #attribute_processing ([ItemCode], [First_RecordDate], [Last_RecordDate], [Cycle_EndDate], 
		[Seconds_Total], [Total_Scan_Count], [Final_Event_Detected], [CatalogID], [Current_Item_Status])
select	ItemCode [SipsItemCode]
		--Use the min EventDate in case there is overlapping product inventory data.  This shouldn't happen, but just in case		
		,min(EventDate) [First_RecordDate]
		--Same for the max EventDate, but with sales data.  The same item code can and does sell multiple times, or be trashed and then sold.  Record the last date info was record in the system.	
		,max(EventDate) [Last_RecordDate]		
		--I know, what if the item is mysteriously scanned to a current shelf after it sells?
		--Also, the items that are not active but don't have a transfer record look odd because they have 0 totals days since the cycle end date is the same as the create date
		--Well in those sort of one off cases, this won't be quite correct.  These sorts of exceptions should trigger the item to be re-Sips'd in any case		
		,case when max(FinalEvent) = 1 then max(EventDate) else @CurrentDate end [Cycle_EndDate]
		--Either count from the time created to final event or current date		
		,case when max(FinalEvent) = 1 then datediff(second, min(EventDate), max(EventDate)) else datediff(second, min(EventDate), @CurrentDate) end [Seconds_Total]
		--just counting the number of times the item was shelf scanned in case anyone wants to run a labor analysis		
		,sum(case when EventType in (2,3) then 1 else 0 end) [Total_Scan_Count]		
		,max(FinalEvent) [Final_Event_Detected]
		,nullif(max(coalesce(CatalogID, 0)), 0) [CatalogID]
		,max(CurrentStatus) [Current_Item_Status]

from #ProductLifeCycle
group by ItemCode;



--Now aggregate the events for each item code.  
create table #agg_events (ItemCode int primary key, Seconds_ScannedDate int, Seconds_Salable_Priced int, Seconds_Salable_Scanned int, 
			Seconds_OnlineSalable int, First_ScanDate datetime2(3), Last_ScanDate datetime2(3), Current_ScanRecord bit,
			Current_ScanRecord_Salable bit, Current_ScanRecord_OnlineSalable bit, Last_SaleDate datetime2(3), Last_TransferDate datetime2(3),
			Last_Event_Type smallint, Sale_Price money, Sale_MarketType smallint);

--Run in two stages so we can get the time between each event in the order it happened
with cte_lifecycle (EventID, ItemCode, EventType, Salable, OnlineSalable, FinalEvent, EventDate,
		[lag_eventDate], [lead_eventDate], [Seconds_ScannedDate], [Seconds_Salable_Priced], 
		[Seconds_Salable_Scanned], [Seconds_OnlineSalable], [Current_ScanRecord], [Current_ScanRecord_Salable],
		[Current_ScanRecord_OnlineSalable], [Last_Event], Sale_Price, Sale_MarketType)
as
(

select EventID,		
		ItemCode,
		EventType,
		Salable,
		OnlineSalable,
		FinalEvent,
		EventDate,
		lag (EventDate, 1) over (partition by itemcode order by eventdate) [lag_eventDate],
		lead (EventDate, 1) over (partition by itemcode order by eventdate) [lead_eventDate],
		--look at previous EventType to see whether it is a historical or current scan so we can get the number
		--of seconds between that event and the current one
		case when (lag (EventType, 1, 0) over (partition by itemcode order by eventdate)) in (2, 3)
			then  datediff(second, lag (EventDate, 1) over (partition by itemcode order by eventdate), EventDate)
			else 0 end [Seconds_ScannedDate],
		--look at previous Salable flag to see whether it is on or off so we can get the number
		--of seconds between that event and the current one (this means from the time it was priced)
		case when (lag (Salable, 1, 0) over (partition by itemcode order by eventdate)) = 1
			then  datediff(second, lag (EventDate, 1) over (partition by itemcode order by eventdate), EventDate)
			else 0 end [Seconds_Salable_Priced],
		--look at previous EventType to see whether it was the pricing event so we can get the number
		--of seconds between salable events after that one and the current one
		case when (lag (EventType, 1, 0) over (partition by itemcode order by eventdate)) in (2,3)
				and (lag (Salable, 1, 0) over (partition by itemcode order by eventdate)) = 1
			then datediff(second, lag (EventDate, 1) over (partition by itemcode order by eventdate), EventDate) 
			else 0 end [Seconds_Salable_Scanned],
		--look at previous OnlineSalable flag to see whether it was on or off so we can get the number
		--of seconds between that event and the current one
		case when (lag (OnlineSalable, 1, 0) over (partition by itemcode order by eventdate)) = 1
			then  datediff(second, lag (EventDate, 1) over (partition by itemcode order by eventdate), EventDate)
			else 0 end [Seconds_OnlineSalable],
		--If EventType is 3, we know this is a current scan
		case when EventType = 3 then 1 else 0 end [Current_ScanRecord],
		--If EventType is 3 and the Salable flag is on, the item is currently on the sales floor and available
		case when EventType = 3 and Salable = 1 then 1 else 0 end [Current_ScanRecord_Salable],
		--If EventType is 3 and the OnlineSalable flag is on, the item is currently available for sale online
		case when EventType = 3 and OnlineSalable = 1 then 1 else 0 end [Current_ScanRecord_OnlineSalable],
		--Look for the last event by check the row where the next EventDate is null (meaning there isn't one so this is the last row)
		case when lead (EventDate, 1) over (partition by itemcode order by eventdate) is null then EventType else 0 end [Last_Event],
		Sale_Price,
		Sale_MarketType

from #ProductLifeCycle
--where ItemCode = @SipsItemCode
--order by EventDate
)

--Then aggregate that data by adding up all the time between events depending on the state of the item
--caused by an event.
insert into #agg_events (ItemCode, Seconds_ScannedDate, Seconds_Salable_Priced, Seconds_Salable_Scanned, 
			Seconds_OnlineSalable, First_ScanDate, Last_ScanDate, Current_ScanRecord, Current_ScanRecord_Salable, 
			Current_ScanRecord_OnlineSalable, Last_SaleDate, Last_TransferDate, Last_Event_Type, Sale_Price, Sale_MarketType)
select lc.ItemCode
	,sum(lc.Seconds_ScannedDate) [Seconds_ScannedDate]
	,sum(lc.Seconds_Salable_Priced) [Seconds_Salable_Priced]
	,sum(lc.Seconds_Salable_Scanned) [Seconds_Salable_Scanned]
	,sum(lc.Seconds_OnlineSalable) [Seconds_OnlineSalable]
	,min(case when lc.EventType in (2,3) then lc.EventDate else null end) [First_ScanDate]
	,max(case when lc.EventType in (2,3) then lc.EventDate else null end) [Last_ScanDate]
	,max(lc.Current_ScanRecord) [Current_ScanRecord]
	,max(lc.Current_ScanRecord_Salable) [Current_ScanRecord_Salable]
	,max(lc.Current_ScanRecord_OnlineSalable) [Current_ScanRecord_OnlineSalable]
	,max(case when EventType = 5 then EventDate else null end)  [Last_SaleDate]
	,max(case when EventType = 4 then EventDate else null end) [Last_TransferDate]
	,max(Last_Event) [Last_Event_Type]
	,max(Sale_Price) [Sale_Price]
	,max(Sale_MarketType) [Sale_MarketType]
from cte_lifecycle lc
group by lc.ItemCode;


--update the existing items in the attribute table from the results in the aggregation table
update #attribute_processing
	--if there is a current scan for this item, add the time between the current scan and today's date to get total time
	set Seconds_ScannedDate = ag.Seconds_ScannedDate 
		+ (case when ag.Current_ScanRecord = 1 then datediff(second, ag.Last_ScanDate, @CurrentDate)
				else 0 end)
	--if there is a current scan for this item, add the time between the current scan and today's date to get total time
	,Seconds_Salable_Priced = ag.Seconds_Salable_Priced  
		+ (case --when coalesce(ag.Seconds_Salable_Priced, 0) = 0 and coalesce(ap.Seconds_Total, 0) > 0 then ap.Seconds_Total
				when ag.Current_ScanRecord_Salable = 1 then datediff(second, ag.Last_ScanDate, @CurrentDate)
				else 0 end)
	,Seconds_Salable_Scanned = ag.Seconds_Salable_Scanned 
		+ (case when ag.Current_ScanRecord_Salable = 1 then datediff(second, ag.Last_ScanDate, @CurrentDate)
				else 0 end)
	,Seconds_OnlineSalable = ag.Seconds_OnlineSalable
		+ (case when ag.Current_ScanRecord_OnlineSalable = 1 then datediff(second, ag.Last_ScanDate, @CurrentDate)
				else 0 end)
	,First_ScanDate = ag.First_ScanDate
	,Last_ScanDate = ag.Last_ScanDate
	,Current_ScanRecord = ag.Current_ScanRecord
	,Current_ScanRecord_Salable = ag.Current_ScanRecord_Salable
	,Current_ScanRecord_OnlineSalable = ag.Current_ScanRecord_OnlineSalable
	,Last_SaleDate = ag.Last_SaleDate
	,Last_TransferDate = ag.Last_TransferDate
	,Last_Event_Type = ag.Last_Event_Type
	,Sale_Price = ag.Sale_Price
	,Sale_MarketType = ag.Sale_MarketType
from #attribute_processing ap
join #agg_events ag
	on ag.ItemCode = ap.ItemCode;
	

/*
--insert the new data with a final transform 
create table #ItemCode_Completed ([ItemCode] int primary key, [SkuExtension] varchar(20), [First_RecordDate] datetime2(3), [Last_RecordDate] datetime2(3), 
	[First_ScanDate] datetime2(3), [Last_ScanDate] datetime2(3), [Cycle_EndDate] datetime2(3), [Days_Total] decimal(18,2), [Days_Scanned] decimal(18,2), 
	[Days_Salable_Priced] decimal(18,2), [Days_Salable_Scanned] decimal(18,2), [Days_OnlineSalable] decimal(18,2), [Total_Scan_Count] int, [CatalogID] bigint, 
	[LastEventType] smallint, [LifeCycle_Complete] tinyint, [Last_SaleDate] datetime2(3), [Last_TransferDate] datetime2(3), [Current_Item_Status] char(1))


insert into #ItemCode_Completed ([ItemCode], [SkuExtension], [First_RecordDate], [Last_RecordDate], 
	[First_ScanDate], [Last_ScanDate], [Cycle_EndDate], [Days_Total], [Days_Scanned], [Days_Salable_Priced], 
	[Days_Salable_Scanned], [Days_OnlineSalable], [Total_Scan_Count], [CatalogID], [LastEventType], [LifeCycle_Complete], 
	[Last_SaleDate], [Last_TransferDate], [Current_Item_Status])
*/




insert into Sandbox.dbo.ItemCode_LifeCycle_Historical ([ItemCode], [SkuExtension], [First_RecordDate], [Last_RecordDate], 
	[First_ScanDate], [Last_ScanDate], [Cycle_EndDate], [Days_Total], [Days_Scanned], [Days_Salable_Priced], 
	[Days_Salable_Scanned], [Days_OnlineSalable], [Total_Scan_Count], [CatalogID], [LastEventType], [LifeCycle_Complete], 
	[Last_SaleDate], [Last_TransferDate], [Current_Item_Status], Sale_Price, Sale_MarketType)


select ItemCode [ItemCode]
		,null [SkuExtension]
		,First_RecordDate		
		,Last_RecordDate			
		,First_ScanDate		
		,Last_ScanDate		
		--This is for any items that were priced but no additional records were ever recorded for the item.  We don't want them to accumulate days forever, so we cut it off at 1000 days
		,case when Last_Event_Type = 1 and datediff(day, First_RecordDate, Cycle_EndDate) > 1000 then dateadd(day, 1000, First_RecordDate)
		--Any item transferred store to store but has not been seen for a year after transfer since will be assumed lost
			when Last_Event_Type = 4 and datediff(day, Last_RecordDate, Cycle_EndDate) > 365 then Last_RecordDate
			else Cycle_EndDate 
			end [Cycle_EndDate]	
		--This is for any items that were priced but no additional records were ever recorded for the item.  We don't want them to accumulate days forever, so we cut it off at 1000 days
		,case when Last_Event_Type = 1 and datediff(day, First_RecordDate, Cycle_EndDate) > 1000 then 1000 
		--Any item transferred store to store but has not been seen for a year after transfer since will be assumed lost
			when Last_Event_Type = 4 and datediff(day, Last_RecordDate, Cycle_EndDate) > 365 then datediff(second, First_RecordDate, Last_RecordDate) / 86400.0
			else Seconds_Total / 86400.0 
			end [Days_Total]		
		,Seconds_ScannedDate / 86400.0 [Days_Scanned]
		--This is for any items that were priced but no additional records were ever recorded for the item.  We don't want them to accumulate days forever, so we cut it off at 1000 days
		,case when Last_Event_Type = 1 and datediff(day, First_RecordDate, Cycle_EndDate) > 1000 
			then 1000 
			else Seconds_Salable_Priced / 86400.0 
			end [Days_Salable_Priced]
		,Seconds_Salable_Scanned / 86400.0 [Days_Salable_Scanned]
		,Seconds_OnlineSalable / 86400.0 [Days_OnlineSalable]
		,Total_Scan_Count [Total_Scan_Count]
		,CatalogID [CatalogID]
		,Last_Event_Type [LastEventType]
		,case when Final_Event_Detected = 1 then 1
			when datediff(day, Last_RecordDate, Cycle_EndDate) > 365 then 1
			else 0
			end [LifeCycle_Complete]
		,Last_SaleDate [Last_SaleDate]
		,Last_TransferDate [Last_TransferDate]
		,Current_Item_Status
		,Sale_Price
		,Sale_MarketType
from #attribute_processing;


update Sandbox.dbo.ProductLifeCycle_Processing_Historical
	set Processed = 1
where ItemCode in (select ItemCode from #processing);



--Drop all temp tables
drop table #attribute_processing;
drop table #processing;
drop table #agg_events;
drop table #ProductLifeCycle;
drop table #EventTypes;
--select * from #ItemCode_Completed
--drop table #ItemCode_Completed

end;