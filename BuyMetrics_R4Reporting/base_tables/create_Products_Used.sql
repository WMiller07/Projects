USE [Sandbox]
GO

CREATE TABLE Sandbox.dbo.Products_Used(
	ItemCode int,
	SipsID int,
	Active char(1),
	LocationNo char(5),
	LocationID char(10),
	DateInStock datetime2(3),
	Price money,
	SubjectKey smallint,
	CatalogID bigint,
	ISBN varchar(13),
	AmazonID varchar(50),
	CreateUser varchar(100),
	CreateMachine nvarchar(128),
	ProductType varchar(4),
	Title varchar(150),
	Author varchar(255),
	PublisherName varchar(80),
	PubDate smalldatetime,
	MfgSuggestedPrice money,
	ISBNSubject varchar(50),
	ItemScore tinyint,
	OriginalPrice money,
	OriginalLocationNo char(5),
	OriginalLocationID char(10),
	LastUpdated datetime2(3)
)
