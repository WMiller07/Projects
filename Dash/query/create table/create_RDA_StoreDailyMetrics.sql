USE [Sandbox]
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET ANSI_PADDING ON
GO

CREATE TABLE [dbo].[RDA_StoreDailyMetrics] (
	DistrictName					varchar(20) not null,
	LocationNo						varchar(5) not null,
	Store_Date						datetime2 not null,
	NRF_Year						int not null,
	NRF_Week_Restated				int,
	NRF_Day							int,
	sales_CountTransactions			int,
	sales_AmtSold					decimal(19,4),
	sales_AmtSold_Frontline			decimal(19,4),
	sales_AmtSold_New				decimal(19,4),
	sales_AmtSold_Used				decimal(19,4),
	sales_QtySold					bigint,
	sales_QtySold_Frontline			bigint,
	sales_QtySold_New				bigint,
	sales_QtySold_Used				bigint,
	buys_CountTransactions			int,
	buys_AmtPurchased				decimal(19,4),
	buys_QtyPurchased				bigint,
	buys_BuyWaitSeconds				bigint,
	iStore_CountTransactions		int,
	iStore_AmtSold					decimal(19,4),
	iStore_QtySold					bigint,
	HPBCom_CountTransactions		int,
	HPBCom_AmtSold					decimal(19,4),
	HPBCom_QtySold					bigint,
	BookSmarter_CountTransactions	int,
	BookSmarter_AmtSold				decimal(19,4),
	BookSmarter_QtySold				bigint,
	count_Locations					int
,CONSTRAINT [PK_RDA_StoreDailyMetrics] PRIMARY KEY CLUSTERED 
(
       [LocationNo] ASC,
	   [Store_Date] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 97) ON [PRIMARY]
) ON [PRIMARY]