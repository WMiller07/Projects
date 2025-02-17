SELECT 
	slm.LocationNo,
	sir.ProductType,
	CAST(SUM(CASE 
		WHEN sir.Inventory_SectionID = 98
		THEN sir.Quantity
		END) AS FLOAT)/
			CAST(SUM(CASE 
				WHEN sir.Inventory_SectionID <> 98
				THEN sir.Quantity
				END) AS FLOAT) [pct_BackStockofSalesFloor]
FROM HPB_INV..Scheduled_Inventory_Reporting sir
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON sir.LocationNo = slm.LocationNo
WHERE 
		sir.StartDate >= '1/1/2019'
	AND sir.EndDate <= '3/1/2019'
	AND sir.ProductType IN ('UN', 'CDU', 'DVD', 'PB')
GROUP BY slm.LocationNo, ProductType
ORDER BY slm.LocationNo, ProductType
