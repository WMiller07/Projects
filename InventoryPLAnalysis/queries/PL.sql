DECLARE @StartDate DATE = '1/1/2010'

SELECT 
	[Date] [BusinessMonth],
	COUNT(DISTINCT p.Loc) [count_Locations],
	SUM(Income) [total_Income],
	SUM(PurchasesCash) [total_PurchasesCash],
	SUM([Purchases-Other]) [total_PurchasesOther],
	SUM(CostOfGoodsSold) [total_CostOfGoodsSold],
	SUM(GrossProfit) [total_GrossProfit],
	SUM(NetIncomeLoss) [total_NetIncomeLoss],
	SUM(Commissions) [total_Commissions]
INTO #PL
FROM ReportsView..pnl p
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON p.Loc = slm.LocationNo 
		AND slm.StoreStatus = 'O'
		AND slm.OpenDate <= @StartDate
		AND slm.StoreType = 'S'
WHERE [Date] >= @StartDate
GROUP BY [Date]

SELECT 
	DATEADD(MONTH, DATEDIFF(MONTH, 0, bbh.StartDate), 0) [BusinessMonth],
	COUNT(DISTINCT bbh.LocationID) [count_Locations],
	COUNT(bbh.BuyXactionID) [count_BuyTransactions],
	SUM(bbh.TotalQuantity) [total_UsedPurchaseQty],
	SUM(bbh.TotalOffer) [total_UsedPurchaseAmt],
	bih.total_UsedPurchaseSipsQty
INTO #BuyTransactions
FROM rHPB_Historical..BuyHeaderHistory bbh
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON bbh.LocationID = slm.LocationID
		AND slm.StoreStatus = 'O'
		AND slm.OpenDate <= @StartDate
		AND slm.StoreType = 'S'
	LEFT OUTER JOIN (
		SELECT
			DATEADD(MONTH, DATEDIFF(MONTH, 0, bbh.StartDate), 0) [BusinessMonth],
			SUM(CASE
				WHEN bih.BuyType NOT IN ('CSU', 'CX', 'MG', 'VDU')
				THEN bih.Quantity
				END) [total_UsedPurchaseSipsQty]
		FROM rHPB_Historical..BuyItemHistory bih
			INNER JOIN rHPB_Historical..BuyHeaderHistory bbh
				ON bbh.BuyXactionID = bih.BuyXactionID
				AND bbh.LocationID = bih.LocationID
			INNER JOIN ReportsView..StoreLocationMaster slm
				ON bih.LocationID = slm.LocationID
				AND slm.StoreStatus = 'O'
				AND slm.OpenDate <= @StartDate
				AND slm.StoreType = 'S' 
		GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, bbh.StartDate), 0)) bih
			ON bih.BusinessMonth = DATEADD(MONTH, DATEDIFF(MONTH, 0, bbh.StartDate), 0)
		
WHERE 
	bbh.BusinessDate >= @StartDate AND
	bbh.Status = 'A'
GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, bbh.StartDate), 0), bih.total_UsedPurchaseSipsQty

SELECT 
	DATEADD(MONTH, DATEDIFF(MONTH, 0, spi.DateInStock), 0) [BusinessMonth],
	COUNT(spi.ItemCode) [total_SipsItemsQty]
INTO #SipsItems
FROM ReportsData..SipsProductInventory spi
GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, spi.DateInStock), 0)

SELECT 
	DATEADD(MONTH, DATEDIFF(MONTH, 0, sr.ProcessDate), 0) [BusinessMonth],
	SUM(sr.Qty) [total_NewReceivedQty]
INTO #DistributionShipments
FROM (
	SELECT 
		sr.ProcessDate,
		sr.Qty
	FROM ReportsView..vw_StoreReceiving sr
	WHERE 
		sr.ShipmentType  IN ('W', 'R') AND
		sr.ProcessDate >= @StartDate
	UNION ALL
	SELECT 
		srh.ProcessDate,
		srh.Qty
	FROM ReportsView..vw_StoreReceiving_Historical srh
	WHERE 
		srh.ShipmentType  IN ('W', 'R') AND
		srh.ProcessDate >= @StartDate
	) sr
GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, sr.ProcessDate), 0)


SELECT 
	DATEADD(MONTH, DATEDIFF(MONTH, 0, shh.StartDate), 0) [BusinessMonth],
	COUNT(shh.SalesXactionID) [count_SalesTransactions],
	SUM(shh.TotalDue) - SUM(shh.SalesTax) [total_SalesAmount]
INTO #SalesTransactions
FROM rHPB_Historical..SalesHeaderHistory shh
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON shh.LocationID = slm.LocationID
		AND slm.StoreStatus = 'O'
		AND slm.OpenDate <= @StartDate
		AND slm.StoreType = 'S'
WHERE 
	shh.Status = 'A'  AND 
	shh.StartDate > @StartDate
GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, shh.StartDate), 0)
ORDER BY BusinessMonth

SELECT 
	pl.BusinessMonth,
	pl.total_Income,
	pl.total_PurchasesCash,
	pl.total_PurchasesOther,
	pl.total_CostOfGoodsSold,
	pl.total_GrossProfit,
	pl.total_NetIncomeLoss,
	pl.count_Locations,
	bt.count_Locations,
	ds.total_NewReceivedQty,
	bt.count_BuyTransactions,
	bt.total_UsedPurchaseQty,
	bt.total_UsedPurchaseSipsQty,
	bt.total_UsedPurchaseAmt,
	si.total_SipsItemsQty,
	bt.total_UsedPurchaseAmt / bt.total_UsedPurchaseQty [avg_ItemCost],
	st.count_SalesTransactions,
	st.total_SalesAmount
FROM #PL pl
INNER JOIN #BuyTransactions bt
	ON pl.BusinessMonth = bt.BusinessMonth
INNER JOIN #SipsItems si
	ON pl.BusinessMonth = si.BusinessMonth
INNER JOIN #SalesTransactions st
	ON pl.BusinessMonth = st.BusinessMonth
INNER JOIN #DistributionShipments ds
	ON pl.BusinessMonth = ds.BusinessMonth
ORDER BY BusinessMonth


DROP TABLE #PL
DROP TABLE #BuyTransactions
DROP TABLE #SipsItems
DROP TABLE #SalesTransactions
DROP TABLE #DistributionShipments
