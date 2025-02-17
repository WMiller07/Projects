DECLARE @NRF_StartWeek INT = 1
DECLARE @NRF_StartYear CHAR(4) = '2018'
DECLARE @StartDate DATE
DECLARE @EndDate DATE =  DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)

SELECT
	@StartDate = MIN(nd.Store_Date)
FROM MathLab..NRF_Daily nd
WHERE nd.NRF_Week_Restated = @NRF_StartWeek
AND nd.NRF_Year = @NRF_StartYear

SELECT
	slm.DistrictName,
	slm.LocationNo,
	nd.Store_Date,
	nd.NRF_Week_Restated,
	CAST(nd.NRF_Year AS INT) [NRF_Year],
	ROW_NUMBER() OVER (PARTITION BY nd.NRF_Year, LocationNo ORDER BY nd.Store_Date) [NRF_Day],
	CASE 
		WHEN slm.OpenDate <= DATEADD(YEAR, -5, @StartDate)
			AND slm.StoreType = 'S'
		THEN 1 
		END [bool_CompStore]
INTO #KeyTable
FROM MathLab..NRF_Daily nd
	CROSS JOIN ReportsData..StoreLocationMaster slm
WHERE nd.Store_Date >= @StartDate
	AND nd.Store_Date < @EndDate
	AND slm.StoreType IN ('S', 'O')
	AND slm.ClosedDate IS NULL
ORDER BY LocationNo, Store_Date

SELECT 
	spi.LocationNo,
	spi.ProductType,
	spi.ItemCode,
	spi.SipsID,
	spi.Price,
	spi.DateInStock
INTO #SipsProductInventory
FROM ReportsData..SipsProductInventory spi

SELECT
	shh.LocationID,
	shh.SalesXactionID,
	shh.EndDate [BusinessDate],
	sih.ItemCode,
	sih.Quantity,
	sih.RegisterPrice,
	sih.ExtendedAmt
INTO #Sales
FROM HPB_SALES..SHH2018 shh
	INNER JOIN HPB_SALES..SIH2018 sih
		ON shh.SalesXactionID = sih.SalesXactionId
		AND shh.LocationID = sih.LocationID
		AND shh.[Status] = 'A'									--Accepted sales only (exclude voids)
		AND sih.[Status] = 'A'
WHERE shh.EndDate >= @StartDate
	AND shh.EndDate < @EndDate
UNION
SELECT
	shh.LocationID,
	shh.SalesXactionID,
	shh.EndDate [BusinessDate],
	sih.ItemCode,
	sih.Quantity,
	sih.RegisterPrice,
	sih.ExtendedAmt
FROM HPB_SALES..SHH2019 shh
	INNER JOIN HPB_SALES..SIH2019 sih
		ON shh.SalesXactionID = sih.SalesXactionId
		AND shh.LocationID = sih.LocationID
		AND shh.[Status] = 'A'									--Accepted sales only (exclude voids)
		AND sih.[Status] = 'A'
WHERE shh.EndDate >= @StartDate
	AND shh.EndDate < @EndDate
UNION
SELECT
	shh.LocationID,
	shh.SalesXactionID,
	shh.EndDate [BusinessDate],
	sih.ItemCode,
	sih.Quantity,
	sih.RegisterPrice,
	sih.ExtendedAmt
FROM HPB_SALES..SHH2020 shh
	INNER JOIN HPB_SALES..SIH2020 sih
		ON shh.SalesXactionID = sih.SalesXactionId
		AND shh.LocationID = sih.LocationID
		AND shh.[Status] = 'A'									--Accepted sales only (exclude voids)
		AND sih.[Status] = 'A'
WHERE shh.EndDate >= @StartDate
	AND shh.EndDate < @EndDate

SELECT 
	slm.LocationNo,
	s.BusinessDate,
	s.SalesXactionID,
	CASE 
		WHEN spi.ItemCode IS NOT NULL 
		OR bi.ItemCode IS NOT NULL
			THEN 'Used'
		WHEN pm.ItemCode IS NOT NULL
		AND pm.ProductType NOT LIKE '%F'
		AND bi.ItemCode IS NULL
			THEN 'New'
		WHEN pm.ItemCode IS NOT NULL
		AND pm.ProductType LIKE '%F'
		AND bi.ItemCode IS NULL
			THEN 'Frontline' 
		ELSE 'Used'
		END [ProductClass],
	LTRIM(RTRIM(ISNULL(spi.ProductType, pm.ProductType))) [ProductType],
	CASE 
		WHEN s.RegisterPrice < 0 
		THEN -s.Quantity 
		ELSE s.Quantity 
		END [Quantity],
	ISNULL(spi.Price, pm.Price) [OriginalPrice],  --spi.Price should be substituted with pricechange Original Price in the future
	s.RegisterPrice,
	s.ExtendedAmt,
	CASE 
		WHEN s.RegisterPrice = ROUND(s.RegisterPrice, 0) 
		AND LTRIM(RTRIM(ISNULL(spi.ProductType, pm.ProductType))) NOT IN ('CX', 'MG', 'NOST')
		AND s.RegisterPrice <= 3.00
		THEN 1
		END [isClearance],
	CASE 
		WHEN s.RegisterPrice <= 0.75 * ISNULL(spi.Price, pm.Price)
		AND s.RegisterPrice <> ROUND(s.RegisterPrice, 0)
		AND s.RegisterPrice > 3.00
		THEN 1
		END [isMarkDown]
INTO #Sales_pre
FROM #Sales s
	INNER JOIN ReportsData..StoreLocationMaster slm
		ON s.LocationID = slm.LocationID
	LEFT OUTER JOIN ReportsData..ProductMaster pm
		ON  LEFT(s.ItemCode, 1) = '0'							--Distro items start with 0 in the sales tables
		AND s.ItemCode = pm.ItemCode							--Distro item codes in the sales tables ARE stored in the same format as the inventory tables.
	LEFT OUTER JOIN ReportsData..BaseInventory bi
		ON LEFT(s.ItemCode, 1) = '0'
		AND s.ItemCode = bi.ItemCode
	LEFT OUTER JOIN #SipsProductInventory spi
		ON	LEFT(s.ItemCode, 1) <> '0'							--Used items start non-zero values in the sales tables
		AND CAST(RIGHT(s.ItemCode, 9) AS INT) = spi.ItemCode	--Item codes in the sales tables are not stored in the same format as the inventory tables
WHERE s.ItemCode NOT LIKE '%[^0-9]%'							


DROP TABLE #Sales

SELECT 
	kt.LocationNo,
	kt.Store_Date,
	/***************
	Sales
	****************/
	--Totals
	COUNT(DISTINCT s.SalesXactionID) [sales_CountTransactions],
	SUM(s.Quantity) [sales_QtySold],
	SUM(s.ExtendedAmt) [sales_AmtSold],
	--Totals by class
	SUM(CASE
			WHEN s.ProductClass = 'Used'
			THEN s.Quantity
			END) [sales_QtySold_Used],
	SUM(CASE
			WHEN s.ProductClass = 'New'
			THEN s.Quantity
			END) [sales_QtySold_New],
	SUM(CASE
			WHEN s.ProductClass = 'Frontline'
			THEN s.Quantity
			END) [sales_QtySold_Frontline],
	SUM(CASE
			WHEN s.ProductClass = 'Used'
			THEN s.ExtendedAmt
			END) [sales_AmtSold_Used],
	SUM(CASE
			WHEN s.ProductClass = 'New'
			THEN s.ExtendedAmt
			END) [sales_AmtSold_New],
	SUM(CASE
			WHEN s.ProductClass = 'Frontline'
			THEN s.ExtendedAmt
			END) [sales_AmtSold_Frontline],
	--Clearance totals by class
	SUM(CASE
			WHEN s.ProductClass = 'Used'
			AND s.isClearance = 1
			THEN s.Quantity
			END) [sales_QtySoldClearance_Used],
	SUM(CASE
			WHEN s.ProductClass IN ('New', 'Frontline')
			AND s.isClearance = 1
			THEN s.Quantity
			END) [sales_QtySoldClearance_FrontlineNew],
	SUM(CASE
			WHEN s.ProductClass = 'Used'
			AND s.isClearance = 1
			THEN s.ExtendedAmt
			END) [sales_AmtSoldClearance_Used],
	SUM(CASE
			WHEN s.ProductClass IN ('New', 'Frontline')
			AND s.isClearance = 1
			THEN s.ExtendedAmt
			END) [sales_AmtSoldClearance_FrontlineNew],
	--Markdown totals by class
	SUM(CASE
			WHEN s.ProductClass = 'Used'
			AND s.isMarkDown = 1
			THEN s.Quantity
			END) [sales_QtySoldMarkdown_Used],
	SUM(CASE
			WHEN s.ProductClass IN ('New', 'Frontline')
			AND s.isMarkDown = 1
			THEN s.Quantity
			END) [sales_QtySoldMarkdown_FrontlineNew],
	SUM(CASE
			WHEN s.ProductClass = 'Used'
			AND s.isMarkDown = 1
			THEN s.ExtendedAmt
			END) [sales_AmtSoldMarkdown_Used],
	SUM(CASE
			WHEN s.ProductClass IN ('New', 'Frontline')
			AND s.isMarkDown = 1
			THEN s.ExtendedAmt
			END) [sales_AmtSoldMarkdown_FrontlineNew]
INTO #Sales_post
FROM #KeyTable kt
	INNER JOIN #Sales_pre s
		ON kt.LocationNo = s.LocationNo
		AND kt.Store_Date = DATEADD(DAY, DATEDIFF(DAY, 0, s.BusinessDate), 0)
GROUP BY kt.LocationNo, kt.Store_Date


--SipsProductInventory preprocessing table will still be needed for pricing info
DROP TABLE #Sales_pre


/*******************
Buys
*******************/

SELECT 
	slm.LocationNo,
	CAST(bhh.BuyXactionID AS BIGINT) [BuyXactionID], --Cast as INT to facilitate future join to updated buy tables
	bhh.EndDate [BusinessDate],
	bhh.TotalOffer,
	bhh.TotalQuantity,
	DATEDIFF(SECOND, bhh.StartDate, bhh.EndDate) [seconds_BuyWait],
	bhh.[Status] [BuyStatus]
INTO #Buys_pre
FROM rHPB_Historical.dbo.BuyHeaderHistory bhh
	INNER JOIN ReportsData.dbo.StoreLocationMaster slm
		ON bhh.LocationID = slm.LocationId
WHERE bhh.EndDate >= @StartDate
	AND bhh.EndDate <= @EndDate
	AND bhh.TotalQuantity < 10000
	AND bhh.TotalOffer < 100000
	AND bhh.[Status] = 'A'

SELECT 
	kt.LocationNo,
	kt.Store_Date,
	COUNT(b.BuyXactionID) [buys_CountTransactions],
	SUM(b.TotalQuantity) [buys_QtyPurchased],
	SUM(b.TotalOffer) [buys_AmtPurchased],
	SUM(b.seconds_BuyWait) [buys_BuyWaitSeconds]
INTO #Buys_post
FROM #KeyTable kt
	INNER JOIN #Buys_pre b
		ON kt.LocationNo = b.LocationNo
		AND kt.Store_Date = DATEADD(DAY, DATEDIFF(DAY, 0, b.BusinessDate), 0)
GROUP BY kt.LocationNo, kt.Store_Date

DROP TABLE #Buys_pre

--iStore sales

SELECT 
	DATEADD(DAY, DATEDIFF(DAY, 0, ISNULL(om.RefundDate, om.ShipDate)), 0) [Store_Date],
	kt.LocationNo,
	COUNT(om.ISIS_OrderID) [count_iStoreOrders], --count of iStore orders
	SUM(om.Price) [total_iStoreSales], --sum of iStore sales
	SUM(om.RefundAmount) [total_iStoreRefunds],
	SUM(om.ShippingFee) [total_iStoreShipping],
	SUM(om.ShippedQuantity) [total_iStoreQty] --sum of iStore quantity sold (multiple items per order occurs)
INTO #iStore_post
FROM ISIS..Order_Monsoon om
	LEFT OUTER JOIN ISIS..App_Facilities fac
		ON om.FacilityID = fac.FacilityID
	LEFT OUTER JOIN OFS..Order_Header oh
		ON om.ISIS_OrderID = oh.ISISOrderID
		AND oh.OrderSystem = 'MON' --Excludes SAS and XFR, which are included in register sales
	LEFT OUTER JOIN OFS..Order_Detail od --Purpose of order detail is only to get fulfilling location 
		ON oh.OrderID = od.OrderID
		 --Problem orders have ProblemStatusID not null
		AND od.[Status] IN (1, 4) --Status codes of shipped orders
		AND (od.ProblemStatusID IS NULL
		OR od.ProblemStatusID = 0)
	INNER JOIN #KeyTable kt
		ON ISNULL(od.LocationNo, fac.HPBLocationNo) = kt.LocationNo --This logic takes the store which was originally assigned a problem order when the fulfilling location can not be determined
		AND DATEADD(DAY, DATEDIFF(DAY, 0, ISNULL(om.RefundDate, om.ShipDate)), 0) = kt.Store_Date
WHERE 
	ISNULL(od.LocationNo, fac.HPBLocationNo) IS NOT NULL
	AND om.ShippedQuantity > 0
GROUP BY DATEADD(DAY, DATEDIFF(DAY, 0, ISNULL(om.RefundDate, om.ShipDate)), 0),  kt.LocationNo

--HPB.com sales

SELECT 
	CASE 
		WHEN oo.ItemRefundAmount > 0
		THEN DATEADD(DAY, DATEDIFF(DAY, 0, oo.LastUpdate), 0)
	    ELSE DATEADD(DAY, DATEDIFF(DAY, 0, oh.ShipDate), 0) 
		END [Store_Date],
	kt.LocationNo,
	COUNT(od.OrderID) [count_HPBComOrders],
	SUM(od.Price) [total_HPBComSales],
	SUM(oo.ItemRefundAmount) [total_HPBComRefunds],
	SUM(od.ShippingFee) [total_HPBComShipping],
	SUM(od.Qty) [total_HPBComQty]
INTO #HPBCom_post
FROM OFS..Order_Header oh
	INNER JOIN OFS..Order_Detail od
		ON oh.OrderID = od.OrderID
	LEFT OUTER JOIN ISIS..Order_OMNI oo
		ON CAST(od.MarketOrderItemID AS VARCHAR) = CAST(oo.MarketOrderItemID AS VARCHAR)
	INNER JOIN #KeyTable kt
		ON od.LocationNo = kt.LocationNo
		AND (
			CASE 
			WHEN oo.ItemRefundAmount > 0
			THEN DATEADD(DAY, DATEDIFF(DAY, 0, oo.LastUpdate), 0)
			ELSE DATEADD(DAY, DATEDIFF(DAY, 0, oh.ShipDate), 0) 
			END ) = kt.Store_Date
 WHERE oh.OrderSystem = 'HMP'
  	AND od.[Status] IN (1, 4) --Status codes of shipped orders
	AND (od.ProblemStatusID IS NULL
	OR od.ProblemStatusID = 0)
GROUP BY 
	CASE 
		WHEN oo.ItemRefundAmount > 0
		THEN DATEADD(DAY, DATEDIFF(DAY, 0, oo.LastUpdate), 0)
	    ELSE DATEADD(DAY, DATEDIFF(DAY, 0, oh.ShipDate), 0) 
		END,
	kt.LocationNo

--BookSmarter sales
--Union of both current and archive tables is necessary prior to aggregations because dates overlap between the two tables

SELECT
	od.OrderItemID,
	od.ShipDate [ShipDate],
	CAST(('00' + od.LocationNo) AS CHAR(5)) [LocationNo],
	od.OrderNumber,
	od.Price,
	od.ShippingFee,
	od.ShippedQuantity
INTO #BookSmarterAllSales
FROM Monsoon..OrderDetails od
	INNER JOIN #KeyTable kt
		ON CAST(('00' + od.LocationNo) AS CHAR(5)) = kt.LocationNo
		AND DATEADD(DAY, DATEDIFF(DAY, 0, od.ShipDate), 0) = kt.Store_Date
		  --OrderDetails stores locations in CHAR(3) format, necessitating conversion to CHAR(5) for locations table
WHERE 
		od.[ServerID] IN (4, 5) --Dallas and Ohio BookSmarter servers
UNION
SELECT
	od.OrderItemID,
	od.ShipDate [ShipDate],
	CAST(('00' + od.LocationNo) AS CHAR(5)) [LocationNo],
	od.OrderNumber,
	od.Price,
	od.ShippingFee,
	od.ShippedQuantity
FROM Monsoon..OrderDetailsArchive od
	INNER JOIN #KeyTable kt
		ON CAST(('00' + od.LocationNo) AS CHAR(5)) = kt.LocationNo
		AND DATEADD(DAY, DATEDIFF(DAY, 0, od.ShipDate), 0) = kt.Store_Date
WHERE 
		od.[ServerID] IN (4, 5) --Dallas and Ohio BookSmarter servers


SELECT 
      DATEADD(DAY, DATEDIFF(DAY, 0, r.refundDate), 0) [Store_Date],
      CAST(('00' + od.LocationNo) AS CHAR(5)) [LocationNo],
      SUM(od.RefundAmount) [RefundAmount]
INTO #BookSmarterRefunds
FROM Monsoon..Refunds r
       INNER JOIN Monsoon..OrderDetails od
              ON r.MarketOrderItemID = od.MarketOrderItemID
		INNER JOIN #KeyTable kt
			ON CAST(('00' + od.LocationNo) AS CHAR(5)) = kt.LocationNo
			AND DATEADD(DAY, DATEDIFF(DAY, 0, r.refundDate), 0) = kt.Store_Date
WHERE 
       od.ServerID IN (4, 5)
GROUP BY DATEADD(DAY, DATEDIFF(DAY, 0, r.refundDate), 0), CAST(('00' + od.LocationNo) AS CHAR(5))


SELECT 
	DATEADD(DAY, DATEDIFF(DAY, 0, bas.ShipDate), 0) [Store_Date],
	bas.LocationNo,
	COUNT(DISTINCT bas.OrderNumber) [count_BSOrders],  --Count of all BookSmarter Orders
	SUM(bas.Price) [total_BSSales], --Sum of all BookSmarter sales 
	bsr.RefundAmount [total_BSRefunds], --Sum of all BookSmarter refunds
	SUM(bas.ShippingFee) [total_BSShipping],
	SUM(bas.ShippedQuantity) [total_BSQty] --Sum of BookSmarter quantitity sold (multiple items per order occurs).
INTO #BookSmarter_post
FROM #BookSmarterAllSales bas
	LEFT OUTER JOIN #BookSmarterRefunds bsr
             ON bas.LocationNo = bsr.LocationNo
			 AND DATEADD(DAY, DATEDIFF(DAY, 0, bas.ShipDate), 0) = bsr.Store_Date
GROUP BY DATEADD(DAY, DATEDIFF(DAY, 0, bas.ShipDate), 0), bas.LocationNo, bsr.RefundAmount


DROP TABLE #BookSmarterAllSales
DROP TABLE #BookSmarterRefunds




SELECT 
	kt.DistrictName,
	kt.LocationNo,
	kt.Store_Date,
	kt.NRF_Year,
	kt.NRF_Week_Restated,
	kt.NRF_Day,
	ISNULL(s.sales_CountTransactions, 0) [sales_CountTransactions],
	ISNULL(s.sales_AmtSold, 0) [sales_AmtSold],
	ISNULL(s.sales_AmtSold_Frontline, 0) [sales_AmtSold_Frontline],
	ISNULL(s.sales_AmtSold_New, 0) [sales_AmtSold_New],
	ISNULL(s.sales_AmtSold_Used, 0) [sales_AmtSold_Use],
	ISNULL(s.sales_QtySold, 0) [sales_QtySold],
	ISNULL(s.sales_QtySold_Frontline, 0) [sales_QtySold_Frontline],
	ISNULL(s.sales_QtySold_New, 0) [sales_QtySold_New],
	ISNULL(s.sales_QtySold_Used, 0) [sales_QtySold_Used],
	ISNULL(b.buys_CountTransactions, 0) [buys_CountTransactions],
	ISNULL(b.buys_AmtPurchased, 0) [buys_AmtPurchased],
	ISNULL(b.buys_QtyPurchased, 0) [buys_QtyPurchased],
	ISNULL(b.buys_BuyWaitSeconds, 0) [buys_BuyWaitSeconds],
	ISNULL(i.count_iStoreOrders, 0) [iStore_CountTransactions],
	ISNULL(i.total_iStoreSales, 0) + ISNULL(i.total_iStoreShipping, 0) - ISNULL(i.total_iStoreRefunds, 0) [iStore_AmtSold],
	ISNULL(i.total_iStoreQty, 0) [iStore_QtySold],
	ISNULL(h.count_HPBComOrders, 0) [HPBCom_CountTransactions],
	ISNULL(h.total_HPBComSales, 0) + ISNULL(h.total_HPBComShipping, 0) - ISNULL(h.total_HPBComRefunds, 0) [HPBCom_AmtSold],
	ISNULL(h.total_HPBComQty, 0) [HPBCom_QtySold],
	ISNULL(bs.count_BSOrders, 0) [BookSmarter_CountTransactions],
	ISNULL(bs.total_BSSales, 0) + ISNULL(bs.total_BSShipping, 0) - ISNULL(bs.total_BSRefunds, 0) [BookSmarter_AmtSold],
	ISNULL(bs.total_BSQty, 0) [BookSmarter_QtySold],
	1 [count_Locations]
	--AVG(s.sales_CountTransactions) OVER (PARTITION BY kt.LocationNo, NRF_Year ORDER BY kt.NRF_Day) [rollavg_sales_CountTransactions],
	--AVG(s.sales_AmtSold) OVER (PARTITION BY kt.LocationNo, NRF_Year ORDER BY kt.NRF_Day) [rollavg_sales_AmtSold],
	--AVG(s.sales_AmtSold_Frontline) OVER (PARTITION BY kt.LocationNo, NRF_Year ORDER BY kt.NRF_Day) [rollavg_sales_AmtSold_Frontline],
	--AVG(s.sales_AmtSold_New) OVER (PARTITION BY kt.LocationNo, NRF_Year ORDER BY kt.NRF_Day) [rollavg_sales_AmtSold_New],
	--AVG(s.sales_AmtSold_Used) OVER (PARTITION BY kt.LocationNo, NRF_Year ORDER BY kt.NRF_Day) [rollavg_sales_AmtSold_Used],
	--AVG(s.sales_QtySold) OVER (PARTITION BY kt.LocationNo, NRF_Year ORDER BY kt.NRF_Day) [rollavg_sales_QtySold],
	--AVG(s.sales_QtySold_Frontline) OVER (PARTITION BY kt.LocationNo, NRF_Year ORDER BY kt.NRF_Day) [rollavg_sales_QtySold_Frontline],
	--AVG(s.sales_QtySold_New) OVER (PARTITION BY kt.LocationNo, NRF_Year ORDER BY kt.NRF_Day) [rollavg_sales_QtySold_New],
	--AVG(s.sales_QtySold_Used) OVER (PARTITION BY kt.LocationNo, NRF_Year ORDER BY kt.NRF_Day) [rollavg_sales_QtySold_Used],
	--AVG(b.buys_CountTransactions) OVER (PARTITION BY kt.LocationNo, NRF_Year ORDER BY kt.NRF_Day) [rollavg_buys_CountTransactions],
	--AVG(b.buys_AmtPurchased) OVER (PARTITION BY kt.LocationNo, NRF_Year ORDER BY kt.NRF_Day) [rollavg_buys_AmtPurchased],
	--AVG(b.buys_QtyPurchased) OVER (PARTITION BY kt.LocationNo, NRF_Year ORDER BY kt.NRF_Day) [rollavg_buys_QtyPurchased],
	--AVG(b.buys_BuyWaitSeconds) OVER (PARTITION BY kt.LocationNo, NRF_Year ORDER BY kt.NRF_Day) [rollavg_buys_BuyWaitSeconds]
FROM #KeyTable kt
	FULL OUTER JOIN #Sales_post s
		ON kt.LocationNo = s.LocationNo
		AND kt.Store_Date = s.Store_Date
	FULL OUTER JOIN #Buys_post b
		ON kt.LocationNo = b.LocationNo
		AND kt.Store_Date = b.Store_Date
	FULL OUTER JOIN #iStore_post i
		ON kt.LocationNo = i.LocationNo
		AND kt.Store_Date = i.Store_Date
	FULL OUTER JOIN #HPBCom_post h
		ON kt.LocationNo = h.LocationNo
		AND kt.Store_Date = h.Store_Date
	FULL OUTER JOIN #BookSmarter_post bs
		ON kt.LocationNo = bs.LocationNo
		AND kt.Store_Date = bs.Store_Date
UNION ALL
SELECT 
	'Chain' [DistrictName],
	'Chain' [LocationNo],
	kt.Store_Date,
	kt.NRF_Year,
	kt.NRF_Week_Restated,
	kt.NRF_Day,
	SUM(ISNULL(s.sales_CountTransactions, 0)) [sales_CountTransactions],
	SUM(ISNULL(s.sales_AmtSold, 0)) [sales_AmtSold],
	SUM(ISNULL(s.sales_AmtSold_Frontline, 0)) [sales_AmtSold_Frontline],
	SUM(ISNULL(s.sales_AmtSold_New, 0)) [sales_AmtSold_New],
	SUM(ISNULL(s.sales_AmtSold_Used, 0)) [sales_AmtSold_Use],
	SUM(ISNULL(s.sales_QtySold, 0)) [sales_QtySold],
	SUM(ISNULL(s.sales_QtySold_Frontline, 0)) [sales_QtySold_Frontlin],
	SUM(ISNULL(s.sales_QtySold_New, 0)) [sales_QtySold_New],
	SUM(ISNULL(s.sales_QtySold_Used, 0)) [sales_QtySold_Used],
	SUM(ISNULL(b.buys_CountTransactions, 0)) [buys_CountTransactions],
	SUM(ISNULL(b.buys_AmtPurchased, 0)) [buys_AmtPurchased],
	SUM(ISNULL(b.buys_QtyPurchased, 0)) [buys_QtyPurchased],
	SUM(ISNULL(b.buys_BuyWaitSeconds, 0)) [buys_BuyWaitSeconds],
	SUM(ISNULL(i.count_iStoreOrders, 0)) [iStore_CountTransactions],
	SUM(ISNULL(i.total_iStoreSales, 0) + ISNULL(i.total_iStoreShipping, 0) - ISNULL(i.total_iStoreRefunds, 0)) [iStore_AmtSold],
	SUM(ISNULL(i.total_iStoreQty, 0)) [iStore_QtySold],
	SUM(ISNULL(h.count_HPBComOrders, 0)) [HPBCom_CountTransactions],
	SUM(ISNULL(h.total_HPBComSales, 0) + ISNULL(h.total_HPBComShipping, 0) - ISNULL(h.total_HPBComRefunds, 0)) [HPBCom_AmtSold],
	SUM(ISNULL(h.total_HPBComQty, 0)) [HPBCom_QtySold],
	SUM(ISNULL(bs.count_BSOrders, 0)) [BookSmarter_CountTransactions],
	SUM(ISNULL(bs.total_BSSales, 0) + ISNULL(bs.total_BSShipping, 0) - ISNULL(bs.total_BSRefunds, 0)) [BookSmarter_AmtSold],
	SUM(ISNULL(bs.total_BSQty, 0)) [BookSmarter_QtySold],
	COUNT(DISTINCT kt.LocationNo) [count_Locations]
	--AVG(AVG(s.sales_CountTransactions)) OVER (PARTITION BY NRF_Year ORDER BY kt.NRF_Day) [rollavg_sales_CountTransactions],
	--AVG(AVG(s.sales_AmtSold)) OVER (PARTITION BY NRF_Year ORDER BY kt.NRF_Day) [rollavg_sales_AmtSold],
	--AVG(AVG(s.sales_AmtSold_Frontline)) OVER (PARTITION BY NRF_Year ORDER BY kt.NRF_Day) [rollavg_sales_AmtSold_Frontline],
	--AVG(AVG(s.sales_AmtSold_New)) OVER (PARTITION BY NRF_Year ORDER BY kt.NRF_Day) [rollavg_sales_AmtSold_New],
	--AVG(AVG(s.sales_AmtSold_Used)) OVER (PARTITION BY NRF_Year ORDER BY kt.NRF_Day) [rollavg_sales_AmtSold_Used],
	--AVG(AVG(s.sales_QtySold)) OVER (PARTITION BY NRF_Year ORDER BY kt.NRF_Day) [rollavg_sales_QtySold],
	--AVG(AVG(s.sales_QtySold_Frontline)) OVER(PARTITION BY NRF_Year ORDER BY kt.NRF_Day) [rollavg_sales_QtySold_Frontline],
	--AVG(AVG(s.sales_QtySold_New)) OVER (PARTITION BY  NRF_Year ORDER BY kt.NRF_Day) [rollavg_sales_QtySold_New],
	--AVG(AVG(s.sales_QtySold_Used)) OVER (PARTITION BY NRF_Year ORDER BY kt.NRF_Day) [rollavg_sales_QtySold_Used],
	--AVG(AVG(b.buys_CountTransactions)) OVER (PARTITION BY NRF_Year ORDER BY kt.NRF_Day) [rollavg_buys_CountTransactions],
	--AVG(AVG(b.buys_AmtPurchased)) OVER (PARTITION BY NRF_Year ORDER BY kt.NRF_Day) [rollavg_buys_AmtPurchased],
	--AVG(AVG(b.buys_QtyPurchased)) OVER (PARTITION BY NRF_Year ORDER BY kt.NRF_Day) [rollavg_buys_QtyPurchased],
	--AVG(AVG(b.buys_BuyWaitSeconds)) OVER (PARTITION BY NRF_Year ORDER BY kt.NRF_Day) [rollavg_buys_BuyWaitSeconds]
FROM #KeyTable kt
	FULL OUTER JOIN #Sales_post s
		ON kt.LocationNo = s.LocationNo
		AND kt.Store_Date = s.Store_Date
	FULL OUTER JOIN #Buys_post b
		ON kt.LocationNo = b.LocationNo
		AND kt.Store_Date = b.Store_Date
	FULL OUTER JOIN #iStore_post i
		ON kt.LocationNo = i.LocationNo
		AND kt.Store_Date = i.Store_Date
	FULL OUTER JOIN #HPBCom_post h
		ON kt.LocationNo = h.LocationNo
		AND kt.Store_Date = h.Store_Date
	FULL OUTER JOIN #BookSmarter_post bs
		ON kt.LocationNo = bs.LocationNo
		AND kt.Store_Date = bs.Store_Date
--WHERE kt.bool_CompStore = 1
GROUP BY 
	kt.Store_Date,
	kt.NRF_Year,
	kt.NRF_Week_Restated,
	kt.NRF_Day
ORDER BY kt.LocationNo, kt.Store_Date

DROP TABLE #KeyTable
DROP TABLE #SipsProductInventory
DROP TABLE #Sales_post
DROP TABLE #Buys_post
DROP TABLE #iStore_post
DROP TABLE #HPBCom_post
DROP TABLE #BookSmarter_post
