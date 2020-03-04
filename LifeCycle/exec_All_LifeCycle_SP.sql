--DECLARE @StartDate DATE = '7/1/2018'
DECLARE @EndDate DATE = '4/1/2019'

TRUNCATE TABLE Sandbox..Products_Used_Historical
TRUNCATE TABLE Sandbox..ProductLifeCycle_Processing_Historical
TRUNCATE TABLE Sandbox..ItemCode_LifeCycle_Historical


EXEC Sandbox.dbo.ru_Products_Used_Historical @EndDate
EXEC Sandbox.dbo.Update_ItemCode_LifeCycle_Historical_ProcessingTable
EXEC Sandbox.dbo.Populate_ItemCode_LifeCycle_Historical @EndDate


