DECLARE @StartDate DATE = '1/1/2008'

SELECT	
	DATEADD(MONTH, DATEDIFF(MONTH, 0, bhh.EndDate), 0) [BusinessMonth],
	slm.LocationNo,
	CAST(COUNT(bhh.BuyXactionID) AS FLOAT) [count_BuyTransactions],
	CAST(COUNT(bhh.TotalItems) AS FLOAT) [count_BuyItems]
INTO #BuyMetrics
FROM rHPB_Historical..BuyHeaderHistory bhh
	INNER JOIN MathLab..StoreLocationMaster slm
		ON bhh.LocationID = slm.LocationID
		AND slm.OpenDate < DATEADD(YEAR, -2, @StartDate)
		AND slm.ClosedDate IS NULL
WHERE bhh.Status = 'A'
GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, bhh.EndDate), 0), slm.LocationNo


SELECT 
	REPLACE(STR(pnl.Loc ,5),' ','0') [LocationNo],
	pnl.Date [BusinessMonth],
	AVG(pnl.Income) OVER (PARTITION BY pnl.Loc ORDER BY pnl.Date ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) [rollavg_Income],
	AVG(bm.count_BuyTransactions) OVER (PARTITION BY pnl.Loc ORDER BY pnl.Date ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) [rollavg_CountBuyTransactions],
	AVG(bm.count_BuyItems) OVER (PARTITION BY pnl.Loc ORDER BY pnl.Date ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) [rollavg_CountBuyItems],
	AVG(pnl.Payroll) OVER (PARTITION BY pnl.Loc ORDER BY pnl.Date ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) [rollavg_Payroll],
	AVG(pnl.Payroll) OVER (PARTITION BY pnl.Loc ORDER BY pnl.Date ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) / 
		NULLIF(AVG(pnl.Income) OVER (PARTITION BY pnl.Loc ORDER BY pnl.Date ROWS BETWEEN 11 PRECEDING AND CURRENT ROW), 0) [rollavg_PayrollPct]
INTO #PayrollPcts 
FROM ReportsView..pnl
	INNER JOIN MathLab..StoreLocationMaster slm
		ON REPLACE(STR(pnl.Loc ,5),' ','0') = slm.LocationNo
		AND slm.OpenDate < DATEADD(YEAR, 2, @StartDate)
		AND slm.ClosedDate IS NULL
	LEFT OUTER JOIN #BuyMetrics bm
		ON pnl.Date = bm.BusinessMonth
		AND REPLACE(STR(pnl.Loc ,5),' ','0') = bm.LocationNo

SELECT
	'Index' [LocationNo],
	p.BusinessMonth [BusinessMonth],
	AVG(p.rollavg_Income) [rollavg_Income],
	AVG(p.rollavg_Payroll) [rollavg_Payroll],
	AVG(p.rollavg_Payroll) / AVG(p.rollavg_Income) [rollavg_PayrollPct],
	AVG(p.rollavg_CountBuyTransactions) [rollavg_CountBuyTransactions],
	AVG(p.rollavg_CountBuyItems) [rollavg_CountBuyItems]
INTO #PayrollPctIndex
FROM #PayrollPcts p
GROUP BY p.BusinessMonth

SELECT 
	ppi.LocationNo,
	ppi.BusinessMonth,
	ppi.rollavg_Income,
	ppi.rollavg_Payroll,
	ppi.rollavg_PayrollPct,
	ppi.rollavg_CountBuyTransactions,
	ppi.rollavg_CountBuyItems,
	ppi.rollavg_Income/NULLIF(LAG(ppi.rollavg_Income, 12) OVER (ORDER BY ppi.BusinessMonth), 0) - 1 [change_Income],
	ppi.rollavg_Payroll/NULLIF(LAG(ppi.rollavg_Payroll, 12) OVER (ORDER BY ppi.BusinessMonth), 0) - 1 [change_Payroll],
	ppi.rollavg_PayrollPct - (LAG(ppi.rollavg_PayrollPct, 12) OVER (ORDER BY ppi.BusinessMonth)) [change_PayrollPct],
	ppi.rollavg_CountBuyTransactions/NULLIF(LAG(ppi.rollavg_CountBuyTransactions, 12) OVER (ORDER BY ppi.BusinessMonth), 0) - 1 [change_countBuyTransactions],
	ppi.rollavg_CountBuyItems/NULLIF(LAG(ppi.rollavg_CountBuyItems, 12) OVER (ORDER BY ppi.BusinessMonth), 0) - 1 [change_countBuyItems]
INTO #PayrollPctIndexChange
FROM #PayrollPctIndex ppi
ORDER BY BusinessMonth

SELECT 
	p.LocationNo,
	p.BusinessMonth,
	p.rollavg_Income / ppi.rollavg_Income - 1 [rollavg_Income],
	p.rollavg_Payroll / ppi.rollavg_Payroll - 1 [rollavg_Payroll],
	p.rollavg_PayrollPct - ppi.rollavg_PayrollPct [rollavg_PayrollPct],
	p.rollavg_Income/NULLIF(LAG(p.rollavg_Income, 12) OVER (PARTITION BY p.LocationNo ORDER BY p.BusinessMonth), 0) -  
		ppi.rollavg_Income/NULLIF(LAG(ppi.rollavg_Income, 12) OVER (PARTITION BY p.LocationNo ORDER BY p.BusinessMonth), 0) [change_Income],
	p.rollavg_Payroll/NULLIF(LAG(p.rollavg_Payroll, 12) OVER (PARTITION BY p.LocationNo ORDER BY p.BusinessMonth), 0) - 
		ppi.rollavg_Payroll/NULLIF(LAG(ppi.rollavg_Payroll, 12) OVER (PARTITION BY p.LocationNo ORDER BY p.BusinessMonth), 0) [change_Payroll],
	(p.rollavg_PayrollPct - ppi.rollavg_PayrollPct) - 
		(LAG(p.rollavg_PayrollPct, 12) OVER (PARTITION BY p.LocationNo ORDER BY p.BusinessMonth) - 
		 LAG(ppi.rollavg_PayrollPct, 12) OVER (PARTITION BY p.LocationNo ORDER BY p.BusinessMonth)) [change_PayrollPct],
	p.rollavg_CountBuyTransactions/NULLIF(LAG(p.rollavg_CountBuyTransactions, 12) OVER (PARTITION BY p.LocationNo ORDER BY p.BusinessMonth), 0) - 
		ppi.rollavg_CountBuyTransactions/NULLIF(LAG(ppi.rollavg_CountBuyTransactions, 12) OVER (PARTITION BY p.LocationNo ORDER BY p.BusinessMonth), 0) [change_countBuyTransactions],
	p.rollavg_CountBuyItems/NULLIF(LAG(p.rollavg_CountBuyItems, 12) OVER (PARTITION BY p.LocationNo ORDER BY p.BusinessMonth), 0) - 
		ppi.rollavg_CountBuyItems/NULLIF(LAG(ppi.rollavg_CountBuyItems, 12) OVER (PARTITION BY p.LocationNo ORDER BY p.BusinessMonth), 0) [change_countBuyItems]
INTO #PayrollPctChanges
FROM #PayrollPcts p
	INNER JOIN #PayrollPctIndexChange ppi
		ON p.BusinessMonth = ppi.BusinessMonth

SELECT 
	ppc.LocationNo,
	ppc.BusinessMonth,
	ppc.rollavg_Income [rollavg_Income],
	ppc.rollavg_Payroll [rollavg_Payroll],
	ppc.rollavg_PayrollPct [rollavg_PayrollPct],
	ppc.change_Income [change_Income],
	ppc.change_Payroll  [change_Payroll],
	ppc.change_PayrollPct [change_PayrollPct],
	ppc.change_CountBuyTransactions [change_BuyTransactions],
	ppc.change_CountBuyItems [change_BuyItems],
	LAG(ppc.change_Payroll, 3) OVER (PARTITION BY ppc.LocationNo ORDER BY ppc.BusinessMonth) [change3mo_Payroll],
	LAG(ppc.change_PayrollPct, 3) OVER (PARTITION BY ppc.LocationNo ORDER BY ppc.BusinessMonth) [change3mo_PayrollPct],
	LAG(ppc.change_Payroll, 6) OVER (PARTITION BY ppc.LocationNo ORDER BY ppc.BusinessMonth) [change6mo_Payroll],
	LAG(ppc.change_PayrollPct, 6) OVER (PARTITION BY ppc.LocationNo ORDER BY ppc.BusinessMonth) [change6mo_PayrollPct],
	LAG(ppc.change_Payroll, 12) OVER (PARTITION BY ppc.LocationNo ORDER BY ppc.BusinessMonth) [change12mo_Payroll],
	LAG(ppc.change_PayrollPct, 12) OVER (PARTITION BY ppc.LocationNo ORDER BY ppc.BusinessMonth) [change12mo_PayrollPct],
	LAG(ppc.change_countBuyTransactions, 3) OVER (PARTITION BY ppc.LocationNo ORDER BY ppc.BusinessMonth) [change3mo_BuyTransactions],
	LAG(ppc.change_countBuyItems, 3) OVER (PARTITION BY ppc.LocationNo ORDER BY ppc.BusinessMonth) [change3mo_BuyItems],
	LAG(ppc.change_countBuyTransactions, 6) OVER (PARTITION BY ppc.LocationNo ORDER BY ppc.BusinessMonth) [change6mo_BuyTransactions],
	LAG(ppc.change_countBuyItems, 6) OVER (PARTITION BY ppc.LocationNo ORDER BY ppc.BusinessMonth) [change6mo_BuyItems],
	LAG(ppc.change_countBuyTransactions, 12) OVER (PARTITION BY ppc.LocationNo ORDER BY ppc.BusinessMonth) [change12mo_BuyTransactions],
	LAG(ppc.change_countBuyItems, 12) OVER (PARTITION BY ppc.LocationNo ORDER BY ppc.BusinessMonth) [change12mo_BuyItems]
FROM #PayrollPctChanges ppc
ORDER BY LocationNo, BusinessMonth



DROP TABLE #BuyMetrics
DROP TABLE #PayrollPcts
DROP TABLE #PayrollPctChanges
DROP TABLE #PayrollPctIndex
DROP TABLE #PayrollPctIndexChange