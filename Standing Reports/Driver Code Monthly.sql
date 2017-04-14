USE [reports]
GO

DECLARE @RC int
DECLARE @DriverUserId int


-- TODO: Set parameter values here.
Declare @startDate as datetime,@EndDate as datetime


--Below code is to fetch the date for the first(sunday) and last day(Saturday) of previous week--

--set @StartDate = DATEADD(wk, -1, DATEADD(DAY, 1-DATEPART(WEEKDAY, GETDATE()), DATEDIFF(dd, 0, GETDATE()))) --first day previous week
--set @EndDate = DATEADD(wk, 0, DATEADD(DAY, 0-DATEPART(WEEKDAY, GETDATE()), DATEDIFF(dd, 0, GETDATE()))) --last day previous week

--Below code is to fetch the date for the first and last day of previous month--

set @StartDate = DATEADD(mm, DATEDIFF(mm, 0, GETDATE()) - 1, 0)
set @EndDate = CONVERT(VARCHAR(25),DATEADD(dd,-(DAY(GETDATE())),GETDATE()),101)



--set  @StartDate=2015-08-24
--set  @EndDate=2015-08-28 
--set  @DriverUserId=9700

Declare @DrvCount as int , @Drv_step as int ,@Drv as int, @Drv_ID as int,@Drv_SEQ_NO as int
select @Drvcount= count(*) from dbo.UserSecurity where SecurityId = 17
print @Drvcount

IF OBJECT_ID('reports_bic.dbo.UserSecurity_sorted_Mnthly', 'U') IS NOT NULL 
  DROP TABLE reports_bic.dbo.UserSecurity_sorted_Mnthly; 

  IF OBJECT_ID('reports_bic.dbo.alldriverdata_Mnthly', 'U') IS NOT NULL 
  DROP TABLE  reports_bic.dbo.alldriverdata_Mnthly; 

  CREATE TABLE reports_bic.[dbo].[alldriverdata_Mnthly](
	[DateCompleted] [date] NULL,
	[SiteId] [int] NULL,
	[SiteName] [varchar](64) NULL,
	[DriverId] [int] NULL,
	[DriverName] [varchar](129) NOT NULL,
	[OrderId] [int] NOT NULL,
	[MissingOrderStat] [bit] NULL,
	[IRCorrect] [bit] NULL,
	[WOMatch] [bit] NULL,
	[Instruct] [bit] NULL,
	[DME] [bit] NULL,
	[Signature] [bit] NULL,
	[Notes] [bit] NULL,
	[Replied] [bit] NULL,
	[SerialNumberDelivery] [int] NULL,
	[OxygenDelivery] [int] NULL,
	[SerialNumberPickup] [int] NULL,
	[OxygenPickup] [int] NULL,
	[TotallyAccurate] [bit] NULL
) ON [PRIMARY]



select * into reports_bic.dbo.UserSecurity_sorted_Mnthly from dbo.UserSecurity where SecurityId = 17
order by Userid ASC

set @Drv_step=1

while (@Drv_step <= @Drvcount)

--while (@Drv_step <= 20)
begin

select @DriverUserId= min(Userid) from reports_bic.dbo.UserSecurity_sorted_Mnthly -- read min Driver id from the list 
--set  @DriverUserId=8604
-----------
----your code starts here


print @StartDate 
print @EndDate
print @DriverUserId

--check to make sure the temp table doesn't already exist
	IF OBJECT_ID(N'tempdb..#tempOrderDelivery') IS NOT null
	BEGIN
		DROP TABLE #tempOrderDelivery
	END
	IF OBJECT_ID(N'tempdb..#tempOrderPickup') IS NOT null
	BEGIN
		DROP TABLE #tempOrderPickup
	END
	IF OBJECT_ID(N'tempdb..#tempOrderDetail') IS NOT null
	BEGIN
		DROP TABLE #tempOrderDetail
	END
	IF OBJECT_ID(N'tempdb..##tempdriverall') IS NOT null
	BEGIN
		DROP TABLE #tempdriverall
	END


	-- Get all the data we'll need - no transforms or calculations, just get in and out fast
	--Get Deliveries
	SELECT o.iOrderID, o.dtCompleted, o.iDriverID,
	od.cStatusID, od.sSerialNumber, od.sO2LotNumber, od.iProductID,
	p.iClientRef AS PiClientRef, p.iSiteRef AS PiSiteRef,
	pk.iSerialCnt AS PKiSerialCnt, pk.iO2Cnt AS PKiO2Cnt
	INTO #tempOrderDelivery
	FROM ss.tblOrder o (NOLOCK)
	INNER JOIN ss.tblOrderDetail od (NOLOCK) ON od.iOrderID = o.iOrderID
	INNER JOIN ss.tblPatient p (NOLOCK) ON p.iPatientID = o.iPatientID
	INNER JOIN ss.setProductKitList pk (NOLOCK) ON pk.iProductRef = od.iProductID AND pk.iClientRef = p.iClientRef AND pk.iSiteRef = p.iSiteRef
	INNER JOIN ss.vCompanyLocation ls (NOLOCK) ON p.iSiteRef = ls.iLocationID
	WHERE o.dtCompleted BETWEEN @StartDate AND @EndDate
	AND ls.iCompanyRef = 2 -- FRAGILE: StateServ
	-- too slow to filter here: AND (o.iDriverID = @DriverUserId OR @DriverUserId IS NULL)

	--Get Pickups
	SELECT o.iOrderID, o.dtCompleted, o.iDriverID,
	od.cStatusID, od.sSerialNumber, od.sO2LotNumber, od.iProductID,
	p.iClientRef AS PiClientRef, p.iSiteRef AS PiSiteRef,
	pk.iSerialCnt AS PKiSerialCnt, pk.iO2Cnt AS PKiO2Cnt
	INTO #tempOrderPickup
	FROM ss.tblOrder o (NOLOCK)
	INNER JOIN ss.tblOrderDetail od (NOLOCK) ON od.iReferenceOrderID = o.iOrderID
	INNER JOIN ss.tblPatient p (NOLOCK) ON p.iPatientID = o.iPatientID
	INNER JOIN ss.setProductKitList pk (NOLOCK) ON pk.iProductRef = od.iProductID AND pk.iClientRef = p.iClientRef AND pk.iSiteRef = p.iSiteRef
	INNER JOIN ss.vCompanyLocation ls (NOLOCK) ON p.iSiteRef = ls.iLocationID
	WHERE o.dtCompleted BETWEEN @StartDate AND @EndDate
	AND ls.iCompanyRef = 2 -- FRAGILE: StateServ
	-- too slow to filter here: AND (o.iDriverID = @DriverUserId OR @DriverUserId IS NULL)


	-- Identify time buckets for Site (& Driver)
	-- Count number of errors per order (0=success, 1=error, -1=n/a)
	SELECT dtCompleted AS DateCompleted,
		PiSiteRef AS SiteId, iDriverId as DriverId, iOrderID AS OrderId,
		SerialNumberDelivery, OxygenDelivery, SerialNumberPickup, OxygenPickup,
		CASE WHEN iOrderStatsID IS NOT NULL THEN CAST(0 AS bit) ELSE CAST(1 AS bit) END AS MissingOrderStat,
		iIRCorrect, iWOMatch, iInstruct, iDME, iSignature, iNotes, iReplied, -- OnCallDone isn't used here
		-- If all of them are 0, it was accurate, mis-use '+' to avoid checking them all, FRAGILE: ASSUME: if there is an OrderStat that all of OrderStat is not null (wasn't -1)
		CASE WHEN iOrderStatsID IS NULL THEN NULL
			WHEN ISNULL(SerialNumberDelivery,0) + ISNULL(OxygenDelivery,0) + ISNULL(SerialNumberPickup,0) + ISNULL(iIRCorrect,0) + ISNULL(iWOMatch,0)
				+ ISNULL(iInstruct,0) + ISNULL(iDME,0) + ISNULL(iSignature,0) + ISNULL(iNotes,0) + ISNULL(iReplied,0) = 0
			THEN CAST(0 AS bit) ELSE CAST(1 AS bit) END AS TotallyAccurate
	INTO #tempOrderDetail
	FROM (
		--Orders with SN / O2 Count for the Date Range
		-- For this order, there were this many lines with errors
		-- Date, Site, (Driver) are merely to surface it to later functions without needing to re-join the tables
		SELECT iOrderID, dtCompleted, PiSiteRef, iDriverID,
			SUM(SerialNumberDelivery) AS SerialNumberDelivery,
			SUM(OxygenDelivery) AS OxygenDelivery,
			SUM(SerialNumberPickup) AS SerialNumberPickup,
			SUM(OxygenPickup) AS OxygenPickup
		FROM (
			--Get all orders between date range, and check if valid SN / O2 on file.
			(
				--Get Delivery Counts - number of errors
				SELECT o.iOrderID, CAST(ss.fn_Date(o.dtCompleted,NULL,2) AS datetime) AS dtCompleted, o.PiSiteRef, iDriverID, 
					CASE WHEN CHARINDEX(cStatusID,'DSHOPMY#GS') != 0 AND ISNULL(o.PKiSerialCnt,0) != 0 AND o.sSerialNumber IS NULL THEN 1 ELSE 0 END AS SerialNumberDelivery,
					CASE WHEN CHARINDEX(cStatusID,'DSHOPMY#GS') != 0 AND ISNULL(o.PKiO2Cnt,0) != 0 AND o.sO2LotNumber IS NULL THEN 1 ELSE 0 END AS OxygenDelivery,
					0 AS SerialNumberPickup, 0 AS OxygenPickup
				FROM #tempOrderDelivery AS o
				WHERE (o.iDriverID = @DriverUserId OR @DriverUserId IS NULL)
		) UNION ALL (
				--Get Pickup Counts - number of errors
				SELECT o.iOrderID, CAST(ss.fn_Date(o.dtCompleted,NULL,2) AS datetime) AS dtCompleted, o.PiSiteRef, iDriverID,
					0 AS SerialNumberDelivery, 0 AS OxygenDelivery,
					CASE WHEN CHARINDEX(cStatusID,'DSHOPMY#GS') != 0 AND ISNULL(o.PKiSerialCnt,0) != 0 AND o.sSerialNumber IS NULL THEN 1 ELSE 0 END AS SerialNumberPickup,
					CASE WHEN CHARINDEX(cStatusID,'DSHOPMY#GS') != 0 AND ISNULL(o.PKiO2Cnt,0) != 0 AND o.sO2LotNumber IS NULL THEN 1 ELSE 0 END AS OxygenPickup
				FROM #tempOrderPickup AS o
				WHERE (o.iDriverID = @DriverUserId OR @DriverUserId IS NULL)
			)
		) AS s
		GROUP BY iOrderID, dtCompleted, PiSiteRef, iDriverID
	) sn
	LEFT JOIN ss.tblOrderStats AS os (NOLOCK) ON os.iOrderRef = sn.iORderID


	-- Harvest details
	SELECT DateCompleted, SiteId, sName as SiteName, DriverId, u.sFirst + ' ' + u.sLast AS DriverName, OrderId,
	MissingOrderStat,
	iIRCorrect AS IRCorrect, iWOMatch AS WOMatch, iInstruct AS Instruct, iDME AS DME, 
	iSignature AS Signature, iNotes AS Notes, iReplied AS Replied, -- OnCallDone isn't used here
	SerialNumberDelivery, OxygenDelivery, SerialNumberPickup, OxygenPickup,
	TotallyAccurate into #tempdriverall
	FROM #tempOrderDetail AS y
	INNER JOIN ss.tblLocation AS ls (NOLOCK) ON y.SiteId = ls.iLocationID
	INNER JOIN ss.tblUser u (NOLOCK) ON u.iUserID = y.DriverID
	ORDER BY ls.sName, u.sFirst + ' ' + u.sLast, OrderId, y.DateCompleted

	insert into reports_bic.dbo.alldriverdata_Mnthly select [DateCompleted],
	[SiteId],
	[SiteName] ,
	[DriverId] ,
	[DriverName] ,
	[OrderId] ,
	[MissingOrderStat] ,
	[IRCorrect] ,
	[WOMatch] ,
	[Instruct] ,
	[DME],
	[Signature] ,
	[Notes] ,
	[Replied],
	[SerialNumberDelivery],
	[OxygenDelivery],
	[SerialNumberPickup] ,
	[OxygenPickup] ,
	[TotallyAccurate] from #tempdriverall;


	--drop the temp tables
	DROP TABLE #tempOrderDelivery
	DROP TABLE #tempOrderPickup
	DROP TABLE #tempOrderDetail
	DROP TABLE #tempdriverall

---your code ends here----

delete from reports_bic.dbo.UserSecurity_sorted_Mnthly where Userid=@DriverUserId

set @Drv_step = @Drv_step +1
end
 --This code is to fetch data for Driver Accuracy Monthly and email it to the recipients--

 Declare @query nvarchar(max);
    Set @query = 'select * from reports_bic.dbo.alldriverdata_Mnthly';

 Execute msdb.dbo.sp_send_dbmail
        @profile_name = 'DMETrack Reports'
      , @recipients = 'croode@stateserv.com;kkahl@stateserv.com;SiteManagers@stateserv.com' 
	 ,@copy_recipients = 'lsantapoor@stateserv.com'
      , @subject = 'Driver Accuracy Monthly Report'
      , @body = 'Hi,
	  
	  Please find the monthly Driver Accuracy Report attached.

	  Let me know in case of any concerns.

	  Have a nice day.
	  
	  Thanks,
	  Lavanya'
      , @query = @query
      , @query_result_separator='	' -- tab
      , @query_result_header = 1
      , @attach_query_result_as_file = 1
      , @query_attachment_filename = 'Driver Accuracy Monthly.csv'
	  ,@query_result_no_padding=1 --trim
	 ,@query_result_width = 32767