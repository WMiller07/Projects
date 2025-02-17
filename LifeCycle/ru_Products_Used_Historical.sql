USE [Sandbox]
GO
/****** Object:  StoredProcedure [dbo].[ru_Products_Used_Historical]    Script Date: 11/25/2019 2:18:35 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER procedure [dbo].[ru_Products_Used_Historical]
	--@StartDate DATE,
	@EndDate DATE
as

/***************************************************************************
Populate and Update Used Product Data
****************************************************************************/

--get original price from price change table
with #cte_original_prices (ItemCode, PriceChangeID)
as
(
	select ItemCode, min(PriceChangeID) [PriceChangeID]
	from ReportsData.dbo.SipsPriceChanges spc
	group by ItemCode
)
--WAM: added date criteria below to limit the items included to a smaller set. The CTE does not need changing.
insert into Sandbox.dbo.Products_Used_Historical(ItemCode, SipsID, Active, LocationNo, LocationID, DateInStock, Price, SubjectKey,
	CatalogId, ISBN, AmazonID, CreateUser, CreateMachine, ProductType, Title, Author, PublisherName, PubDate, MfgSuggestedPrice,
	ISBNSubject, ItemScore, OriginalPrice)
select 	spi.ItemCode
		,spi.SipsID
		,spi.Active
		,spi.LocationNo
		,spi.LocationID
		,spi.DateInStock
		,spi.Price		
		,spi.SubjectKey
		,spm.CatalogId
		,spm.ISBN		
		,spm.AmazonID
		,spi.CreateUser
		,spi.CreateMachine		
		,spi.ProductType
		,spm.Title
		,spm.Author		
		,spm.PublisherName
		,spm.PubDate
		,spm.MfgSuggestedPrice		
		,spm.ISBNSubject	
		,spi.ItemScore	
		,coalesce(spc.OldPrice, spi.Price) [OriginalPrice]
from ReportsData.dbo.SipsProductInventory spi
join ReportsData.dbo.SipsProductMaster spm
	on spm.SipsID = spi.SipsID
left join #cte_original_prices op
	on op.ItemCode = spi.ItemCode
left join ReportsData.dbo.SipsPriceChanges spc
	on spc.PriceChangeID = op.PriceChangeID
left join Sandbox.dbo.Products_Used_Historical pu
	on pu.ItemCode = spi.ItemCode
where pu.ItemCode is null
	--AND spi.DateInStock >= @StartDate
	AND spi.DateInStock < @EndDate;

--WAM: Since the status, location, and catalog updates are designed to update items already included in the table, and this is a one-time roll-up, this should be skipped.
--Instead, the "Active" flag in Products_Used should be modified to what it would have been as of @EndDate.

--update status and location if changed
--update Sandbox.dbo.Products_Used
--	set Active = spi.Active
--		,LocationNo = spi.LocationNo
--		,LocationID = spi.LocationID
--		,Price = spi.Price
--from Sandbox.dbo.Products_Used pu
--join ReportsData.dbo.SipsProductInventory spi
--	on spi.ItemCode = pu.ItemCode
--where spi.Active <> pu.Active
--	or spi.LocationNo <> pu.LocationNo
--	or spi.Price <> pu.Price


----update catalog ids that have been added or changed
--update Base_Analytics.dbo.Products_Used
--	set CatalogId = spm.CatalogId
--from Base_Analytics.dbo.Products_Used pu
--join SIPS.dbo.SipsProductMaster spm
--	on spm.SipsID = pu.SipsID
--where isnull(pu.CatalogId, 0) <> isnull(spm.CatalogId, 0);

with cte_transferflags (TransferNo, SipsItemCode, TransferType)
as
(
select 
		row_number() over (partition by SipsItemCode order by TransferCompleteDate desc) [TransferNo], --set the last transfer that occurred before end date to rank 1
		SipsItemCode,		
		TransferType 
from Base_Analytics_Cashew.dbo.Transfers 
where SipsItemCode is not null	
	and TransferCompleteDate < @EndDate
)
update Sandbox.dbo.Products_Used_Historical --Reset item status based on last transfer that occurred, unless that item was marked as missing.
set Active = CASE
				WHEN t.TransferType = 1
					THEN 'T'
				WHEN t.TransferType = 2
					THEN 'D'
				WHEN t.TransferType = 4
					THEN 'B'
				WHEN t.TransferType = 5
					THEN 'K'
				WHEN t.TransferType = 7
					THEN 'F'
				ELSE 'Y'
				END
from Sandbox.dbo.Products_Used_Historical pu
	left outer join cte_transferflags t
		on pu.ItemCode = t.SipsItemCode
		and t.TransferNo = 1
WHERE pu.Active <> 'M';


--get the original location number and location id for an item if transferred
--WAM: the below needs no modification
with cte_transfers (TransferNo, SipsItemCode, FromLocationNo)
as
(
select row_number() over (partition by SipsItemCode order by TransferCompleteDate) [TransferNo],
		SipsItemCode,		
		FromLocationNo			
from Base_Analytics_Cashew.dbo.Transfers
where TransferType = 3
	and SipsItemCode is not null	
)
update Sandbox.dbo.Products_Used_Historical
	set OriginalLocationNo = cte.FromLocationNo
		,OriginalLocationID = loc.LocationID
		,LastUpdated = current_timestamp
from Sandbox.dbo.Products_Used_Historical pu
join cte_transfers cte
	on cte.SipsItemCode = pu.ItemCode	
	and cte.TransferNo = 1
join ReportsData.dbo.Locations loc
	on loc.LocationNo = cte.FromLocationNo
where pu.OriginalLocationNo is null;






