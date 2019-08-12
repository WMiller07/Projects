DECLARE @StartDate DATE = '1/1/2015'

SELECT 
	slm.LocationNo [LocationNo],
	[Date] [BusinessMonth],
    slm.SalesFloorSize,
	SUM(Income) [total_Income],
    SUM(Income)/NULLIF(slm.SalesFloorSize, 0) [total_IncomePerSqFt],
	SUM(PurchasesCash) [total_PurchasesCash],
	SUM([Purchases-Other]) [total_PurchasesOther],
	SUM(CostOfGoodsSold) [total_CostOfGoodsSold],
	SUM(GrossProfit) [total_GrossProfit],
    SUM(GrossProfit)/NULLIF(slm.SalesFloorSize, 0) [total_GrossProfitPerSqFt],
	SUM(NetIncomeLoss) [total_NetIncomeLoss]
INTO #PL
FROM ReportsView..pnl p
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON p.Loc = slm.LocationNo 
		AND slm.StoreStatus = 'O'
		AND slm.OpenDate <= @StartDate
		AND slm.StoreType = 'S'
WHERE [Date] >= @StartDate
GROUP BY [Date], slm.LocationNo, slm.SalesFloorSize

SELECT 
	bbh.LocationNo,
	DATEADD(MONTH, DATEDIFF(MONTH, 0, bbh.UpdateTime), 0) [BusinessMonth],
	SUM(bbh.TotalQuantity) [total_UsedPurchaseQty],
	SUM(bbh.TotalOffer) [total_UsedPurchaseAmt]
INTO #UsedQtyPurchased
FROM ReportsData..BuyBinHeader bbh
WHERE 
	bbh.CreateTime >= @StartDate AND
	bbh.StatusCode = 1 
GROUP BY bbh.LocationNo, DATEADD(MONTH, DATEDIFF(MONTH, 0, bbh.UpdateTime), 0)

SELECT 
	pl.LocationNo,
	pl.BusinessMonth,
	pl.total_Income,
	pl.total_IncomePerSqFt,
	pl.total_PurchasesCash,
	pl.total_PurchasesOther,
	pl.total_CostOfGoodsSold,
	pl.total_GrossProfit,
	pl.total_GrossProfitPerSqFt,
	pl.total_NetIncomeLoss,
	uqp.total_UsedPurchaseQty,
	uqp.total_UsedPurchaseAmt
FROM #PL pl
INNER JOIN #UsedQtyPurchased uqp
	ON pl.BusinessMonth = uqp.BusinessMonth
	AND pl.LocationNo = uqp.LocationNo
ORDER BY LocationNo, BusinessMonth

DROP TABLE #PL
DROP TABLE #UsedQtyPurchased
