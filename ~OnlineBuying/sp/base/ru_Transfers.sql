USE [Base_Analytics_Test]
GO
/****** Object:  StoredProcedure [dbo].[ru_Transfers]    Script Date: 3/19/2020 1:15:20 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE procedure [dbo].[ru_Transfers]


as

/******************************************************************
Populate all transfers into single table
******************************************************************/




/******************************************************************
OG SIPS Transfers

This is stuff that only exists in this table and not in 
SipsTransferBinHeader or InventoryItemTransfersAny

**Only run if repopulating the table
******************************************************************/
--SPI Archive
/*
insert into Base_Analytics.dbo.Transfers ([SipsItemCode], [Quantity], 
	[FromLocationNo], [ToLocationNo], [StatusCode], [CreateUser], [CreateMachine], [CompleteUser], 
	[CompleteMachine], [TransferCreateDate], [TransferCompleteDate], [TransferType], [ProductType], [CatalogID], 
	[SourceSystem], [SourceBatchNo], [SourceLineNo])

select 	st.ItemCode
		,1 [Quantity]
		,st.FromLocationNo
		,st.ToLocationNo
		,st.StatusCode
		,st.RequestedUser [CreateUser]
		,st.RequestedMachine [CreateMachine]
		,st.RequestedUser [CompleteUser]
		,st.RequestedMachine [CompleteMachine]
		,st.RequestedTime [TransferCreateDate]
		,st.RequestedTime [TransferCompleteDate]
		,case when coalesce(spi.Active, spih.Active) = 'T' then 1
			when coalesce(spi.Active, spih.Active) = 'D' then 2
			else 3 end [TransferType]
		,coalesce(spi.ProductType, spih.ProductType)
		,spm.CatalogId
		,1 [SourceSystem]
		,st.TransferBatchNo [SourceBatchNo]
		,rank () over (partition by st.TransferBatchNo order by st.RequestedTime, st.ItemCode) [SourceLineNo]
from SIPS.dbo.SipsTransfer st
left join archSIPS.dbo.vw_SipsProductInventoryHistory spih
	on spih.ItemCode = st.ItemCode
left join SIPS.dbo.SipsProductInventory spi
	on spi.ItemCode = st.ItemCode
left join SIPS.dbo.SipsProductMaster spm
	on spm.SipsID = coalesce(spi.SipsID, spih.SipsID)
left join SIPS.dbo.SipsTransferBinHeader h
	on h.SipsTransferBatchNo = st.TransferBatchNo
left join SIPS.dbo.InventoryItemTransfersAny a
	on a.SipsItemCode = st.ItemCode
	and a.FromLocationNo = st.FromLocationNo
	and a.ToLocationNo = st.ToLocationNo
where h.SipsTransferBatchNo is null
	and a.SipsItemCode is null
*/


/******************************************************************
SIPS Desktop Based Transfers
******************************************************************/
insert into Base_Analytics_Test.dbo.Transfers ([SipsItemCode], [DistributionItemCode], [Quantity], 
	[Cost], [FromLocationNo], [ToLocationNo], [StatusCode], [CreateUser], [CreateMachine], [CompleteUser], 
	[CompleteMachine], [TransferCreateDate], [TransferCompleteDate], [TransferType], [ProductType], 
	[SourceSystem], [SourceBatchNo], [SourceLineNo])

select	d.SipsItemCode
		,d.DipsItemCode [DistributionItemCode]
		,d.Quantity
		,d.DipsCost [Cost]
		,h.LocationNo [FromLocationNo]
		,h.ToLocationNo
		,d.StatusCode
		,d.CreateUser
		,d.CreateMachine
		,coalesce(d.UpdateUser, d.CreateUser) [CompleteUser]
		,coalesce(d.UpdateMachine, d.CreateMachine) [CompleteMachine]
		,h.CreateTime [TransferCreateDate]
		,coalesce(d.UpdateTime, d.CreateTime) [TransferCompleteDate]
		,h.TransferType
		--,coalesce(spih.ProductType, spi.ProductType, pm.ProductType) [ProductType] only need this when loading the first time
		,coalesce(spi.ProductType, pm.ProductType) [ProductType]
		,2 [SourceSystem]
		,h.TransferBinNo [SourceBatchNo]
		,d.ItemLineNo [SourceLineNo]
from ReportsData.dbo.SipsTransferBinHeader h
join ReportsData.dbo.SipsTransferBinDetail d
	on d.TransferBinNo = h.TransferBinNo
--for loading the table the first time
--left join archSIPS.dbo.vw_SipsProductInventoryHistory spih
--	on spih.ItemCode = d.SipsItemCode
left join ReportsData.dbo.SipsProductInventory spi
	on spi.ItemCode = d.SipsItemCode	
left join ReportsData.dbo.ProductMaster pm
	on pm.ItemCode = d.DipsItemCode
left join Base_Analytics_Test.dbo.Transfers t
	on t.SourceSystem = 2
	and t.SourceBatchNo = h.TransferBinNo
	and t.SourceLineNo = d.ItemLineNo
where d.StatusCode = 1
	and t.SourceSystem is null


/******************************************************************
SIPS Automated Transfer System
******************************************************************/
insert into Base_Analytics_Test.dbo.Transfers ([SipsItemCode], [DistributionItemCode], [Quantity], 
	[Cost], [FromLocationNo], [ToLocationNo], [StatusCode], [CreateUser], [CreateMachine], [CompleteUser], 
	[CompleteMachine], [TransferCreateDate], [TransferCompleteDate], [TransferType], [ProductType], 
	[SourceSystem], [SourceBatchNo], [SourceLineNo])

select	a.SipsItemCode
		,a.DipsItemCode [DistributionItemCode]
		,a.Quantity
		,a.DipsCost [Cost]
		,a.FromLocationNo
		,a.ToLocationNo
		,a.StatusCode
		,a.CreateUser
		,a.CreateMachine
		,a.CreateUser [CompleteUser]
		,a.CreateMachine [CompleteMachine]
		,a.TransferRequestDateTime [TransferCreateDate]
		,a.ProcessedDate [TransferCompleteDate]
		,a.TransferType
		,a.ProductType
		,3 [SourceSystem]
		,a.STMTransferBinNo [SourceBatchNo]
		,a.ProcessedSequence [SourceLineNo]		
from ReportsData.dbo.InventoryItemTransfersAny a
left join Base_Analytics_Test.dbo.Transfers t
	on t.SourceSystem = 3
	and t.SourceBatchNo = a.STMTransferBinNo
	and t.SourceLineNo = a.ProcessedSequence
where a.Processed = 1
	and t.SourceSystem is null


/******************************************************************
Update Catalog ID
******************************************************************/
--SIPS
update Base_Analytics.dbo.Transfers
	set CatalogID = spm.CatalogID
from Base_Analytics.dbo.Transfers t
join SIPS.dbo.SipsProductInventory spi
	on spi.ItemCode = t.SipsItemCode
join SIPS.dbo.SipsProductMaster spm
	on spm.SipsID = spi.SipsID
where t.CatalogID is null
	and spm.CatalogId is not null


--Distribution
update Base_Analytics.dbo.Transfers
	set CatalogID = coalesce(isbn.CatalogID, upc.CatalogID)
from Base_Analytics.dbo.Transfers t
join ReportsData.dbo.ProductMaster pm
	on pm.ItemCode = t.DistributionItemCode
join ReportsData.dbo.ProductMasterDist pmd
	on pmd.ItemCode = pm.ItemCode
left join Base_Analytics.dbo.GenericSKUs s
	on s.ItemCode = pm.ItemCode
left join Base_Analytics.dbo.Catalog_Lookup isbn
	on isbn.Identifier = pm.ISBN
left join Base_Analytics.dbo.Catalog_Lookup upc 
	on upc.Identifier = pmd.UPC
where s.ItemCode is null
	and coalesce(isbn.CatalogID, upc.CatalogID) is not null
	and t.CatalogID is null
	

