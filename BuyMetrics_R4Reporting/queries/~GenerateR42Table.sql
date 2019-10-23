UPDATE Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42
SET AccDaysRangeTo = 14
WHERE BuyGradeName = 'A'

UPDATE Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42
SET AccDaysRangeFrom = 14, AccDaysRangeTo = 50
WHERE BuyGradeName = 'B'

UPDATE Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42
SET AccDaysRangeFrom = 50, AccDaysRangeTo = 150
WHERE BuyGradeName = 'C'

UPDATE Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42
SET AccDaysRangeFrom = 150, AccDaysRangeTo = 486
WHERE BuyGradeName = 'D'

UPDATE Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42
SET AccDaysRangeFrom = 486, AccDaysRangeTo = 6500
WHERE BuyGradeName = 'E'

SELECT 
	BuyGradeID,
	CatalogBinding,
	BuyGradeName,
	AccDaysRangeFrom,
	AccDaysRangeTo,
	BuyOfferPct
FROM Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42