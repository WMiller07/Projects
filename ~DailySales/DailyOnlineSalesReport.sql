
DECLARE @Start_NRFWeek INT = 1
DECLARE @Start_NRFYear INT = 2018

DECLARE @StartDate DATE
DECLARE @EndDate DATE =  DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)

SELECT
	@StartDate = MIN(nd.Store_Date)
FROM MathLab..NRF_Daily nd
WHERE nd.NRF_Week_Restated = @Start_NRFWeek
AND nd.NRF_Year = @Start_NRFYear

CREATE TABLE #ListingInstances (ListingInstanceID smallint, InstanceName varchar(50), InstanceType varchar(20))

INSERT INTO #ListingInstances
SELECT
	li.ListingInstanceID,
	li.InstanceName,
	CASE 
		WHEN li.ListingTypeID = 1 THEN 'iStore'
		WHEN li.ListingTypeID = 3 THEN 'HPB.com'
		END [InstanceType] 
FROM ISIS.dbo.App_ListingInstances li
WHERE li.Status = 'A'
AND li.ListingTypeID IN (1, 3)

INSERT INTO #ListingInstances
SELECT 
	MAX(li.ListingInstanceID) + 1 [ListingInstanceId],
	'BookSmarter' [InstanceName],
	'BookSmarter' [InstanceType]
FROM #ListingInstances li


SELECT 
	nrf.Store_Date,
	nrf.NRF_Year,
	nrf.NRF_MonthNum,
	nrf.NRF_Week,
	nrf.NRF_Week_Restated,
	nrf.NRF_Day,
	li.InstanceType,
	li.InstanceName,
	li.ListingInstanceID
INTO #KeyTable
FROM MathLab.dbo.NRF_Daily nrf
	CROSS JOIN #ListingInstances li
WHERE 
		nrf.NRF_Year >= @Start_NRFYear
	AND nrf.Store_Date < @EndDate

DROP TABLE #ListingInstances

--iStore sales

SELECT 
	DATEADD(DAY, DATEDIFF(DAY, 0, ISNULL(om.RefundDate, om.ShipDate)), 0) [Store_Date],
	kt.InstanceName,
	COUNT(om.ISIS_OrderID) [count_iStoreOrders], --count of iStore orders
	SUM(om.Price) [total_iStoreSales], --sum of iStore sales
	SUM(om.RefundAmount)[total_iStoreRefunds],
	SUM(om.ShippingFee) [total_iStoreShipping],
	SUM(om.ShippedQuantity) [total_iStoreQty], --sum of iStore quantity sold (multiple items per order occurs
	SUM(CASE
			WHEN om.Price <= om.AmazonLowestPrice
			THEN om.ShippedQuantity
			END) [total_iStoreQty_PriceFloorAndUnder],
	SUM(CASE
			WHEN om.Price = om.AmazonLowestPrice
			THEN om.ShippedQuantity
			END) [total_iStoreQty_AtPriceFloor],
	SUM(CASE
			WHEN om.AmazonSalesRank < 10000
			THEN om.ISIS_OrderID
			END) [total_iStoreQty_ASRUnder10k]
INTO #iStore_post
FROM ISIS..Order_Monsoon om
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
		ON om.ListingInstanceID = kt.ListingInstanceID --This logic takes the store which was originally assigned a problem order when the fulfilling location can not be determined
		AND DATEADD(DAY, DATEDIFF(DAY, 0, ISNULL(om.RefundDate, om.ShipDate)), 0) = kt.Store_Date
WHERE 
	 om.ShippedQuantity > 0
GROUP BY DATEADD(DAY, DATEDIFF(DAY, 0, ISNULL(om.RefundDate, om.ShipDate)), 0),  kt.InstanceName

--HPB.com sales

SELECT 
	CASE 
		WHEN oo.ItemRefundAmount > 0
		THEN DATEADD(DAY, DATEDIFF(DAY, 0, oo.LastUpdate), 0)
		ELSE DATEADD(DAY, DATEDIFF(DAY, 0, oh.ShipDate), 0) 
		END [Store_Date],
	kt.InstanceName,
	COUNT(od.OrderID) [count_HPBComOrders],
	SUM(od.Price)[total_HPBComSales],
	SUM(oo.ItemRefundAmount) [total_HPBComRefunds],
	SUM(od.ShippingFee) [total_HPBComShipping],
	SUM(od.Qty)[total_HPBComQty]
INTO #HPBCom_post
FROM OFS..Order_Header oh
	INNER JOIN OFS..Order_Detail od
		ON oh.OrderID = od.OrderID
	LEFT OUTER JOIN ISIS..Order_OMNI oo
		ON CAST(od.MarketOrderItemID AS VARCHAR) = CAST(oo.MarketOrderItemID AS VARCHAR)
	INNER JOIN #KeyTable kt
		ON od.ListingInstanceID = kt.ListingInstanceID
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
	kt.InstanceName

--BookSmarter sales
--Union of both current and archive tables is necessary prior to aggregations because dates overlap between the two tables

SELECT
	od.OrderItemID,
	od.ShipDate [ShipDate],
	kt.InstanceName,
	od.OrderNumber,
	od.Price,
	od.ShippingFee,
	od.ShippedQuantity
INTO #BookSmarterSales
FROM Monsoon..OrderDetails od
	INNER JOIN #KeyTable kt
		ON 'BookSmarter' = kt.InstanceName
		AND DATEADD(DAY, DATEDIFF(DAY, 0, od.ShipDate), 0) = kt.Store_Date
			--OrderDetails stores locations in CHAR(3) format, necessitating conversion to CHAR(5) for locations table
WHERE 
		od.[ServerID] IN (4, 5) --Dallas and Ohio BookSmarter servers
UNION
SELECT
	od.OrderItemID,
	od.ShipDate [ShipDate],
	kt.InstanceName,
	od.OrderNumber,
	od.Price,
	od.ShippingFee,
	od.ShippedQuantity
FROM Monsoon..OrderDetailsArchive od
	INNER JOIN #KeyTable kt
		ON 'BookSmarter' = kt.InstanceName
		AND DATEADD(DAY, DATEDIFF(DAY, 0, od.ShipDate), 0) = kt.Store_Date
WHERE 
		od.[ServerID] IN (4, 5) --Dallas and Ohio BookSmarter servers


SELECT 
		DATEADD(DAY, DATEDIFF(DAY, 0, r.refundDate), 0) [Store_Date],
		kt.InstanceName,
		SUM(od.RefundAmount) [RefundAmount]
INTO #BookSmarterRefunds
FROM Monsoon..Refunds r
		INNER JOIN Monsoon..OrderDetails od
				ON r.MarketOrderItemID = od.MarketOrderItemID
		INNER JOIN #KeyTable kt
			ON 'BookSmarter' = kt.InstanceName
			AND DATEADD(DAY, DATEDIFF(DAY, 0, r.refundDate), 0) = kt.Store_Date
WHERE 
		od.ServerID IN (4, 5)
GROUP BY DATEADD(DAY, DATEDIFF(DAY, 0, r.refundDate), 0), kt.InstanceName


SELECT 
	DATEADD(DAY, DATEDIFF(DAY, 0, bas.ShipDate), 0) [Store_Date],
	bas.InstanceName,
	COUNT(DISTINCT bas.OrderNumber) [count_BSOrders],  --Count of all BookSmarter Orders
	SUM(bas.Price) [total_BSSales], --Sum of all BookSmarter sales 
	bsr.RefundAmount [total_BSRefunds], --Sum of all BookSmarter refunds
	SUM(bas.ShippingFee) [total_BSShipping],
	SUM(bas.ShippedQuantity) [total_BSQty] --Sum of BookSmarter quantitity sold (multiple items per order occurs).
INTO #BookSmarter_post
FROM #BookSmarterSales bas
	LEFT OUTER JOIN #BookSmarterRefunds bsr
				ON bas.InstanceName = bsr.InstanceName
				AND DATEADD(DAY, DATEDIFF(DAY, 0, bas.ShipDate), 0) = bsr.Store_Date
GROUP BY DATEADD(DAY, DATEDIFF(DAY, 0, bas.ShipDate), 0), bas.InstanceName, bsr.RefundAmount


DROP TABLE #BookSmarterSales
DROP TABLE #BookSmarterRefunds



--DELETE Sandbox.dbo.RDA_RU_OnlineDailyMetrics
--FROM Sandbox.dbo.RDA_RU_OnlineDailyMetrics odm
--	INNER JOIN #KeyTable kt
--		ON odm.InstanceName = kt.InstanceName
--		AND odm.Store_Date = kt.Store_Date

--TRUNCATE TABLE Sandbox.dbo.RDA_RU_OnlineDailyMetrics
--INSERT INTO Sandbox.dbo.RDA_RU_OnlineDailyMetrics
SELECT 
	kt.InstanceType,
	kt.InstanceName,
	kt.Store_Date,
	kt.NRF_Year,
	kt.NRF_MonthNum,
	kt.NRF_Week_Restated,
	kt.NRF_Day,
	ISNULL(i.count_iStoreOrders, 0) + ISNULL(h.count_HPBComOrders, 0) + ISNULL(bs.count_BSOrders, 0) [CountTransactions],
	ISNULL(i.total_iStoreSales, 0) + ISNULL(i.total_iStoreShipping, 0) - ISNULL(i.total_iStoreRefunds, 0) +
		ISNULL(h.total_HPBComSales, 0) + ISNULL(h.total_HPBComShipping, 0) - ISNULL(h.total_HPBComRefunds, 0) + 
		ISNULL(bs.total_BSSales, 0) + ISNULL(bs.total_BSShipping, 0) - ISNULL(bs.total_BSRefunds, 0) [AmtSold],
	ISNULL(i.total_iStoreQty, 0) + ISNULL(h.total_HPBComQty, 0) + ISNULL(bs.total_BSQty, 0) [QtySold]
FROM #KeyTable kt
	FULL OUTER JOIN #iStore_post i
		ON kt.InstanceName= i.InstanceName
		AND kt.Store_Date = i.Store_Date
	FULL OUTER JOIN #HPBCom_post h
		ON kt.InstanceName = h.InstanceName
		AND kt.Store_Date = h.Store_Date
	FULL OUTER JOIN #BookSmarter_post bs
		ON kt.InstanceName = bs.InstanceName
		AND kt.Store_Date = bs.Store_Date
UNION ALL
SELECT 
	'TotalOnline' [InstanceType],
	'TotalOnline' [InstanceName],
	kt.Store_Date,
	kt.NRF_Year,
	kt.NRF_MonthNum,
	kt.NRF_Week_Restated,
	kt.NRF_Day,
	SUM(ISNULL(i.count_iStoreOrders, 0)) + SUM(ISNULL(h.count_HPBComOrders, 0)) + SUM(ISNULL(bs.count_BSOrders, 0)) [CountTransactions],
	SUM(ISNULL(i.total_iStoreSales, 0) + ISNULL(i.total_iStoreShipping, 0) - ISNULL(i.total_iStoreRefunds, 0)) +
		SUM(ISNULL(h.total_HPBComSales, 0) + ISNULL(h.total_HPBComShipping, 0) - ISNULL(h.total_HPBComRefunds, 0)) + 
		SUM(ISNULL(bs.total_BSSales, 0) + ISNULL(bs.total_BSShipping, 0) - ISNULL(bs.total_BSRefunds, 0)) [AmtSold],
	SUM(ISNULL(i.total_iStoreQty, 0)) + SUM(ISNULL(h.total_HPBComQty, 0)) + SUM(ISNULL(bs.total_BSQty, 0)) [QtySold]
FROM #KeyTable kt
	FULL OUTER JOIN #iStore_post i
		ON kt.InstanceName= i.InstanceName
		AND kt.Store_Date = i.Store_Date
	FULL OUTER JOIN #HPBCom_post h
		ON kt.InstanceName = h.InstanceName
		AND kt.Store_Date = h.Store_Date
	FULL OUTER JOIN #BookSmarter_post bs
		ON kt.InstanceName = bs.InstanceName
		AND kt.Store_Date = bs.Store_Date
GROUP BY 
	kt.Store_Date,
	kt.NRF_Year,
	kt.NRF_MonthNum,
	kt.NRF_Week_Restated,
	kt.NRF_Day
ORDER BY kt.InstanceName, kt.Store_Date

DROP TABLE #KeyTable

DROP TABLE #iStore_post
DROP TABLE #HPBCom_post
DROP TABLE #BookSmarter_post
