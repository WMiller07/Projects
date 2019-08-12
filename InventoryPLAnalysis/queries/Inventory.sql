SELECT DISTINCT
	sir.LocationNo,
	sir.Inventory_ID,
	sir.Inventory_Description,
	CASE 
		WHEN sir.Inventory_Description LIKE '%Jan%'
			THEN 1
		WHEN sir.Inventory_Description LIKE '%Jun%'
			THEN 6
		END [Month],
	DATEPART(YEAR, EndDate) [Year]
INTO #InventoryIndex
FROM HPB_INV..Scheduled_Inventory_Reporting sir
WHERE 
	sir.Inventory_Description LIKE '%Scheduled Inventory%'
	AND sir.Inventory_Description NOT LIKE '%Pilot%'
ORDER BY [Year], [Month]

SELECT
	sir.LocationNo,
	DATEFROMPARTS(ii.Year, ii.Month, 1) [InventoryDate],
	SUM(sir.Quantity * sir.Factor) [total_Quantity],
	SUM(sir.Cost * sir.Factor) [total_Cost],
	SUM(sir.Price) [total_Price_NoFactor],
	SUM(sir.Quantity) [total_Quantity_NoFactor],
	SUM(sir.Price)/SUM(sir.Quantity) [avg_Price]
INTO #SalesFloorTotals
FROM HPB_INV..Scheduled_Inventory_Reporting sir
	INNER JOIN #InventoryIndex ii
		ON sir.Inventory_ID = ii.Inventory_ID
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON sir.LocationID = slm.LocationId
		AND slm.OpenDate < '1/1/2015'
		AND slm.StoreStatus = 'O'
		AND slm.StoreType = 'S'
WHERE 
	sir.Price < 1000000 AND
	sir.Inventory_SectionID <> 98
GROUP BY sir.LocationNo, DATEFROMPARTS(ii.Year, ii.Month, 1) 

SELECT  
	sir.LocationNo,
	DATEFROMPARTS(ii.Year, ii.Month, 1) [InventoryDate],
	RTRIM(LTRIM(ProductType)) [ProductType],
	CASE WHEN sir.Inventory_SectionID = 98 THEN 'Not On Sales Floor' ELSE 'Sales Floor' END [SalesFloor],
	CASE WHEN sir.ItemType_Description = 'Distribution' THEN 'New' ELSE 'Used' END [ItemClass],
	SUM(sir.Quantity * sir.Factor) [total_Quantity],
	SUM(sir.Cost * sir.Factor) [total_Cost],
	SUM(sir.Price) [total_Price_NoFactor],
	SUM(sir.Quantity) [total_Quantity_NoFactor]
INTO #UngroupedSummary
FROM HPB_INV..Scheduled_Inventory_Reporting sir
	INNER JOIN #InventoryIndex ii
		ON sir.Inventory_ID = ii.Inventory_ID
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON sir.LocationID = slm.LocationId
		AND slm.OpenDate < '1/1/2015'
		AND slm.StoreStatus = 'O'
		AND slm.StoreType = 'S'
WHERE sir.Price < 100000
GROUP BY sir.LocationNo, DATEFROMPARTS(ii.Year, ii.Month, 1), sir.ProductType, sir.Inventory_SectionID, sir.ItemType_Description


SELECT 
	us.InventoryDate,
	us.LocationNo,
	us.ItemClass,
	us.ProductType,
    pt.PTypeGroup,
	us.SalesFloor,
	SUM(us.total_Quantity) [total_Quantity],
	CAST(SUM(us.total_Quantity) AS FLOAT)/ 
		NULLIF(CAST(sft.total_Quantity AS FLOAT), 0) [pct_QuantityOnSalesFloor],
	SUM(us.total_Cost) [total_Cost],
	CAST(SUM(us.total_Cost) AS FLOAT)/ 
		NULLIF(CAST(sft.total_Cost AS FLOAT), 0) [pct_CostOnSalesFloor],
	SUM(us.total_Cost) / NULLIF(SUM(us.total_Quantity), 0) [avg_Cost],
	SUM(us.total_Price_NoFactor) / NULLIF(SUM(us.total_Quantity_NoFactor), 0) [avg_Price],
	CAST(SUM(us.total_Price_NoFactor) AS FLOAT)/ 
		NULLIF(CAST(sft.total_Price_NoFactor AS FLOAT), 0) [pct_PriceOnSalesFloor]
FROM #UngroupedSummary us
    INNER JOIN ReportsData..ProductTypes pt
        ON LTRIM(RTRIM(us.ProductType)) = LTRIM(RTRIM(pt.ProductType))
	INNER JOIN #SalesFloorTotals sft
		ON us.LocationNo = sft.LocationNo AND
		us.InventoryDate = sft.InventoryDate
GROUP BY us.InventoryDate, us.LocationNo, us.ItemClass, us.ProductType, pt.PTypeGroup, us.SalesFloor, sft.total_Quantity, sft.total_Price_NoFactor, sft.total_Cost
ORDER BY ItemClass DESC, ProductType, SalesFloor DESC, InventoryDate