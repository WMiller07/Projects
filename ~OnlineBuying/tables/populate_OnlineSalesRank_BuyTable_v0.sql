USE [Buy_Online_Analytics]

INSERT INTO [dbo].[OnlineSalesRank_BuyTable_V0_R0] (BuyGradeID, MarketName, CatalogBinding, BuyGradeName, OnlineSalesRankRangeFrom, OnlineSalesRankRangeTo, BuyOfferPct) 
VALUES 
(1, 'Amazon', 'General', 'A', 0, 250000, 0.4),
(2, 'Amazon', 'General', 'B', 250000, 500000, 0.3),
(3, 'Amazon', 'General', 'C', 500000, 1000000, 0.2),
(4, 'Amazon', 'General', 'D', 1000000, 2000000, 0.1),
(5, 'Amazon', 'General', 'E', 2000000, 999999999, 0.05)
