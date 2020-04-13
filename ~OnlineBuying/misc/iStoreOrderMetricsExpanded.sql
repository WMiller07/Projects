DECLARE @Start_NRFWeek INT = 1
DECLARE @Start_NRFYear INT = 2018

DECLARE @StartDate DATE
DECLARE @EndDate DATE =  DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)

SELECT
	@StartDate = MIN(nd.Store_Date)
FROM MathLab..NRF_Daily nd
WHERE nd.NRF_Week_Restated = @Start_NRFWeek
AND nd.NRF_Year = @Start_NRFYear

CREATE TABLE #ListingInstances (ListingInstanceID smallint, InstanceName varchar(50))

INSERT INTO #ListingInstances
SELECT
	li.ListingInstanceID,
	li.InstanceName
FROM ISIS.dbo.App_ListingInstances li
WHERE li.Status = 'A'
AND li.ListingTypeID = 1


SELECT 
	nrf.Store_Date,
	nrf.NRF_Year,
	nrf.NRF_MonthNum,
	nrf.NRF_Week,
	nrf.NRF_Week_Restated,
	nrf.NRF_Day,
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
	--SUM(CASE
	--		WHEN CAST(om.AmazonSalesRank AS BIGINT) < 10000
	--		THEN om.ShippedQuantity
	--		END) [total_iStoreQty_ASRUnder10k],
	SUM(CASE
			WHEN CAST(om.AmazonSalesRank AS BIGINT) < 250000
			THEN om.ShippedQuantity
			END) [total_iStoreQty_ASRUnder250k],
	SUM(CASE
			WHEN CAST(om.AmazonSalesRank AS BIGINT) < 500000
			AND CAST(om.AmazonSalesRank AS BIGINT) >= 250000
			THEN om.ShippedQuantity
			END) [total_iStoreQty_ASRUnder500k],
	SUM(CASE
			WHEN CAST(om.AmazonSalesRank AS BIGINT) < 1000000
			AND om.AmazonSalesRank >= 500000
			THEN om.ShippedQuantity
			END) [total_iStoreQty_ASRUnder1m],
	SUM(CASE
			WHEN CAST(om.AmazonSalesRank AS BIGINT) < 2000000
			AND CAST(om.AmazonSalesRank AS BIGINT) >= 1000000
			THEN om.ShippedQuantity
			END) [total_iStoreQty_ASRUnder2m],
	SUM(CASE
			WHEN CAST(om.AmazonSalesRank AS BIGINT) >= 2000000
			THEN om.ShippedQuantity
			END) [total_iStoreQty_ASR2mAndOver],
	AVG(spi.Price) [avg_iStoreCOGS]
--INTO #iStore_post
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
	LEFT OUTER JOIN ReportsData.dbo.SipsProductInventory spi
		ON LEFT(od.MarketSKU, 2) = 'S_'
		AND CAST(od.ItemCode AS INT) = CAST(spi.ItemCode AS INT)
	INNER JOIN #KeyTable kt
		ON om.ListingInstanceID = kt.ListingInstanceID --This logic takes the store which was originally assigned a problem order when the fulfilling location can not be determined
		AND DATEADD(DAY, DATEDIFF(DAY, 0, ISNULL(om.RefundDate, om.ShipDate)), 0) = kt.Store_Date
WHERE 
	 om.ShippedQuantity > 0
GROUP BY DATEADD(DAY, DATEDIFF(DAY, 0, ISNULL(om.RefundDate, om.ShipDate)), 0),  kt.InstanceName
ORDER BY InstanceName, Store_Date

DROP TABLE #KeyTable