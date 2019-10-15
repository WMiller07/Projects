SELECT 
	REPLACE(STR(pnl.Loc ,5),' ','0') [LocationNo],
	pnl.Date [BusinessMonth],
	AVG(pnl.Income) OVER (PARTITION BY pnl.Loc ORDER BY pnl.Date ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) [rollavg_Income],
	AVG(pnl.Payroll) OVER (PARTITION BY pnl.Loc ORDER BY pnl.Date ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) [rollavg_Payroll],
	AVG(pnl.Payroll) OVER (PARTITION BY pnl.Loc ORDER BY pnl.Date ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) / 
		NULLIF(AVG(pnl.Income) OVER (PARTITION BY pnl.Loc ORDER BY pnl.Date ROWS BETWEEN 11 PRECEDING AND CURRENT ROW), 0) [rollavg_PayrollPct]
INTO #PayrollPcts
FROM ReportsView..pnl

SELECT 
	p.LocationNo,
	p.BusinessMonth,
	p.rollavg_Income,
	p.rollavg_Payroll,
	p.rollavg_PayrollPct,
	p.rollavg_Income/NULLIF(LAG(p.rollavg_Income, 12) OVER (PARTITION BY p.LocationNo ORDER BY p.BusinessMonth), 0) - 1 [change_Income],
	p.rollavg_Payroll/NULLIF(LAG(p.rollavg_Payroll, 12) OVER (PARTITION BY p.LocationNo ORDER BY p.BusinessMonth), 0) - 1 [change_Payroll],
	p.rollavg_PayrollPct - (LAG(p.rollavg_PayrollPct, 12) OVER (PARTITION BY p.LocationNo ORDER BY p.BusinessMonth)) [change_PayrollPct]
INTO #PayrollPctChanges
FROM #PayrollPcts p


SELECT 
	ppc.LocationNo,
	ppc.BusinessMonth,
	ppc.rollavg_Income,
	ppc.rollavg_Payroll,
	ppc.rollavg_PayrollPct,
	ppc.change_Income,
	ppc.change_Payroll,
	ppc.change_PayrollPct,
	LAG(ppc.change_Payroll, 3) OVER (PARTITION BY ppc.LocationNo ORDER BY ppc.BusinessMonth) [change3mo_Payroll],
	LAG(ppc.change_PayrollPct, 3) OVER (PARTITION BY ppc.LocationNo ORDER BY ppc.BusinessMonth) [change3mo_PayrollPct],
	LAG(ppc.change_Payroll, 6) OVER (PARTITION BY ppc.LocationNo ORDER BY ppc.BusinessMonth) [change6mo_Payroll],
	LAG(ppc.change_PayrollPct, 6) OVER (PARTITION BY ppc.LocationNo ORDER BY ppc.BusinessMonth) [change6mo_PayrollPct]
FROM #PayrollPctChanges ppc
ORDER BY LocationNo, BusinessMonth




DROP TABLE #PayrollPcts
DROP TABLE #PayrollPctChanges