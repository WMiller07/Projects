UPDATE Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42
SET AccDaysRangeTo = 13
WHERE BuyGradeName = 'A'

UPDATE Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42
SET AccDaysRangeFrom = 13, AccDaysRangeTo = 41
WHERE BuyGradeName = 'B'

UPDATE Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42
SET AccDaysRangeFrom = 41, AccDaysRangeTo = 130
WHERE BuyGradeName = 'C'

UPDATE Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42
SET AccDaysRangeFrom = 130, AccDaysRangeTo = 270
WHERE BuyGradeName = 'D'

UPDATE Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42
SET AccDaysRangeFrom = 270, AccDaysRangeTo = 999999
WHERE BuyGradeName = 'E'

SELECT 
	BuyGradeID,
	CatalogBinding,
	BuyGradeName,
	AccDaysRangeFrom,
	AccDaysRangeTo,
	BuyOfferPct
FROM Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42