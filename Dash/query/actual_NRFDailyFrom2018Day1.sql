DECLARE @NRF_StartWeek INT = 1
DECLARE @NRF_StartYear CHAR(4) = '2018'
DECLARE @StartDate DATE
DECLARE @EndDate DATE = GETDATE()

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
	ROW_NUMBER() OVER (PARTITION BY nd.NRF_Year, LocationNo ORDER BY nd.Store_Date) [NRF_Day]
INTO #KeyTable
FROM MathLab..NRF_Daily nd
	CROSS JOIN ReportsData..StoreLocationMaster slm
WHERE nd.Store_Date >= @StartDate
	AND nd.Store_Date <= @EndDate
	AND slm.StoreType = 'S'
	AND slm.OpenDate <= @StartDate
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
	AND shh.EndDate <= @EndDate
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
	AND shh.EndDate <= @EndDate
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
	AND shh.EndDate <= @EndDate

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
	AND s.BusinessDate >= @StartDate
	AND s.BusinessDate <= @EndDate

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

SELECT 
	kt.DistrictName,
	kt.LocationNo,
	kt.Store_Date,
	kt.NRF_Year,
	kt.NRF_Week_Restated,
	kt.NRF_Day,
	s.sales_CountTransactions,
	s.sales_AmtSold,
	s.sales_AmtSold_Frontline,
	s.sales_AmtSold_New,
	s.sales_AmtSold_Used,
	s.sales_QtySold,
	s.sales_QtySold_Frontline,
	s.sales_QtySold_New,
	s.sales_QtySold_Used,
	b.buys_CountTransactions,
	b.buys_AmtPurchased,
	b.buys_QtyPurchased,
	b.buys_BuyWaitSeconds
FROM #KeyTable kt
	FULL OUTER JOIN #Sales_post s
		ON kt.LocationNo = s.LocationNo
		AND kt.Store_Date = s.Store_Date
	FULL OUTER JOIN #Buys_post b
		ON kt.LocationNo = b.LocationNo
		AND kt.Store_Date = b.Store_Date
		
DROP TABLE #KeyTable
DROP TABLE #SipsProductInventory
DROP TABLE #Sales_post
DROP TABLE #Buys_post
