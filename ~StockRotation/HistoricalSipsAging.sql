/* Metrics needed
PNL, Buys, Rotation / Aging, FTE
*/

/* Table Setup > Dates
drop table #dates; drop table #periods; */

declare @endperiod datetime = '12/1/2019'
select cast(dateadd(yy,-6,@endperiod) as datetime) [StartDate], cast(dateadd(ss,-1,dateadd(mm,1,@endperiod)) as datetime) [EndDate] into #dates

declare @period datetime = (select dateadd(yy,2,StartDate) from #dates)
create table #periods (Period date, StartDate datetime, EndDate datetime)

while @period <= @endperiod
begin
	insert into #periods
	select
		cast(@period as date)
		,dateadd(ss,0,@period)
		,dateadd(ss,-1,dateadd(mm,1,@period))

	set @period = (select dateadd(mm,1,@period))
end

/* Base > Sales Transactions >
drop table #base_transactions */

select
	shh.SalesXactionID
	,shh.LocationID
	,shh.EndDate
	,slm.LocationNo
	,slm.DistrictName
	,slm.RegionName
into #base_transactions
from
--	rHPB_Historical..SalesHeaderHistory_Recent shh
	rHPB_Historical..SalesHeaderHistory shh
	inner join #dates d on
		shh.EndDate between d.StartDate and d.EndDate
	inner join MathLab..StoreLocationMaster slm on
		shh.LocationID = slm.LocationID
		and slm.StoreType = 'S'
where
	shh.Status = 'A'

/* Base > Transfers >
drop table #temp_transfers; drop table #base_transfers */

select
	sth.TransferBinNo
	,slm.LocationNo
	,sth.LocationNo [FromLocationNo]
	,sth.ToLocationNo
	,sth.UpdateTime
	,case when lo.LocationNo is not null then -1 else case when lx.LocationNo is not null then 0 end end [XferType] -- -1 = xfer out, 0 = trash
into #temp_transfers
from
	ReportsData..SipsTransferBinHeader sth
	inner join ReportsView..StoreLocationMaster slm on
		sth.LocationNo = slm.LocationNo
		and slm.StoreType = 'S'
	left outer join ReportsData..Locations lo on
		sth.ToLocationNo = lo.LocationNo
		and ((lo.LocationType = 'I' and lo.LocationNo not in ( --'00884',
			'00275','00290'))
			or (lo.LocationType = 'S' or lo.LocationNo = '00300'))
	left outer join ReportsData..Locations lx on
		sth.ToLocationNo = lx.LocationNo
		and ((lx.LocationType = 'T'
			and lx.LocationNo <> '00300')
				or lx.LocationNo in ('00275','00290'))
	inner join #dates d on
		sth.UpdateTime between d.StartDate and d.EndDate
where
	sth.StatusCode = '3';

insert into #temp_transfers
select
	sth.TransferBinNo
	,slm.LocationNo
	,sth.LocationNo [FromLocationNo]
	,sth.ToLocationNo
	,sth.UpdateTime
	,1 [XferType] -- 1 = xfer in
from
	ReportsData..SipsTransferBinHeader sth
	inner join ReportsView..StoreLocationMaster slm on
		sth.ToLocationNo = slm.LocationNo
		and slm.StoreType = 'S'
	inner join ReportsData..Locations li on
		sth.LocationNo = li.LocationNo
		and li.Status = 'A'
		and li.LocationType = 'S'
	inner join #dates d on
		sth.UpdateTime between d.StartDate and d.EndDate
where
	sth.StatusCode = '3';

select
	it.LocationNo
	,it.TransferBinNo
	,it.FromLocationNo
	,it.ToLocationNo
	,it.UpdateTime
	,it.XferType -- -1 = xfer out, 0 = trash, 1 = xfer in
	,pcm.Class
	,isnull(std.DipsCost,abc.Cost) * std.Quantity [Costs]
	,std.Quantity [Qty]
	,std.SipsItemCode
into #base_transfers
from
	ReportsData..SipsTransferBinDetail std
	inner join #temp_transfers it on
		it.TransferBinNo = std.TransferBinNo 
	left outer join ReportsData..AvgBookCost_v2 abc on
		std.AvgBookCostID = abc.AvgBookCostID
	left outer join ReportsData..ProductMaster pm with (nolock) on
		std.DipsItemCode = pm.ItemCode
	left outer join ReportsData..SipsProductInventory spi with (nolock) on
		std.SipsItemCode = spi.ItemCode
	left outer join MathLab..ProductClassificationMaster pcm on
		isnull(spi.ProductType, pm.ProductType) = pcm.ProductType
		and isnull(spi.SubjectKey,'-1') = pcm.SubjectKey
		and isnull(pm.SectionCode,'-1') = pcm.SectionCode		
where
	std.DipsCost < '500'
	and not(std.DipsCost > '75' and (DipsCost / std.Quantity) < '50') 
	and std.Quantity < '11000';

drop table #temp_transfers

/* Base > Sips >
drop table #temp_sips; drop table #temp_firstscans; drop table #sips_firstscans; drop table #temp_sipspricechangerank; drop table #sips_originalprice; 
drop table #sips_xfer; drop table #sips_storesales; drop table #sips_isales; drop table #temp_sipsdisposed; drop table #sips_disposed; drop table #base_sips; */

/* Base > Sips > Sips Item Codes >
drop table #temp_sips */

select
	spi.ItemCode [SipsItemCode]
	,slm.LocationNo
	,spi.DateInStock
	,spi.SipsID
	,spi.Price
into #temp_sips
from
	ReportsData..SipsProductInventory spi
	inner join ReportsView..StoreLocationMaster slm on
		spi.LocationID = slm.LocationId
		and slm.StoreType = 'S'
	inner join #dates d on
		spi.DateInStock between d.StartDate and d.EndDate

/* Base > Sips > Scans >
drop table #temp_scans; drop table #sips_scans */

select
	SipsItemCode
	,ScannedOn
into #temp_scans
from
	ReportsData..ShelfItemScan sis
	inner join #temp_sips s on
		sis.ItemCodeSips = s.SipsItemCode;

insert into #temp_scans
select
	SipsItemCode
	,ScannedOn
from
	ReportsData..ShelfItemScanHistory sis
	inner join #temp_sips s on
		sis.ItemCodeSips = s.SipsItemCode;

insert into #temp_scans
select
	SipsItemCode
	,ScannedOn
from
	archShelfScan..ShelfItemScanHistory_2009 sis
	inner join #temp_sips s on
		sis.ItemCodeSips = s.SipsItemCode;

insert into #temp_scans
select
	SipsItemCode
	,ScannedOn
from
	archShelfScan..ShelfItemScanHistory_2010 sis
	inner join #temp_sips s on
		sis.ItemCodeSips = s.SipsItemCode;

insert into #temp_scans
select
	SipsItemCode
	,ScannedOn
from
	archShelfScan..ShelfItemScanHistory_2011 sis
	inner join #temp_sips s on
		sis.ItemCodeSips = s.SipsItemCode;

insert into #temp_scans
select
	SipsItemCode
	,ScannedOn
from
	archShelfScan..ShelfItemScanHistory_2012 sis
	inner join #temp_sips s on
		sis.ItemCodeSips = s.SipsItemCode;

insert into #temp_scans
select
	SipsItemCode
	,ScannedOn
from
	archShelfScan..ShelfItemScanHistory_2013 sis
	inner join #temp_sips s on
		sis.ItemCodeSips = s.SipsItemCode;

insert into #temp_scans
select
	SipsItemCode
	,ScannedOn
from
	archShelfScan..ShelfItemScanHistory_2014 sis
	inner join #temp_sips s on
		sis.ItemCodeSips = s.SipsItemCode;

insert into #temp_scans
select
	SipsItemCode
	,ScannedOn
from
	archShelfScan..ShelfItemScanHistory_2015 sis
	inner join #temp_sips s on
		sis.ItemCodeSips = s.SipsItemCode;

insert into #temp_scans
select
	SipsItemCode
	,ScannedOn
from
	archShelfScan..ShelfItemScanHistory_2016 sis
	inner join #temp_sips s on
		sis.ItemCodeSips = s.SipsItemCode;

insert into #temp_scans
select
	SipsItemCode
	,ScannedOn
from
	archShelfScan..ShelfItemScanHistory_2017 sis
	inner join #temp_sips s on
		sis.ItemCodeSips = s.SipsItemCode;

insert into #temp_scans
select
	SipsItemCode
	,ScannedOn
from
	archShelfScan..ShelfItemScanHistory_2018 sis
	inner join #temp_sips s on
		sis.ItemCodeSips = s.SipsItemCode;

insert into #temp_scans
select
	SipsItemCode
	,ScannedOn
from
	archShelfScan..ShelfItemScanHistory_2019 sis
	inner join #temp_sips s on
		sis.ItemCodeSips = s.SipsItemCode;

select
	s.SipsItemCode
	,min(s.ScannedOn) [FirstScanned]
	,max(s.ScannedOn) [LastScanned]
into #temp_sips_scans
from
	#temp_scans s
group by
	s.SipsItemCode;

drop table #temp_scans;

/* Base > Sips > Price Changes >
drop table #temp_sipspricechangerank; drop table #sips_originalprice */

select
	t.SipsItemCode
	,spc.OldPrice
	,rank() over (partition by spc.ItemCode order by spc.ModifiedTime asc) [OriginalPriceRank]
into #temp_sipspricechangerank
from
	ReportsData..SipsPriceChanges spc
	inner join #temp_sips t on
		t.SipsItemCode = spc.ItemCode
where
	spc.OldPrice < 10000;

select
	t.SipsItemCode
	,isnull(s.OldPrice,t.Price) [OriginalPrice]
into #temp_sips_originalprice
from
	#temp_sips t
	left outer join #temp_sipspricechangerank s on
		t.SipsItemCode = s.SipsItemCode
		and s.OriginalPriceRank = 1
where
	isnull(s.OldPrice,t.Price) < 10000; 

drop table #temp_sipspricechangerank;


/* Base > Sips > Disposed >
drop table #temp_sips_xfer; drop table #temp_sips_storesales; drop table #temp_sips_isales; drop table #temp_sipsdisposed; drop table #temp_sips_disposed */

/* Base > Sips > Disposed > Xfers >
drop table #temp_sips_xfer */

select
	s.SipsItemCode
	,max(t.UpdateTime) [EndDate]
into #temp_sips_xfer
from
	#base_transfers t
	inner join #temp_sips s on
		t.SipsItemCode = s.SipsItemCode 
where
	t.XferType <= 0
group by
	s.SipsItemCode

/* Base > Sips > Disposed > Store Sales >
drop table #sips_storesales */

select
	s.SipsItemCode [SipsItemCode]
	,sum(ssh.ExtendedAmt) [Sales]
	,max(ssh.EndDate) [EndDate]
into #temp_sips_storesales
from
	ReportsData..SipsSalesHistory ssh -- I need to use this because I'm measuring from a Date Sips'd and not a Xfer Date perspective
	inner join #base_transactions it on
		ssh.SalesXactionId = it.SalesXactionID
		and ssh.LocationID = it.LocationID
	inner join #temp_sips s on
		ssh.SipsItemCode = s.SipsItemCode
group by
	s.SipsItemCode;

/* Base > Sips > Disposed > iStore Sales >
drop table #sips_isales */

select
	s.SipsItemCode [SipsItemCode]
	,sum(mo.Price - RefundAmount) [Sales]
	,max(ShipDate) [EndDate]
into #temp_sips_isales
from
	ReportsView..vw_MonsoonOrders mo
	inner join #temp_sips s on
		cast(replace(mo.SKU,'U','') as int) = s.SipsItemCode
where
	left(mo.SKU,1) = 'U'
	and mo.Status = 'Shipped'
	and mo.Location = 'At Location Sales'
group by
	s.SipsItemCode;

/* Base > Sips > Disposed > Compile >
drop table #temp_sipsdisposed; drop table #sips_disposed */

select
	SipsItemCode
	,Sales
	,EndDate
into #temp_sipsdisposed
from
	#temp_sips_storesales;

insert into #temp_sipsdisposed
select
	SipsItemCode
	,Sales
	,EndDate
from
	#temp_sips_isales;

insert into #temp_sipsdisposed
select
	SipsItemCode
	,0
	,EndDate
from
	#temp_sips_xfer;

select SipsItemCode, sum(Sales) [Sales], max(EndDate) [DisposalDate] into #temp_sips_disposed from #temp_sipsdisposed group by SipsItemCode;

drop table #temp_sipsdisposed;
drop table #temp_sips_storesales;
drop table #temp_sips_isales;
drop table #temp_sips_xfer;

/* Base > Sips > Compile
drop table #base_sips*/

select
	s.SipsItemCode
	,s.LocationNo
	,s.DateInStock
	,f.FirstScanned
	,f.LastScanned
	,s.SipsID
	,o.OriginalPrice
	,s.Price
	,isnull(sd.Sales,0) [Sales]
	,isnull(sd.DisposalDate, 
		case when dateadd(mm,8,f.LastScanned) < d.EndDate then dateadd(mm,8,f.LastScanned) else 
			case when f.LastScanned is null and dateadd(mm,12,s.DateInStock) < d.EndDate then dateadd(mm,12,s.DateInStock) else 
				d.EndDate end end) [DisposalDate]
into #base_sips
from
	#temp_sips s
	left outer join #temp_sips_scans f on
		s.SipsItemCode = f.SipsItemCode
	left outer join #temp_sips_originalprice o on
		s.SipsItemCode = o.SipsItemCode
	left outer join #temp_sips_disposed sd on
		s.SipsItemCode = sd.SipsItemCode
	inner join #dates d on 1=1

drop table #temp_sips
drop table #temp_sips_scans
drop table #temp_sips_originalprice
drop table #temp_sips_disposed

/* Period
drop table #period_pnl; drop table #period_fte; drop table #period_sips_rotation; drop table #period_data; drop table #annual_data; */

/* Period > PNL 
drop table #period_pnl; */

select
	Period
	,LocationNo
	,Income [Pnl_Income]
	,[Purchases-Other] [Pnl_DistroPurchases]
	,GrossProfit [Pnl_GrossProfit]
	,StoreExpenses [Pnl_StoreExpenses]
	,NetIncomeLoss [Pnl_NetProfit]
	,Payroll [Pnl_Payroll]
into #period_pnl
from
	#periods p
	left outer join Reportsview..Pnl pnl on
		pnl.Date between p.StartDate and p.EndDate
	inner join ReportsView..StoreLocationMaster slm on
		pnl.Loc = slm.Loc
		and slm.StoreType = 'S'

/* Period > FTE 
drop table #period_fte; */

select
	Period
	,LocationNo
	,sum(Hours) [FTE_Hours]
	,sum(FTE) [FTE]
into #period_fte
from
	#periods p
	left outer join Reportsview..FTE fte on
		fte.PeriodEndDate between dateadd(ww,-4,p.EndDate) and p.EndDate
	inner join ReportsView..StoreLocationMaster slm on
		fte.Loc = slm.Loc
		and slm.StoreType = 'S'
group by
	Period
	,LocationNo

/* Period > Sips Rotations >
drop table #period_sips_rotation; */

select
	p.Period
	,s.LocationNo
	,cast(isnull(count(s.SipsItemCode),0) as decimal(18,3)) [Sips_TotalQtyInStock]
	,cast(isnull(count(case when cast(datediff(ss,s.DateInStock,case when s.DisposalDate <= p.EndDate then s.DisposalDate else p.EndDate end) as decimal(18,3)) / 60 / 60 / 24 <= 30 then s.SipsItemCode end),0) as decimal(18,3)) [Sips_TotalQtyInStock_Under30]
	,cast(isnull(count(case when cast(datediff(ss,s.DateInStock,case when s.DisposalDate <= p.EndDate then s.DisposalDate else p.EndDate end) as decimal(18,3)) / 60 / 60 / 24 <= 60 then s.SipsItemCode end),0) as decimal(18,3)) [Sips_TotalQtyInStock_Under60]
	,cast(isnull(count(case when cast(datediff(ss,s.DateInStock,case when s.DisposalDate <= p.EndDate then s.DisposalDate else p.EndDate end) as decimal(18,3)) / 60 / 60 / 24 <= 90 then s.SipsItemCode end),0) as decimal(18,3)) [Sips_TotalQtyInStock_Under90]
	,cast(isnull(count(case when cast(datediff(ss,s.DateInStock,case when s.DisposalDate <= p.EndDate then s.DisposalDate else p.EndDate end) as decimal(18,3)) / 60 / 60 / 24 <= 180 then s.SipsItemCode end),0) as decimal(18,3)) [Sips_TotalQtyInStock_Under180]
	,cast(isnull(count(case when cast(datediff(ss,s.DateInStock,case when s.DisposalDate <= p.EndDate then s.DisposalDate else p.EndDate end) as decimal(18,3)) / 60 / 60 / 24 <= 364 then s.SipsItemCode end),0) as decimal(18,3)) [Sips_TotalQtyInStock_Under364]
	,isnull(sum(cast(datediff(ss,s.DateInStock,case when s.DisposalDate <= p.EndDate then s.DisposalDate else p.EndDate end) as decimal(18,3))),0) / 60 / 60 / 24 [Sips_TotalDaysInStock]
	,isnull(cast(count(case when s.DateInStock between p.StartDate and p.EndDate then s.SipsItemCode end) as decimal(18,3)),0) [Sips_QtyAdded]
	,isnull(sum(cast(datediff(ss, case when s.DateInStock < p.StartDate then p.StartDate else s.DateInStock end, case when s.DisposalDate > p.EndDate then p.EndDate else s.DisposalDate end) as decimal(18,3))),0) / 60 / 60 / 24 [Sips_DaysInStock]
	,isnull(sum(case when s.Sales > 0 and s.DisposalDate <= p.EndDate then cast(datediff(ss, s.DateInStock, s.DisposalDate) as decimal(18,3)) else 0 end),0) / 60 / 60 /24 [Sips_DaysToSell]
	,cast(isnull(count(case when s.Sales > 0 and s.DisposalDate <= p.EndDate then SipsItemCode end),0) as decimal(18,3)) [Sips_QtySold]
	,cast(isnull(sum(case when s.Sales > 0 and s.DisposalDate <= p.EndDate then s.Sales end),0) as decimal(18,3)) [Sips_Sales]
into #period_sips_rotation
from
	#periods p
	left outer join #base_sips s on
		s.DateInStock between dateadd(ww,-104,p.StartDate) and p.EndDate
		and s.DisposalDate >= p.StartDate
group by
	p.Period
	,s.LocationNo

/* Data 
drop table #period_data; drop table #annual_data */

select
	p.Period
	,slm.LocationNo
	,slm.StoreSize [SqFt]
	,sr.Sips_QtyAdded
	,sr.Sips_DaysInStock
	,sr.Sips_DaysToSell
	,sr.Sips_QtySold
	,sr.Sips_Sales
	,sr.Sips_TotalDaysInStock
	,sr.Sips_TotalQtyInStock
	,sr.Sips_TotalQtyInStock_Under30
	,sr.Sips_TotalQtyInStock_Under60
	,sr.Sips_TotalQtyInStock_Under90
	,sr.Sips_TotalQtyInStock_Under180
	,sr.Sips_TotalQtyInStock_Under364
	,fte.FTE
	,fte.FTE_Hours
	,pnl.Pnl_Income
	,pnl.Pnl_GrossProfit
	,pnl.Pnl_Payroll
	,pnl.Pnl_NetProfit
	,pnl.Pnl_StoreExpenses
into #period_data
from
	#periods p
	inner join ReportsView..StoreLocationMaster slm on
		slm.OpenDate <= p.StartDate
		and (slm.ClosedDate is null or slm.ClosedDate >= p.EndDate)
		and slm.StoreType = 'S'
	left outer join #period_sips_rotation sr on
		p.Period = sr.Period
		and slm.LocationNo = sr.LocationNo	
	left outer join #period_fte fte on
		p.Period = fte.Period
		and slm.LocationNo = fte.LocationNo	
	left outer join #period_pnl pnl on
		p.Period = pnl.Period
		and slm.LocationNo = pnl.LocationNo	

/* Annual > Data 
drop table #annual_data; */

select * into #annual_data from #period_data where 0 = 1

insert into #annual_data
select
	p.Period
	,pd.LocationNo
	,pd.SqFt
	,sum(pd.Sips_QtyAdded)
	,sum(pd.Sips_DaysInStock)
	,sum(pd.Sips_DaysToSell)
	,sum(pd.Sips_QtySold)
	,sum(pd.Sips_Sales)
	,sum(pd.Sips_TotalDaysInStock)
	,sum(pd.Sips_TotalQtyInStock)
	,sum(pd.Sips_TotalQtyInStock_Under30)
	,sum(pd.Sips_TotalQtyInStock_Under60)
	,sum(pd.Sips_TotalQtyInStock_Under90)
	,sum(pd.Sips_TotalQtyInStock_Under180)
	,sum(pd.Sips_TotalQtyInStock_Under364)
	,sum(pd.FTE)
	,sum(pd.FTE_Hours)
	,sum(pd.Pnl_Income)
	,sum(pd.Pnl_GrossProfit)
	,sum(pd.Pnl_Payroll)
	,sum(pd.Pnl_NetProfit)
	,sum(pd.Pnl_StoreExpenses)
from
	#periods p
	inner join #dates d on
		p.StartDate between dateadd(yy,2,d.StartDate) and d.EndDate
	inner join ReportsView..StoreLocationMaster slm on
		slm.OpenDate <= dateadd(yy,-1,p.StartDate)
		and (slm.ClosedDate is null or slm.ClosedDate > p.EndDate)
		and slm.StoreType = 'S'
	left outer join #period_data pd on
		pd.LocationNo = slm.LocationNo
		and pd.Period between dateadd(mm,-11,p.Period) and p.Period
group by
	p.Period
	,pd.LocationNo
	,pd.SqFt

select 'Period Data'
select * from #period_data order by Period, LocationNo

select 'Annual Data'
select * from #annual_data order by Period, LocationNo