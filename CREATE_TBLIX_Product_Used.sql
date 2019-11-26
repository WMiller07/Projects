USE [Sandbox]
GO

CREATE TABLE [dbo].[Products_Used](
	[ItemCode] [int] NOT NULL,
	[SipsID] [int] NULL,
	[Active] [char](1) NULL,
	[LocationNo] [char](5) NULL,
	[LocationID] [char](10) NULL,
	[DateInStock] [datetime2](3) NULL,
	[Price] [money] NULL,
	[SubjectKey] [smallint] NULL,
	[CatalogID] [bigint] NULL,
	[ISBN] [varchar](13) NULL,
	[AmazonID] [varchar](50) NULL,
	[CreateUser] [varchar](100) NULL,
	[CreateMachine] [nvarchar](128) NULL,
	[ProductType] [varchar](4) NULL,
	[Title] [varchar](150) NULL,
	[Author] [varchar](255) NULL,
	[PublisherName] [varchar](80) NULL,
	[PubDate] [smalldatetime] NULL,
	[MfgSuggestedPrice] [money] NULL,
	[ISBNSubject] [varchar](50) NULL,
	[ItemScore] [tinyint] NULL,
	[OriginalPrice] [money] NULL,
	[OriginalLocationNo] [char](5) NULL,
	[OriginalLocationID] [char](10) NULL,
	[LastUpdated] [datetime2](3) NULL,
CONSTRAINT [PK_RDA_ProductUsed_ItemCode] PRIMARY KEY CLUSTERED 
(
       [ItemCode] 
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 97) ON [PRIMARY]
) ON [PRIMARY]
GO


