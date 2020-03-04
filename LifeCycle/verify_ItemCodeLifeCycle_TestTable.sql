SELECT 
	lc1.ItemCode,
	lc1.First_RecordDate,
	lc2.First_RecordDate,
	lc1.Days_Total,
	lc2.Days_Total,
	lc1.LastEventType,
	lc2.LastEventType,
	lc1.Last_RecordDate,
	lc2.Last_RecordDate,
	lc1.LifeCycle_Complete,
	lc2.LifeCycle_Complete
FROM Buy_Analytics..ItemCode_LifeCycle lc1
FULL OUTER JOIN Sandbox..ItemCode_LifeCycle_190401 lc2
	ON lc1.ItemCode = lc2.ItemCode
WHERE lc1.Days_Total <> lc2.Days_Total
ORDER BY lc1.ItemCode