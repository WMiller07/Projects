SET NOCOUNT ON;
SET ANSI_WARNINGS OFF;


DECLARE @StartDate DATE = '1/1/2017'
DECLARE	@RollingAvg BIT = 0


SELECT 
	LocationNo,
	CASE 
		WHEN slm.OpenDate <= DATEADD(YEAR, -2, @StartDate) 
		AND slm.ClosedDate IS NULL
		AND slm.StoreType = 'S'
		THEN 1
		--ELSE 0
		END [bool_2YrCompLoc],
	CASE 
		WHEN slm.OpenDate <= DATEADD(YEAR, -5, @StartDate) 
			AND slm.ClosedDate IS NULL
		AND slm.StoreType = 'S'
		THEN 1
		--ELSE 0
		END [bool_5YrCompLoc],
	CASE 
		WHEN slm.OpenDate <= DATEADD(YEAR, -10, @StartDate) 
		AND slm.ClosedDate IS NULL
		AND slm.StoreType = 'S'
		THEN 1
		--ELSE 0
		END [bool_10YrCompLoc]
INTO #Locations
FROM ReportsData..StoreLocationMaster slm

SELECT 
	sm.LocationNo,
	nrf.NRF_Year,
    nrf.Store_StartOfWeek,
	nrf.NRF_Week,
	nrf.NRF_Week_Restated,
    sales_CountTransactions,
    sales_QtySold,
    sales_AmtSold,
    sales_QtySold_Used,
    sales_QtySold_New,
    sales_QtySold_Frontline,
    sales_AmtSold_Used,
    sales_AmtSold_New,
    sales_AmtSold_Frontline,
    sales_QtySoldClearance_Used,
    sales_QtySoldClearance_FrontlineNew,
    sales_AmtSoldClearance_Used,
    sales_AmtSoldClearance_FrontlineNew,
    sales_QtySoldMarkdown_Used,
    sales_QtySoldMarkdown_FrontlineNew,
    sales_AmtSoldMarkdown_Used,
    sales_AmtSoldMarkdown_FrontlineNew,
    buys_CountTransactions,
    buys_QtyPurchased,
    buys_AmtPurchased,
    buys_BuyWaitSeconds,
    pricing_QtyPriced,
    pricing_AvgPrice,
    pricing_AvgListPrice,
    pricing_QtyScannerClearance,
    pricing_QtyScannerMarkdown,
    transfers_QtyDisposed,
    transfers_QtyToBookSmarter,
    transfers_QtyToLocation,
	cl.bool_2YrCompLoc,
	cl.bool_5YrCompLoc,
	cl.bool_10YrCompLoc
INTO #Base
FROM [Sandbox].[dbo].[RDA_RU_StarMetrics] sm
	INNER JOIN MathLab..NRF_Weekly nrf
		ON sm.Store_StartOfWeek = nrf.Store_StartOfWeek
	LEFT OUTER JOIN #Locations cl
		ON sm.LocationNo = cl.LocationNo
WHERE nrf.Store_StartOfWeek >= DATEADD(YEAR, -1, @StartDate)




SELECT 
	CASE 
		WHEN b.bool_10YrCompLoc = 1
			THEN '10Yr'
		WHEN b.bool_5YrCompLoc = 1
			THEN '5Yr'
		WHEN b.bool_2YrCompLoc = 1
			THEN '2Yr' 
		END [LocationNo],
	b.NRF_Year,
	b.Store_StartOfWeek,
	b.NRF_Week,
	b.NRF_Week_Restated,
	AVG(b.sales_CountTransactions) [sales_CountTransactions],
    AVG(b.sales_QtySold) [sales_QtySold],
    AVG(b.sales_AmtSold) [sales_AmtSold],
    AVG(b.sales_QtySold_Used) [sales_QtySold_Used],
    AVG(b.sales_QtySold_New) [sales_QtySold_New],
    AVG(b.sales_QtySold_Frontline) [sales_QtySold_Frontline],
    AVG(b.sales_AmtSold_Used) [sales_AmtSold_Used],
    AVG(b.sales_AmtSold_New) [sales_AmtSold_New],
    AVG(b.sales_AmtSold_Frontline) [sales_AmtSold_Frontline],
    AVG(b.sales_QtySoldClearance_Used) [sales_QtySoldClearance_Used],
    AVG(b.sales_QtySoldClearance_FrontlineNew) [sales_QtySoldClearance_FrontlineNew],
    AVG(b.sales_AmtSoldClearance_Used) [sales_AmtSoldClearance_Used],
    AVG(b.sales_AmtSoldClearance_FrontlineNew) [sales_AmtSoldClearance_FrontlineNew],
    AVG(b.sales_QtySoldMarkdown_Used) [sales_QtySoldMarkdown_Used],
    AVG(b.sales_QtySoldMarkdown_FrontlineNew) [sales_QtySoldMarkdown_FrontlineNew],
    AVG(b.sales_AmtSoldMarkdown_Used) [sales_AmtSoldMarkdown_Used],
    AVG(b.sales_AmtSoldMarkdown_FrontlineNew) [sales_AmtSoldMarkdown_FrontlineNew],
    AVG(b.buys_CountTransactions) [buys_CountTransactions],
    AVG(b.buys_QtyPurchased) [buys_QtyPurchased],
    AVG(b.buys_AmtPurchased) [buys_AmtPurchased],
    AVG(b.buys_BuyWaitSeconds) [buys_BuyWaitSeconds],
    AVG(b.pricing_QtyPriced) [pricing_QtyPriced],
    AVG(b.pricing_AvgPrice) [pricing_AvgPrice],
    AVG(b.pricing_AvgListPrice) [pricing_AvgListPrice],
    AVG(b.pricing_QtyScannerClearance) [pricing_QtyScannerClearance],
    AVG(b.pricing_QtyScannerMarkdown) [pricing_QtyScannerMarkdown],
    AVG(b.transfers_QtyDisposed) [transfers_QtyDisposed],
    AVG(b.transfers_QtyToBookSmarter) [transfers_QtyToBookSmarter],
    AVG(b.transfers_QtyToLocation) [transfers_QtyToLocation]
INTO #BaseIdx
FROM #Base b
GROUP BY 
	b.NRF_Year,
	b.Store_StartOfWeek,
	b.NRF_Week,
	b.NRF_Week_Restated,
	GROUPING SETS(
	b.bool_10YrCompLoc, 
	b.bool_5YrCompLoc,
	b.bool_2YrCompLoc)
HAVING (CASE 
		WHEN b.bool_10YrCompLoc = 1
			THEN '10YrComp'
		WHEN b.bool_5YrCompLoc = 1
			THEN '5YrComp'
		WHEN b.bool_2YrCompLoc = 1
			THEN '2YrComp' 
		END) IS NOT NULL
UNION ALL
SELECT 
	b.LocationNo,
	b.NRF_Year,
    b.Store_StartOfWeek,
	b.NRF_Week,
	b.NRF_Week_Restated,
    b.sales_CountTransactions,
    b.sales_QtySold,
    b.sales_AmtSold,
    b.sales_QtySold_Used,
    b.sales_QtySold_New,
    b.sales_QtySold_Frontline,
    b.sales_AmtSold_Used,
    b.sales_AmtSold_New,
    b.sales_AmtSold_Frontline,
    b.sales_QtySoldClearance_Used,
    b.sales_QtySoldClearance_FrontlineNew,
    b.sales_AmtSoldClearance_Used,
    b.sales_AmtSoldClearance_FrontlineNew,
    b.sales_QtySoldMarkdown_Used,
    b.sales_QtySoldMarkdown_FrontlineNew,
    b.sales_AmtSoldMarkdown_Used,
    b.sales_AmtSoldMarkdown_FrontlineNew,
    b.buys_CountTransactions,
    b.buys_QtyPurchased,
    b.buys_AmtPurchased,
    b.buys_BuyWaitSeconds,
    b.pricing_QtyPriced,
    b.pricing_AvgPrice,
    b.pricing_AvgListPrice,
    b.pricing_QtyScannerClearance,
    b.pricing_QtyScannerMarkdown,
    b.transfers_QtyDisposed,
    b.transfers_QtyToBookSmarter,
    b.transfers_QtyToLocation
FROM #Base b

IF @RollingAvg = 1
	SELECT 
		b.LocationNo,
		b.NRF_Year,
		b.Store_StartOfWeek,
		b.NRF_Week,
		b.NRF_Week_Restated,
		AVG(b.sales_CountTransactions) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [sales_CountTransactions],
		AVG(b.sales_QtySold ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [sales_QtySold],
		AVG(b.sales_AmtSold ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [sales_AmtSold],
		AVG(b.sales_QtySold_Used ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [sales_QtySold_Used],
		AVG(b.sales_QtySold_New ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [sales_QtySold_New],
		AVG(b.sales_QtySold_Frontline ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [sales_QtySold_Frontline],
		AVG(b.sales_AmtSold_Used ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [sales_AmtSold_Used],
		AVG(b.sales_AmtSold_New ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [sales_AmtSold_New],
		AVG(b.sales_AmtSold_Frontline ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [sales_AmtSold_Frontline],
		AVG(b.sales_QtySoldClearance_Used ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [sales_QtySoldClearance_Used],
		AVG(b.sales_QtySoldClearance_FrontlineNew ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [sales_QtySoldClearance_FrontlineNew],
		AVG(b.sales_AmtSoldClearance_Used ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [sales_AmtSoldClearance_Used],
		AVG(b.sales_AmtSoldClearance_FrontlineNew ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [sales_AmtSoldClearance_FrontlineNew],
		AVG(b.sales_QtySoldMarkdown_Used ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [sales_QtySoldMarkdown_Used],
		AVG(b.sales_QtySoldMarkdown_FrontlineNew ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [sales_QtySoldMarkdown_FrontlineNew],
		AVG(b.sales_AmtSoldMarkdown_Used ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [sales_AmtSoldMarkdown_Used],
		AVG(b.sales_AmtSoldMarkdown_FrontlineNew ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [sales_AmtSoldMarkdown_FrontlineNew],
		AVG(b.buys_CountTransactions ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [buys_CountTransactions],
		AVG(b.buys_QtyPurchased ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [buys_QtyPurchased],
		AVG(b.buys_AmtPurchased ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [buys_AmtPurchased],
		AVG(b.buys_BuyWaitSeconds ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [buys_BuyWaitSeconds],
		AVG(b.pricing_QtyPriced ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [pricing_QtyPriced],
		AVG(b.pricing_AvgPrice ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [pricing_AvgPrice],
		AVG(b.pricing_AvgListPrice ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [pricing_AvgListPrice],
		AVG(b.pricing_QtyScannerClearance ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [pricing_QtyScannerClearance],
		AVG(b.pricing_QtyScannerMarkdown ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [pricing_QtyScannerMarkdown],
		AVG(b.transfers_QtyDisposed ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [transfers_QtyDisposed],
		AVG(b.transfers_QtyToBookSmarter ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [transfers_QtyToBookSmarter],
		AVG(b.transfers_QtyToLocation ) OVER (PARTITION BY b.LocationNo ORDER BY b.Store_StartOfWeek ROWS BETWEEN 52 PRECEDING AND CURRENT ROW) [transfers_QtyToLocation]
	FROM #BaseIdx b
	ORDER BY LocationNo, Store_StartOfWeek
ELSE 
	SELECT 
		b.LocationNo,
		b.NRF_Year,
		b.Store_StartOfWeek,
		b.NRF_Week,
		b.NRF_Week_Restated,
		b.sales_CountTransactions,
		b.sales_QtySold,
		b.sales_AmtSold,
		b.sales_QtySold_Used,
		b.sales_QtySold_New,
		b.sales_QtySold_Frontline,
		b.sales_AmtSold_Used,
		b.sales_AmtSold_New,
		b.sales_AmtSold_Frontline,
		b.sales_QtySoldClearance_Used,
		b.sales_QtySoldClearance_FrontlineNew,
		b.sales_AmtSoldClearance_Used,
		b.sales_AmtSoldClearance_FrontlineNew,
		b.sales_QtySoldMarkdown_Used,
		b.sales_QtySoldMarkdown_FrontlineNew,
		b.sales_AmtSoldMarkdown_Used,
		b.sales_AmtSoldMarkdown_FrontlineNew,
		b.buys_CountTransactions,
		b.buys_QtyPurchased,
		b.buys_AmtPurchased,
		b.buys_BuyWaitSeconds,
		b.pricing_QtyPriced,
		b.pricing_AvgPrice,
		b.pricing_AvgListPrice,
		b.pricing_QtyScannerClearance,
		b.pricing_QtyScannerMarkdown,
		b.transfers_QtyDisposed,
		b.transfers_QtyToBookSmarter,
		b.transfers_QtyToLocation
	FROM #BaseIdx b
	ORDER BY LocationNo, Store_StartOfWeek;

DROP TABLE #Locations
DROP TABLE #Base
DROP TABLE #BaseIdx