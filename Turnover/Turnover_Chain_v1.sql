/****** Script for SelectTopNRows command from SSMS  ******/
SELECT
	DATEADD(MONTH, DATEDIFF(MONTH, 0, asu.AddDate), 0) [BusinessMonth],
	COUNT(asu.UserNo) [count_AddedEmployees],
	COUNT(CASE 
			WHEN asu.Status = 'I'
			THEN asu.UserNo
			END) [count_SubtractedEmployees],
	SUM(COUNT(asu.UserNo)) OVER (ORDER BY DATEADD(MONTH, DATEDIFF(MONTH, 0, asu.AddDate), 0)) [total_AddedEmployees],
	SUM(COUNT(asu.UserNo)) OVER (ORDER BY DATEADD(MONTH, DATEDIFF(MONTH, 0, asu.AddDate), 0)) -
		SUM(COUNT(CASE 
				WHEN asu.Status = 'I'
				THEN asu.UserNo
				END)) OVER (ORDER BY DATEADD(MONTH, DATEDIFF(MONTH, 0, asu.AddDate), 0)) [total_CurrentEmployees]
INTO #AddedEmployees
FROM ReportsData..[ASUsers] asu
	INNER JOIN ReportsData..StoreLocationMaster slm
		ON asu.AddLocationNo = slm.LocationNo
		AND slm.OpenDate <= '1/1/2018'
		AND slm.StoreType IN ('S', 'O')
GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, asu.AddDate), 0)

SELECT 
	DATEADD(MONTH, DATEDIFF(MONTH, 0, asu.ModifyDate), 0) [BusinessMonth],
	COUNT(
		CASE 
			WHEN asu.[Status] = 'I'
			THEN asu.UserNo
			END) [count_Terms],
	SUM(COUNT(
		CASE 
			WHEN asu.[Status] = 'I'
			THEN asu.UserNo
			END)) OVER (ORDER BY DATEADD(MONTH, DATEDIFF(MONTH, 0, asu.ModifyDate), 0)) [total_SubtractedEmployees]
INTO #SubtractedEmployees
FROM [ReportsData]..[ASUsers] asu
	INNER JOIN ReportsData..StoreLocationMaster slm
		ON asu.AddLocationNo = slm.LocationNo
		AND slm.OpenDate <= '1/1/2018'
		AND slm.StoreType IN ('S', 'O')
WHERE asu.ModifyDate >= '1/1/2013'
GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, asu.ModifyDate), 0)

SELECT
	te.BusinessMonth,
	ae.total_CurrentEmployees,
	te.count_Terms,
	CAST(count_Terms AS FLOAT)/CAST((LAG(count_Terms, 12, NULL) OVER (ORDER BY te.BusinessMonth)) AS FLOAT) - 1 [pct_AnnualChange],
	AVG(CAST(count_Terms AS FLOAT)) OVER (ORDER BY te.BusinessMonth ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) [avg12mo_Terms],
	CAST(te.count_Terms AS FLOAT)/CAST(ae.total_CurrentEmployees AS FLOAT)[pct_Turnover]
FROM #SubtractedEmployees te
	LEFT OUTER JOIN #AddedEmployees ae
		ON te.BusinessMonth = ae.BusinessMonth
ORDER BY te.BusinessMonth

DROP TABLE #AddedEmployees
DROP TABLE #SubtractedEmployees