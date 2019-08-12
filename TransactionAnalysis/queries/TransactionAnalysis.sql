
declare @enddate date

set @enddate = '7/22/2019' -- date not included

create table #dates (StartDate date, EndDate date)
insert into #dates values (dateadd(yy,-1,@enddate), @enddate)

-- drop table #salestrans
select
       slm.LocationNo
       ,shh.LocationID
       ,shh.SalesXactionID
       ,shh.EndDate
into #salestrans
from
       HPB_SALES..SHH2019 shh
       inner join MathLab..StoreLocationMaster slm on
              shh.LocationID = slm.LocationId
              and slm.StoreType = 'S'
       inner join #dates d on
              shh.EndDate between d.StartDate and d.EndDate
where
       shh.Status = 'A'

insert into #salestrans
select
       slm.LocationNo
       ,shh.LocationID
       ,shh.SalesXactionID
       ,shh.EndDate
from
       HPB_SALES..SHH2018 shh
       inner join MathLab..StoreLocationMaster slm on
              shh.LocationID = slm.LocationId
              and slm.StoreType = 'S'
       inner join #dates d on
              shh.EndDate between d.StartDate and d.EndDate
where
       shh.Status = 'A'

-- drop table #storesales
select
       st.LocationNo
       ,st.LocationID
       ,st.SalesXactionID
       ,st.EndDate
       ,sih.ItemCode
       ,sih.ODPCCode [CouponCode]
       ,count(*) [QtySold]
       ,sum(sih.ExtendedAmt) [Sales]
       ,sum(sih.DiscountAmt) [Discounts]
into #storesales
from
       HPB_SALES..SIH2019 sih
       inner join #salestrans st on
              sih.LocationID = st.LocationID
              and sih.SalesXactionID = st.SalesXactionID
where
       sih.ItemCode not like '%[^0-9]%'
group by
       st.LocationNo
       ,st.LocationID
       ,st.SalesXactionID
       ,st.EndDate
       ,sih.ItemCode
       ,sih.ODPCCode

insert into #storesales
select
       st.LocationNo
       ,st.LocationID
       ,st.SalesXactionID
       ,st.EndDate
       ,sih.ItemCode
       ,sih.ODPCCode [CouponCode]
       ,count(*) [QtySold]
       ,sum(sih.ExtendedAmt) [Sales]
       ,sum(sih.DiscountAmt) [Discounts]
from
       HPB_SALES..SIH2018 sih
       inner join #salestrans st on
              sih.LocationID = st.LocationID
              and sih.SalesXactionID = st.SalesXactionID
where
       sih.ItemCode not like '%[^0-9]%'
group by
       st.LocationNo
       ,st.LocationID
       ,st.SalesXactionID
       ,st.EndDate
       ,sih.ItemCode
       ,sih.ODPCCode






-- drop table #itemcodes
select
       ItemCode
into #itemcodes
from
       #storesales
group by
       ItemCode

-- drop table #temp_itemcodes_details
select
       ic.ItemCode
       ,case when bi.ItemCode is null then pm.ItemCode end [DipsItemCode]
       ,bi.ItemCode [BaseItemCode]
       ,spi.ItemCode [SipsItemCode]
       ,spi.SipsID
       ,coalesce(spi.ProductType, pm.ProductType) [ProductType]
       ,pm.SectionCode
       ,pcm.FPSection
       ,case when dateadd(mm,-6,spi.DateInStock) <= spm.PubDate then 91 else spi.SubjectKey end [SubjectKey]
       ,spi.LocationNo [SipsLocationNo]
       ,pm.Cost [DipsCost]
into #temp_itemcodes_details
from
       #itemcodes ic
       left outer join ReportsView..vw_BaseInventory bi on
              ic.ItemCode = bi.ItemCode
       left outer join ReportsData..SipsProductInventory spi on
              left(ic.ItemCode,1) <> '0'
              and cast(right(ic.ItemCode,9) as int) = spi.ItemCode
       left outer join ReportsData..SipsProductMaster spm on
              spi.SipsID = spm.SipsID
       left outer join ReportsData..ProductMaster pm on
              left(ic.ItemCode,1) = '0'
              and ic.ItemCode = pm.ItemCode
       left outer join MathLab..ProductClassificationMaster pcm on
              pm.ProductType = pcm.ProductType
              and pm.SectionCode = pcm.SectionCode

-- drop table #basecosts
select
       ss.LocationID
       ,ss.SalesXactionID
       ,ss.ItemCode
       ,isnull(avg(abc.LineOfferSum / nullif(abc.Quantity,0)), avg(abc.Cost)) [BaseCost]
into #basecosts
from
       #storesales ss
       inner join #temp_itemcodes_details ic on
              ss.ItemCode = ic.ItemCode
              and ic.BaseItemCode is not null
       left outer join ReportsData..AvgBookCost_v2 abc on
              ss.LocationNo = abc.LocationNo
              and ic.ProductType = abc.ProductType
              and cast(dateadd(month, datediff(month, 0, ss.EndDate), 0) as date) = abc.FirstDayOfMonth
group by
       ss.LocationID
       ,ss.SalesXactionID
       ,ss.ItemCode

/** Sips Actual Costs **/

-- drop table #temp_sipsbuys
select
       bbi.SipsID
       ,bbi.LocationNo
       ,sum(bbi.Offer) [Offers]
       ,sum(bbi.Quantity) [Qty]
       ,avg(bbi.Offer / nullif(bbi.Quantity,0)) [AvgOffer]
into #temp_sipsbuys
from
       Buys..BuyBinItems bbi
       inner join Buys..BuyBinHeader bbh on
              bbi.LocationNo = bbh.LocationNo
              and bbi.BuyBinNo = bbh.BuyBinNo
              and bbh.StatusCode = '1'
       inner join #dates d on
              bbh.CreateTime between dateadd(dd,-1,d.StartDate) and d.EndDate
       inner join Buys..BuyTypes bt on
              bbi.BuyTypeID = bt.BuyTypeID
where
       bbi.StatusCode = '1'
       and bbi.SipsID is not null
group by
       bbi.SipsID
       ,bbi.LocationNo

-- drop table #sipsbuys
select
       SipsID
       ,LocationNo
       ,AvgOffer
       ,sum(Qty) [QtyOffers]
into #sipsbuys
from
       #temp_sipsbuys
group by
       SipsID
       ,LocationNo
       ,AvgOffer

insert into #sipsbuys
select
       SipsID
       ,'00000'
       ,sum(Offers) / nullif(sum(Qty),0) [AvgOffer]
       ,sum(Qty) [QtyOffers]
from
       #temp_sipsbuys
group by
       SipsID



-- drop table #temp_sipsitemcodes
select
       spi.ItemCode [SipsItemCode],
       spm.SipsID,
       spi.ProductType,
       case when dateadd(mm,-6,spi.DateInStock) <= spm.PubDate then 91 else spi.SubjectKey end [SubjectKey],
       spi.LocationNo,
       1 [Source]
into #temp_sipsitemcodes
from
       ReportsData..SipsProductInventory spi
       inner join ReportsData..SipsProductMaster spm on
              spi.SipsID = spm.SipsID
       inner join #dates d on
              spi.DateInStock between dateadd(yy,-1,d.StartDate) and d.EndDate


insert into #temp_sipsitemcodes
select
       ic.SipsItemCode
       ,ic.SipsID
       ,ic.ProductType
       ,ic.SubjectKey
       ,ic.SipsLocationNo
       ,2
from
       #temp_itemcodes_details ic
where
       ic.SipsItemCode is not null

-- drop table #temp_sipsitemcodes2

select
       ic.SipsItemCode
       ,ic.SipsID
       ,ic.ProductType
       ,ic.SubjectKey
       ,ic.LocationNo
into #temp_sipsitemcodes2
from
       #temp_sipsitemcodes ic
group by
       ic.SipsItemCode
       ,ic.SipsID
       ,ic.ProductType
       ,ic.SubjectKey
       ,ic.LocationNo



/*
drop table #temp_scans
drop table #temp_scans2
*/
select
       sic.SipsItemCode
       ,sis.ScannedOn
       ,sis.ShelfItemScanID
       ,s.SubjectKey [SubjectKey]
into #temp_scans
from
       #temp_sipsitemcodes2 sic
       left outer join ReportsData..ShelfItemScan sis on
              sic.SipsItemCode = sis.ItemCodeSips
       left outer join ReportsData..ShelfScan ss on
              sis.ShelfScanID = ss.ShelfScanID
       left outer join ReportsData..ShelfScanHistory ssh on
              sis.ShelfScanID = ssh.ShelfScanID
       left outer join ReportsData..Shelf s on
              isnull(ss.ShelfID,ssh.ShelfID) = s.ShelfID

insert into #temp_scans
select
       sic.SipsItemCode
       ,sis.ScannedOn
       ,sis.ShelfItemScanID
       ,s.SubjectKey [SubjectKey]
from
       #temp_sipsitemcodes2 sic
       left outer join archShelfScan..ShelfItemScanHistory_2018 sis on
              sic.SipsItemCode = sis.ItemCodeSips
       left outer join ReportsData..ShelfScan ss on
              sis.ShelfScanID = ss.ShelfScanID
       left outer join ReportsData..ShelfScanHistory ssh on
              sis.ShelfScanID = ssh.ShelfScanID
       left outer join ReportsData..Shelf s on
              isnull(ss.ShelfID,ssh.ShelfID) = s.ShelfID

insert into #temp_scans
select
       sic.SipsItemCode
       ,sis.ScannedOn
       ,sis.ShelfItemScanID
       ,s.SubjectKey [SubjectKey]
from
       #temp_sipsitemcodes2 sic
       left outer join archShelfScan..ShelfItemScanHistory_2017 sis on
              sic.SipsItemCode = sis.ItemCodeSips
       left outer join ReportsData..ShelfScan ss on
              sis.ShelfScanID = ss.ShelfScanID
       left outer join ReportsData..ShelfScanHistory ssh on
              sis.ShelfScanID = ssh.ShelfScanID
       left outer join ReportsData..Shelf s on
              isnull(ss.ShelfID,ssh.ShelfID) = s.ShelfID

select
       ts.SipsItemCode
       ,rank() over (partition by ts.SipsItemCode order by ts.ScannedOn desc, ts.ShelfItemScanID) [LastScan]
       ,ts.SubjectKey
into #temp_scans2
from
       #temp_scans ts
where
       ScannedOn is not null


-- drop table #temp_sips_actualcosts
-- drop table #sipsitemcodes
select
       sic.SipsItemCode
       ,sic.SipsID
       ,isnull(pcm_ss.FPSection, pcm.FPSection) [FPSection]
       ,sic.ProductType
       ,isnull(ts.SubjectKey, sic.SubjectKey) [SubjectKey]
       ,pcm.Product
       ,sic.LocationNo
into #sipsitemcodes
from
       #temp_sipsitemcodes2 sic
       left outer join #temp_scans2 ts on
              sic.SipsItemCode = ts.SipsItemCode
              and ts.LastScan = 1
       left outer join MathLab..ProductClassificationMaster_ScanSubject pcm_ss on
              isnull(ts.SubjectKey, sic.SubjectKey) = pcm_ss.SubjectKey
       left outer join MathLab..ProductClassificationMaster pcm on
              sic.ProductType = pcm.ProductType
              and isnull(ts.SubjectKey, sic.SubjectKey) = pcm.SubjectKey


/*
drop table #temp_sips_actualcosts
drop table #temp_section_offers
drop table #sipscosts
drop table #itemcosts_sips
*/

select
       sic.SipsItemCode
       ,sic.FPSection
       ,isnull(sb.AvgOffer,sb_a.AvgOffer) [Offer]
       -- get qty offers for later filters (say we don't have enough offers to justify the data)
       ,sb.QtyOffers [LocQtyOffers] 
       ,sb_a.QtyOffers [ChainQtyOffers]
into #temp_sips_actualcosts
from
       #sipsitemcodes sic
       left outer join #sipsbuys sb on
              sic.SipsID = sb.SipsID
              and sic.LocationNo = sb.LocationNo
       left outer join #sipsbuys sb_a on
              sic.SipsID = sb_a.SipsID
              and sb_a.LocationNo = '00000'

select
       FPSection
       ,avg(Offer) [Offer]
into
       #temp_section_offers
from
       #temp_sips_actualcosts
group by
       FPSection
       
select
       sic.SipsItemCode
       ,isnull(ts_ac.Offer,ts_o.Offer) [Offer]
into #sipscosts
from
       #sipsitemcodes sic
       left outer join #temp_sips_actualcosts ts_ac on
              sic.SipsItemCode = ts_ac.SipsItemCode
       left outer join #temp_section_offers ts_o on
              sic.FPSection = ts_o.FPSection

























-- drop table #salesdetails
select
       ss.LocationNo
       ,ss.LocationID
       ,ss.SalesXactionID
       ,ss.EndDate
       ,ss.ItemCode
       ,ic.DipsItemCode
       ,ic.SipsItemCode
       ,ic.BaseItemCode
       ,ss.QtySold
       ,ss.Sales
       ,ss.Discounts
       ,ss.CouponCode
       ,coalesce(sc.Offer, ic.DipsCost, bc.BaseCost) * ss.QtySold  [Costs]
       ,case when ic.DipsItemCode is not null then 'Distro' else 'Used' end [Class]
       ,coalesce(sas.FPSection, sic.FPSection, ic.FPSection) [FPSection]
       ,ic.ProductType
into #salesdetails
from
       #storesales ss
       left outer join #temp_itemcodes_details ic on
              ss.ItemCode = ic.ItemCode -- is there only one record of each itemcode on ic?
       left outer join #sipsitemcodes sic on
              ic.SipsItemCode = sic.SipsItemCode
       left outer join #sipscosts sc on
              ic.SipsItemCode = sc.SipsItemCode
       left outer join #basecosts bc on
              ss.LocationID = bc.LocationID
              and ss.SalesXactionID = bc.SalesXactionID
              and ss.ItemCode = bc.ItemCode
       left outer join MathLab..SurveyAssignedSections sas on
              ss.LocationNo = sas.LocationNo
              and isnull(sic.FPSection, ic.FPSection) = sas.PCM_FPSection

select * 
from #salesdetails
where EndDate between '6/1/2019' and '7/1/2019'
order by EndDate ASC

drop table #basecosts
drop table #dates
drop table #itemcodes
drop table #salesdetails
drop table #salestrans
drop table #sipsbuys
drop table #sipscosts
drop table #sipsitemcodes
drop table #storesales
drop table #temp_itemcodes_details
drop table #temp_scans
drop table #temp_scans2
drop table #temp_section_offers
drop table #temp_sips_actualcosts
drop table #temp_sipsbuys
drop table #temp_sipsitemcodes
drop table #temp_sipsitemcodes2
