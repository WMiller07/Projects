DECLARE @StartDate DATE = '1/1/2016'
DECLARE @EndDate DATE = '1/12/2020'
DECLARE @LocationNo CHAR(5) = '00007'


SELECT 
	bbh.LocationNo,
	DATEADD(DAY, DATEDIFF(DAY, 0, bbh.CreateTime), 0) [BusinessDay],
	DATEADD(HOUR, DATEDIFF(HOUR, 0, bbh.CreateTime), 0) [BusinessHour],
	COUNT(DISTINCT bbh.BuyBinNo) [count_BuyTransactions],
	SUM(bbh.TotalQuantity) [total_BuyItems],
	SUM(bbh.TotalOffer) [total_BuyOffer],
	AVG(CAST(DATEDIFF(SECOND, bbh.CreateTime, bbh.UpdateTime) AS FLOAT) / 60) [avg_BuyWaitMin],
	SUM(CAST(DATEDIFF(SECOND, bbh.CreateTime, bbh.UpdateTime) AS FLOAT)) / SUM(bbh.TotalQuantity) [avg_SecPerItem]
INTO #BuyWaitMetrics
FROM BUYS..BuyBinHeader bbh
WHERE 
		bbh.LocationNo = @LocationNo
	AND bbh.CreateTime >= @StartDate
	AND bbh.CreateTime < @EndDate
	AND bbh.StatusCode = 1
	AND bbh.TotalOffer < 100000
GROUP BY 
	bbh.LocationNo,
	DATEADD(DAY, DATEDIFF(DAY, 0, bbh.CreateTime), 0),
	DATEADD(HOUR, DATEDIFF(HOUR, 0, bbh.CreateTime), 0)
	WITH ROLLUP
ORDER BY
	bbh.LocationNo,
	DATEADD(DAY, DATEDIFF(DAY, 0, bbh.CreateTime), 0),
	DATEADD(HOUR, DATEDIFF(HOUR, 0, bbh.CreateTime), 0)

SELECT 
	bwm.LocationNo,
	bwm.BusinessDay,
	bwm.count_BuyTransactions,
	bwm.total_BuyItems,
	bwm.total_BuyOffer,
	AVG(bwm.avg_BuyWaitMin) OVER (PARTITION BY bwm.LocationNo ORDER BY bwm.BusinessDay ROWS BETWEEN 7 PRECEDING AND CURRENT ROW) [avg7day_BuyWaitMin],
	AVG(bwm.avg_SecPerItem) OVER (PARTITION BY bwm.LocationNo ORDER BY bwm.BusinessDay ROWS BETWEEN 7 PRECEDING AND CURRENT ROW) [avg7day_SecPerItem],
	AVG(bwm.avg_BuyWaitMin) OVER (PARTITION BY bwm.LocationNo ORDER BY bwm.BusinessDay ROWS BETWEEN 28 PRECEDING AND CURRENT ROW) [avg28day_BuyWaitMin],
	AVG(bwm.avg_SecPerItem) OVER (PARTITION BY bwm.LocationNo ORDER BY bwm.BusinessDay ROWS BETWEEN 28 PRECEDING AND CURRENT ROW) [avg28day_SecPerItem],
	AVG(bwm.avg_BuyWaitMin) OVER (PARTITION BY bwm.LocationNo ORDER BY bwm.BusinessDay ROWS BETWEEN 365 PRECEDING AND CURRENT ROW) [avg365day_BuyWaitMin],
	AVG(bwm.avg_SecPerItem) OVER (PARTITION BY bwm.LocationNo ORDER BY bwm.BusinessDay ROWS BETWEEN 365 PRECEDING AND CURRENT ROW) [avg365day_SecPerItem]
INTO #BuyWaitRollAvg
FROM #BuyWaitMetrics bwm
WHERE 
	bwm.BusinessHour IS NULL
AND bwm.BusinessDay IS NOT NULL
ORDER BY BusinessDay

SELECT 
	m.LocationNo,
	m.BusinessDay [BusinessDate],
	DATEPART(HOUR, m.BusinessHour) [BusinessHour],
	m.count_BuyTransactions,
	m.total_BuyItems,
	m.total_BuyOffer,
	m.avg_BuyWaitMin,
	m.avg_SecPerItem,
	ra.avg7day_BuyWaitMin,
	ra.avg7day_SecPerItem,
	ra.avg28day_BuyWaitMin,
	ra.avg28day_SecPerItem,
	ra.avg365day_BuyWaitMin,
	ra.avg365day_SecPerItem
FROM #BuyWaitMetrics m
	INNER JOIN #BuyWaitRollAvg ra
		ON m.BusinessDay = ra.BusinessDay
		AND m.LocationNo = ra.LocationNo
WHERE 
		m.BusinessDay >= DATEADD(YEAR, 1, @StartDate)
	AND m.BusinessHour IS NOT NULL
ORDER BY m.BusinessDay, m.BusinessHour

DROP TABLE #BuyWaitMetrics
DROP TABLE #BuyWaitRollAvg