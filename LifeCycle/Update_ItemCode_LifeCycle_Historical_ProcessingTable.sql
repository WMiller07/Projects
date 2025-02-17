USE [Sandbox]
GO
/****** Object:  StoredProcedure [dbo].[Update_ItemCode_LifeCycle_Historical_ProcessingTable]    Script Date: 11/25/2019 4:42:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER procedure [dbo].[Update_ItemCode_LifeCycle_Historical_ProcessingTable]

as

/******************************************************************
Updating the processing table

This will be exapnded as we find new reasons to re-process 
items because of particular scenarios.

At some point we may want to reprocess items that have been
sold since the item life cycle flag was set to completed. 

Right now, I believe they are supposed to reprice all items
returned or bought that have a bar code on them.  We can discuss
this point in an upcoming meeting.
******************************************************************/

--update processing row for reprocessing
create table #updates (itemcode int primary key)

--Get items that have been scanned after the item life cycle was set as complete
--insert into #updates (itemcode)
--select lc.ItemCode
--from Sandbox.dbo.ItemCode_LifeCycle_Historical lc
--join Base_Analytics_Cashew.dbo.ShelfScan ss
--	on lc.ItemCode = ss.ItemCodeSips
--where (lc.LifeCycle_Complete = 1 and ss.ScannedOn > lc.InsertTime)
--group by lc.ItemCode

----Get items that have been transferred after the item code has been set as complete
--insert into #updates (itemcode)
--select lc.ItemCode
--from Sandbox.dbo.ItemCode_LifeCycle_Historical lc
--join Base_Analytics_Cashew.dbo.Transfers t
--	on t.SipsItemCode = lc.ItemCode
--left join #updates u
--	on u.itemcode = lc.ItemCode
--where t.TransferCompleteDate > lc.InsertTime
--	and lc.LifeCycle_Complete = 1
--	and u.itemcode is null
--group by lc.ItemCode

----update the scanned items as unprocessed and delete the rows
----from the life cycle table
--update Sandbox.dbo.ProductLifeCycle_Processing_Historical
--	set Processed = 0
--where ItemCode in (select itemcode from #updates)

--drop table #updates


----Set the items currently having life cycle complete flag set to 0
--update Sandbox.dbo.ProductLifeCycle_Processing_Historical
--	set Processed = 0
--from Sandbox.dbo.ProductLifeCycle_Processing_Historical p
--join Sandbox.dbo.ItemCode_LifeCycle lc
--	on lc.ItemCode = p.ItemCode
--where lc.LifeCycle_Complete = 0


--delete all rows in the life cycle table where the item code is set to
--be reprocessed
--delete from Sandbox.dbo.ItemCode_LifeCycle_Historical
--from Sandbox.dbo.ItemCode_LifeCycle_Historical lc
--join Sandbox.dbo.ProductLifeCycle_Processing_Historical p
--	on p.ItemCode = lc.ItemCode
--where p.Processed = 0


--insert new items
insert into Sandbox.dbo.ProductLifeCycle_Processing_Historical (ItemCode, Processed)
select pu.ItemCode, 0
from Sandbox.dbo.Products_Used_Historical pu
left join Sandbox.dbo.ProductLifeCycle_Processing_Historical lc
	on lc.ItemCode = pu.ItemCode
where lc.ItemCode is null

--update existing items that have changed catalog id
--update Sandbox.dbo.ItemCode_LifeCycle_Historical
--	set CatalogID = pu.CatalogId
--from Sandbox.dbo.ItemCode_LifeCycle_Historical lc
--join Sandbox.dbo.Products_Used_Historical pu
--	on pu.ItemCode = lc.ItemCode
--where isnull(lc.CatalogID, 0) <> isnull(pu.CatalogId, 0)	

