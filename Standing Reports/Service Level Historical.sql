USE [reports]
GO

/****** Object:  StoredProcedure [dbo].[sp_GetOrderManagementOrders_v2]    Script Date: 1/11/2017 1:48:25 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('reports_bic.dbo.ServiceLevel', 'U') IS NOT NULL 
DROP TABLE  reports_bic.dbo.ServiceLevel; 
CREATE table reports_bic.dbo.ServiceLevel
(
	dmeID int null,
	siteID int null,
	OrderId int null,
	RouteNumber int null,
	PatientId int null,
	PatientLastName varchar(60) null,
	DateType int null, -- null,0,1,2,3 null all dates, 0 default scheduled date, 1 order date, 2 complete date, 3 AutoCompleted
	StartDate datetime null,
	EndDate datetime null,
	OrderStatus varchar(25) null,
	Clients varchar(8000) null,
	Tags varchar(255) null,
	SortBy [varchar](25) null,
	Priority [bit] null,
	ScheduleStartTime smalldatetime null,
	ScheduleEndTime smalldatetime null
)ON [PRIMARY]


--WITH RECOMPILE

	-- temp workaround for "Scheduled" status
	--IF @vcOrderStatus = 'S'
	--	SET @vcOrderStatus = 'S,R,T,U,Q,D,E,P'
/*
-=[Version Infomration]=-
Name        Date     VER Update
I. Erickson 20061219 1.1 Updated to handle new Order / Order Detail structure.
I. Erickson 20070620 1.2 Updated for Address Detail Changes
I. Erickson 20070625 1.3 Updated for Order Referance Change to Detail Table
						  App was not using Refernece Number as such was dropped
I. Erickson 20070627 1.4 Added Infectious Char field
I. Erickson 20080725 1.5 Order Note Counter now counting non disabled notes only
I. Erickson 20080923 1.6 OrderID was being converted to an AlphaNumeric before 
						  sorting. Caused issues as we rolled over 100000 orders 
						  as it was placing 100000 before 99999
I. Erickson 20091204 1.7 Returning Patient and Order Flags for Icon Highlights on Dash
I. Erickson 20091209 1.8 Rebuilt for speed on joins and cleaned it up.
I. Erickson 20091215 1.9 Added Duplicate watch from Patient Table
I. Erickson 20100604 2.0 Update for Version 2.0 DME Track network backend.
I. Erickson 20100611 2.01 Update for Version 2.0 DME Track user backend.
C. Roode	20100902 2.02 Added @dmeID and @siteID to filter on DME OR DME AND SITE
I. Erickson 20100906 2.1 Added corys search date mode, fixed end date to be end of day of day selected.
C. Roode	20100910 2.2 Fixed bug with WHERE clause using @cSearchType and evaluating it as an int
C. Roode	20100916 2.3 Added @cSearchType = 3 so SSM users can still search by only scheduled date
E.Eilertsen 20110819 2.4 Outputs times offset by timezone.
E.Eilertsen 20120307 2.5 Changed ClientRef input to 2000 chars.
f. ramos		20160216 2.6 adding specialty column

-=[Called By]=-
Dashboard.aspx

-=[Example Calls]=-
exec ss.sp_GetPatientOrdersByDate '6,7,8', '2010-01-01','2010-01-02', null, null, null
exec ss.sp_GetPatientOrdersByDate 8, null, null, '2010-09-01', '2010-09-010', null, null, null, "2"

	@dmeID			int,
	@siteID			int,
	@iClientID		varchar(255) = null,
	@dtmStartDate  	datetime = null,
	@dtmEndDate		datetime = null,
	@vcSortBy		varchar(25) = null,
	@vcOrderStatus	varchar(25) = null,
	@vcDrivers		varchar(255) = null,
	@cSearchType	char(1) = 1 --1 for orderdate, 2 for completion date

-=[Function]=-
Called by dashboard.aspx, looks up orders by patient.
*/	

 BEGIN


	DECLARE @dmeID int
	DECLARE @siteID int
	DECLARE @OrderId int 
	DECLARE @RouteNumber int 
	DECLARE @PatientId int 
	DECLARE @PatientLastName varchar(60) 
	DECLARE @DateType int-- null,0,1,2,3 null all dates, 0 default scheduled date, 1 order date, 2 complete date, 3 AutoCompleted
	DECLARE @StartDate datetime 
	DECLARE @EndDate datetime
	DECLARE @OrderStatus varchar(25)
	DECLARE @Clients varchar(8000) 
	DECLARE @Tags varchar(255) 
	DECLARE @SortBy [varchar](25) 
	DECLARE @Priority [bit] 
	DECLARE @ScheduleStartTime smalldatetime 
	DECLARE @ScheduleEndTime smalldatetime

	DECLARE @SearchSingleOrderOnly bit = 0
	DECLARE @SearchByRouteNumberOnly bit = 0
	DECLARE @PatientIdOnly bit = 0
	DECLARE @PatientLastnameOnly bit = 0
	DECLARE @NotReconciled bit = 0
	DECLARE @AnyDriverId bit = 0
	DECLARE @UnScheduled bit = 0
	DECLARE @StartTime as varchar(8)
	DECLARE @EndTime as varchar(8)

	set @dmeID=2

--set @StartDate = GETDATE()
--set @EndDate = GETDATE()
--set @StartDate = '11/25/2016'
--SET @StartDate= GETDATE()
--set @EndDate = '01/25/2017'
--Set @EndDate= GETDATE()
set @StartDate = DATEADD(mm, DATEDIFF(mm, 0, GETDATE()) - 2, 0)
set @EndDate = GetDate()
print @StartDate
Print @EndDate
	
	--Below code is to fetch the date for the first and last day of previous month--

--set @StartDate = DATEADD(mm, DATEDIFF(mm, 0, GETDATE()) - 1, 0)
--set @EndDate = CONVERT(VARCHAR(25),DATEADD(dd,-(DAY(GETDATE())),GETDATE()),101)

	IF (@OrderId IS NULL AND @RouteNumber IS NULL AND @PatientId IS NULL AND @PatientLastName IS NULL AND @StartDate IS NULL AND @OrderStatus IS NULL AND @Clients IS NULL AND @Tags IS NULL) BEGIN
return
	END

	IF (ISNULL(@OrderId, 0) <> 0 AND ISNUMERIC(@OrderId) = 1) BEGIN

		SET @SearchSingleOrderOnly = 1
		SET @SearchByRouteNumberOnly = 0
		SET @PatientIdOnly = 0
		SET @PatientLastnameOnly = 0
		SET @RouteNumber = null
		SET @PatientId = null
		SET @PatientLastName = null
		SET @DateType = 0 -- null,0,1,2,3 null all dates, 0 default scheduled date, 1 order date, 2 complete date, 3 AutoCompleted
		SET @StartDate = null
		SET @EndDate = null
		SET @OrderStatus = null
		SET @Clients = null
		SET @Tags = null
	END	ELSE IF (ISNULL(@RouteNumber, 0) <> 0 AND ISNUMERIC(@RouteNumber) = 1) BEGIN
		SET @SearchSingleOrderOnly = 0
		SET @SearchByRouteNumberOnly = 1
		SET @PatientIdOnly = 0
		SET @PatientLastnameOnly = 0
		SET @PatientId = null
		SET @PatientLastName = null
		SET @DateType = 0
		SET @OrderStatus = null
		SET @Clients = null
		SET @Tags = null
	END	ELSE IF (ISNULL(@PatientId, 0) <> 0 AND ISNUMERIC(@PatientId) = 1) BEGIN
		SET @SearchSingleOrderOnly = 0
		SET @SearchByRouteNumberOnly = 0
		SET @PatientIdOnly = 1
		SET @PatientLastnameOnly = 0
		SET @RouteNumber = null
		SET @PatientLastName = null
		SET @DateType = 0 -- null,0,1,2,3 null all dates, 0 default scheduled date, 1 order date, 2 complete date, 3 AutoCompleted
		SET @StartDate = null
		SET @EndDate = null
		SET @OrderStatus = null
		SET @Clients = null
		SET @Tags = null
	END	ELSE IF @PatientLastName IS NOT NULL BEGIN
		SET @SearchSingleOrderOnly = 0
		SET @SearchByRouteNumberOnly = 0
		SET @PatientIdOnly = 0
		SET @PatientLastnameOnly = 1
		SET @PatientId = null
	END

	IF(@Tags IS NULL) BEGIN SET @AnyDriverId = 1 END

	SELECT @UnScheduled = 1 FROM ss.fn_Split(@OrderStatus, ',') WHERE value = 'R'

	DECLARE @ScheduledStatus bit = 0
	SELECT @ScheduledStatus = 1 FROM ss.fn_Split(@OrderStatus, ',') WHERE value = 'S'

	if @Priority is not null and @Priority = 1 begin
		-- if Priority was included in the querya and the Schedule status is not in orderstatus
		-- then inject the 'S"cheduled status
		if @ScheduledStatus = 0
			IF (@OrderStatus IS NOT NULL)
				SET @OrderStatus =  @OrderStatus + ',S'
			else
				SET @OrderStatus =  ',S'

		SET @ScheduledStatus = 1
	end

	DECLARE @PriorityId TABLE (PriorityId bit)
	if @Priority is null
		insert into @PriorityId values (0),(1)
	else
		insert into @PriorityId values (1)

	if @ScheduleStartTime is null
		set @StartTime =  '00:00:00'
	else
		set @StartTime = CONVERT(VARCHAR(8),CONVERT(TIME,@ScheduleStartTime))

	if @ScheduleEndTime is null
		set @EndTime =  '23:59:59'
	else
		set @EndTime = CONVERT(VARCHAR(8),CONVERT(TIME,@ScheduleEndTime))

	IF (@OrderStatus IS NOT NULL AND @ScheduledStatus = 1) BEGIN
		IF(@DateType IS NULL) SET @DateType = 0
		SET @OrderStatus =  @OrderStatus + ',R'
		SET @OrderStatus = REPLACE ( @OrderStatus, 'S' , '' )
		SET @OrderStatus = REPLACE ( @OrderStatus, ',,' , ',' )
	END

	DECLARE @NotReconciledStatus bit = 0
	SELECT @NotReconciledStatus = 1 FROM ss.fn_Split(@OrderStatus, ',') WHERE value = '!'
	IF @NotReconciledStatus = 1 BEGIN
		IF(@StartDate IS NULL AND @SearchSingleOrderOnly = 0 ) SET @StartDate = '2009-09-01'
		IF(@EndDate IS NULL AND @SearchSingleOrderOnly = 0 ) SET @EndDate = GETDATE()
		IF(@DateType IS NULL) SET @DateType = 0
		SET @NotReconciled = 1
		SET @OrderStatus= REPLACE ( @OrderStatus, '!' , '' )
		SET @OrderStatus= REPLACE ( @OrderStatus, ',,' , ',' )
	END

	IF(@DateType IS NULL AND @SearchSingleOrderOnly = 0 ) BEGIN
		IF(@StartDate IS NULL) SET @StartDate = DATEADD(dd, 0, DATEDIFF(dd, 0, GETDATE()))
		IF(@EndDate IS NULL) SET @EndDate = @StartDate
	END

	IF(@StartDate IS NOT NULL AND @EndDate IS NULL) BEGIN
		SET @EndDate = @StartDate
	END

	--Set End Date to End of Day
	--SET @StartDate = DATEADD(dd, 0, DATEDIFF(dd, 0, @StartDate))
	--set @EndDate = DATEADD(MS, -3, DATEADD(dd, 1, DATEDIFF(dd, 0, @EndDate)))
--set @StartDate = DATEADD(mm, DATEDIFF(mm, 0, GETDATE()) - 2, 0)
--set @EndDate = GetDate()
set @StartDate = DATEADD(mm, DATEDIFF(mm, 0, GETDATE()) - 2, 0)
set @EndDate = GetDate()

	--This takes unknown site id value of -1 to null all sites.
	if @siteID = -1 begin set @siteID = null end

	DECLARE @StartDateTZ datetime = DATEADD(HOUR,-6,@StartDate)
	DECLARE @EndDateTZ datetime = DATEADD(HOUR,+6,@EndDate)

	IF(@OrderStatus IS NULL) BEGIN SET @OrderStatus = 'R,S,T,U,Q,D,P,QU' END
	DECLARE @OrderStatuses TABLE (
		cStatusId varChar(3)
	)
	INSERT INTO @OrderStatuses
	SELECT DISTINCT Value FROM ss.fn_Split(@OrderStatus, ',') 

	DECLARE @Orders TABLE (
		iOrderId INT,
		cStatusId varChar(3),
		cTypeId varChar(3),
		dtDateStamp datetime,
		dtScheduled datetime,
		dtCompleted datetime,
		iRouteNumber INT,
		blnAddOnStop BIT,
		sLastViewedBy varChar(32),
		dtLastViewed datetime,
		dtxOnCallDone datetime,
		dtxReconciled datetime,
		cReason varChar(1),
		szPhone1 varChar(20),
		szPhone2 varChar(20),
		szContactName varChar(128),
		iAddressRef INT,
		iDriverID INT,
		iOrderedBy INT,
		CompletionActionId INT,
		Priority BIT,
		ScheduleEnd smalldatetime,
		iPatientID INT,
		RouteId INT,
		LOX BIT,
		isServiceCall BIT
	)
	INSERT INTO @Orders
	SELECT DISTINCT o.iOrderID, o.cStatusID, o.cTypeID, o.dtDateStamp, o.dtScheduled, o.dtCompleted, o.iRouteNumber, o.blnAddOnStop, 
		o.sLastViewedBy, o.dtLastViewed, o.dtxOnCallDone, o.dtxReconciled, o.cReason, o.szPhone1, o.szPhone2, o.szContactName,
		o.iAddressRef, o.iDriverID, o.iOrderedBy, o.CompletionActionId, o.Priority, o.ScheduleEnd, o.iPatientID, o.RouteId, 0 AS LOX,o.IsServiceCall as isServiceCall
	FROM ss.tblOrder o (NOLOCK)
	JOIN @OrderStatuses os ON os.cStatusId = o.cStatusID
	WHERE 1=1
	AND ((@SearchSingleOrderOnly = 1 AND o.iOrderId = @OrderId) OR (o.iOrderId is not null and @SearchSingleOrderOnly = 0))
	AND ((@PatientIdOnly = 1 AND o.iPatientID = @PatientId) OR (@PatientIdOnly = 0))
	AND ((@SearchByRouteNumberOnly = 1 AND o.iRouteNumber = @RouteNumber) OR (@SearchByRouteNumberOnly = 0))
	AND (	
			(@DateType = 0 AND ((o.dtScheduled BETWEEN @StartDateTZ AND @EndDateTZ ) OR (@StartDate IS NULL AND @EndDate IS NULL)))
		OR (@DateType = 1 AND ((o.dtDateStamp BETWEEN @StartDate AND @EndDate) OR (@StartDate IS NULL AND @EndDate IS NULL )))
		OR (@DateType = 2 AND ((o.dtCompleted BETWEEN @StartDate AND @EndDate ) OR (@StartDate IS NULL AND @EndDate IS NULL )))
		OR (@DateType = 3 AND ((o.dtCompleted BETWEEN @StartDate AND @EndDate AND o.CompletionActionId = 2 ) OR (@StartDate IS NULL AND @EndDate IS NULL )))
		OR (@DateType IS NULL AND (((o.dtScheduled BETWEEN @StartDateTZ AND @EndDateTZ )) OR (o.dtDateStamp BETWEEN @StartDate AND @EndDate) OR (o.dtCompleted BETWEEN @StartDate AND @EndDate )))
	)
	AND ((@NotReconciled = 1 AND o.dtxReconciled IS NULL AND o.dtCompleted IS NOT NULL) OR @NotReconciled = 0 )

	UPDATE @Orders SET Priority = 0 WHERE Priority IS NULL

	--UPDATE @Orders SET
	--	LOX = 1
	--WHERE iOrderId IN (
	--	SELECT o.iOrderId
	--	FROM @Orders o
	--	JOIN ss.tblorderdetail od on od.iOrderId = o.iOrderId
	--	JOIN ss.tblProductEquip pe on pe.iProductRef = od.iProductID
	--	JOIN ss.tblEquipment e on e.iEquipmentID = pe.iEquipmentRef
	--	WHERE e.iItemRef in ( 142,143,144,145,146,147 )
	--	AND cTypeId = 'D'
	--)

	DECLARE @Patients TABLE (
		iPatientId INT,
		iClientRef INT,
		iSiteRef INT,
		dtDisableDate datetime,
		szFullName varChar(150),
		cInfectious varChar(1),
		dtTorpid datetime,
		iDup INT,
		szLastName varChar(64)
	)
	IF  @PatientLastnameOnly = 1 BEGIN
		INSERT INTO @Patients 
		SELECT p.iPatientID, p.iClientRef, p.iSiteRef, p.dtDisableDate, p.szLastName + ', ' + p.szFirstName + ' ' + ISNULL(p.cMiddleInit, '') AS szFullName,
			p.cInfectious, p.dtTorpid, p.iDup , p.szLastName
		FROM ss.tblPatient p (NOLOCK)
		INNER JOIN ss.tblLocation dme (NOLOCK) ON dme.iLocationID = p.iSiteRef AND dme.iCompanyRef = @dmeID and dme.cType = 'S'
		WHERE 1=1
		AND p.szLastName LIKE '' + @PatientLastName + '%'
	END ELSE BEGIN
		INSERT INTO @Patients 
		SELECT p.iPatientID, p.iClientRef, p.iSiteRef, p.dtDisableDate, p.szLastName + ', ' + p.szFirstName + ' ' + ISNULL(p.cMiddleInit, '') AS szFullName,
			p.cInfectious, p.dtTorpid, p.iDup , p.szLastName
		FROM ss.tblPatient p (NOLOCK)
		INNER JOIN ss.tblLocation dme (NOLOCK) ON dme.iLocationID = p.iSiteRef AND dme.iCompanyRef = @dmeID and dme.cType = 'S'
		WHERE 1=1
		AND (( @PatientIdOnly = 1 AND p.iPatientID = @PatientId ) OR (@PatientIdOnly = 0))
	END
 
  IF OBJECT_ID('reports_bic.dbo.OrderManagementData', 'U') IS NOT NULL 
  DROP TABLE  reports_bic.dbo.OrderManagementData; 

create table reports_bic.dbo.OrderManagementData(
		iOrderId INT,
		cStatusId varChar(3),
		cTypeId varChar(3),
		dtDateStamp datetime,
		dtScheduled date,
		dtCompleted datetime,
		iRouteNumber INT,
		blnAddOnStop BIT,
		sLastViewedBy varChar(32),
		dtLastViewed datetime,
		dtxOnCallDone datetime,
		dtxReconciled datetime,
		cReason varChar(1),
		szPhone1 varChar(20),
		szPhone2 varChar(20),
		szContactName varChar(128),
		iPatientID INT,
		dtDisableDate datetime,
		szFullName varChar(150),
		cInfectious varChar(1),
		dtTorpid datetime,
		iDup INT,
		szCompanyName varChar(64),
		iClientID INT,
		SiteID INT,
		iAddressRef INT,
		iDriverID INT,
		iOrderedBy INT,
		CompletionActionId INT,
		SiteName varChar(64),
		Region varchar(60),
		Priority int,
		ScheduleEnd smalldatetime,
		RouteId INT,
		iTZID INT,
		LOX INT,
		isServiceCall INT,
		Missed int--,
		--Variance time
	)
	INSERT INTO reports_bic.dbo.OrderManagementData
	SELECT o.iOrderID, o.cStatusID, o.cTypeID, o.dtDateStamp, o.dtScheduled, o.dtCompleted, o.iRouteNumber, o.blnAddOnStop, 
		o.sLastViewedBy, o.dtLastViewed, o.dtxOnCallDone, o.dtxReconciled, o.cReason, o.szPhone1, o.szPhone2, o.szContactName,
		p.iPatientID, p.dtDisableDate, p.szFullName, p.cInfectious, p.dtTorpid, p.iDup,
		c.sName AS szCompanyName, c.iLocationID AS iClientID, p.iSiteRef AS SiteID,
	o.iAddressRef, o.iDriverID, o.iOrderedBy, o.CompletionActionId, s.sName As SiteName,r.region as Region,o.Priority,o.ScheduleEnd, RouteId, tz.iTZID, o.LOX,o.isServiceCall,case
		when DATEDIFF(minute,ScheduleEnd,dtCompleted)>30 and o.priority=1 then '1'
		else '0'
	end as Missed
	--, SUBSTRING(CONVERT(VARCHAR(20),(dtCompleted - dtScheduled),120),12,8) as variance
	FROM @Orders o
	
	  	join @Patients AS p ON o.iPatientID = p.iPatientID
		join ss.tblLocation AS c (NOLOCK) ON p.iClientRef = c.iLocationID and c.cType = 'C'
		join ss.tblLocation s (NOLOCK) ON p.iSiteRef = s.iLocationID and s.cType = 'S'
		left join reports_bic.dbo.ServiceLevelRegions as R ON s.sName=r.Site
		left join ss.tblTimeZone tz (NOLOCK) on tz.iTZID = ss.fn_GetTimeZone(@dmeID,p.iSiteRef,null)
	WHERE 1=1
		AND (
				(@UnScheduled = 1 AND o.dtScheduled IS NULL) OR (@ScheduledStatus = 1 AND o.dtScheduled IS NOT NULL AND o.Priority in (SELECT PriorityId FROM @PriorityId))
				OR ((@UnScheduled = 0 AND @ScheduledStatus = 0) AND (o.dtScheduled IS NULL OR o.dtScheduled IS NOT NULL)) 
		)
		AND (
				(o.iDriverID  IN (SELECT ISNULL(Value, isnull(o.iDriverID,0)) FROM ss.fn_Split(@Tags, ',')))
				OR (o.iDriverID IS NULL AND @AnyDriverId = 1)
		)
		AND p.iClientRef IN (SELECT ISNULL(Value, p.iClientRef) FROM ss.fn_Split(@Clients, ','))
		AND s.iCompanyRef = @dmeID
		AND ( @siteID IS NULL OR p.iSiteRef = @siteID )

	select 
		opC.szCompanyName, 
		Opc.iOrderID,
		Opc.cStatusID,
		Opc.cTypeID,
		CASE 
			WHEN Opc.cStatusID IN ('Q', 'T','U') THEN 'ENRT'
			WHEN Opc.cStatusID IN ('D','E','P') THEN 'DONE'
			WHEN Opc.cStatusID IN ('R') THEN 'RECV'
			WHEN Opc.cStatusID IN ('QU') THEN 'QUEUED'
		END as szStatus,
		Opc.cTypeID,
		CASE Opc.cTypeID
			WHEN 'P' THEN 'PU'
			WHEN 'D' THEN 'DEL'
			WHEN 'E' THEN 'EXCH'
		END as szType,
		t.szType,
		ss.fn_LocationTime(Opc.dtDateStamp,opc.iTZID,0) AS dtDateStamp,
		CONVERT(CHAR(10), ss.fn_LocationTime(Opc.dtScheduled,opc.iTZID,0), 101) AS dtScheduled,
		ss.fn_LocationTime(Opc.dtCompleted,opc.iTZID,0) AS dtComplete,
		ss.fn_LocationTime(oPc.dtDisableDate,opc.iTZID,0) AS dtDisableDate,
		oPc.szFullName,
		REPLACE(a.szAddress1,'''', '') as szAddress1,
		a.szAddress2, a.szCity, a.szState, a.szZip,
		Opc.szPhone1, Opc.szPhone2, Opc.szContactName,
		CASE a.szDeliveryLocation
			WHEN 'ACH' THEN 'ACH (Adult Care Home)'
			WHEN 'AL' THEN 'AL (Assisted Living)'
			WHEN 'LTC' THEN 'LTC (Long Term Care)'
			WHEN 'RES' THEN 'Residence'
		END as szDeliveryLocation,
		u.sFull AS szSubmitter,
		oPc.iPatientID,
		du.sFirst + ' ' + LEFT(du.sLast,1) + '.' AS Driver,
		np.iNoteCnt AS iNoteCount,
		opC.iClientID,
		du.iUserID as iDMEUserID, du.sUser as szUserName,
		opC.SiteID,
		Opc.iRouteNumber,
		case Opc.blnAddOnStop WHEN 0 THEN 'No' ELSE 'Yes' END As blnAddOnStop,
		Opc.sLastViewedBy,
		ss.fn_LocationTime(Opc.dtLastViewed,opc.iTZID,0) AS dtLastViewed,
		qa.iQAAnswerID,
		case oPc.cInfectious when '?' then '' when '0' then '' else ltrim(oPc.cInfectious) end as cInfectious,
		isnull(oPc.iDup,0) as duplicate,
		ss.fn_ORS(Opc.cStatusID,
			case when isnull(Opc.dtxOnCallDone,0) = 0 then 0 else 1 end,
			case when isnull(Opc.dtxReconciled,0) = 0 then 0 else 1 end,
			-1,
			case when isnull(Opc.dtCompleted,0) = 0 then 0 else datediff(hh,ss.fn_LocationTime(Opc.dtCompleted,opc.iTZID,0),ss.fn_LocationTime(GETDATE(),opc.iTZID,0)) end
		) as ORS,
		isnull(Opc.cReason,'O') as ORC, lORC.sName as sORC,
		case when isnull(oPc.dtTorpid,0) = 0 then 0 else 1 end as PF_Torpid,
		case when isnull(oPc.dtDisableDate,0) = 0 then 0 else 1 end as PF_Disable,
		case when (np.dLastUpdate) > dateadd(s,1,isnull(Opc.dtLastViewed,'1900-01-01 00:00:00.000')) then 1 else 0 end as OF_NewNote,
		a.Latitude, a.Longitude,
		a.RoomNum, a.BedNum, a.Name
		, opc.CompletionActionId, opc.SiteName,opc.Priority, 
		ss.fn_LocationTime(opc.dtScheduled,opc.iTZID,0) as ScheduleStart, 
		ss.fn_LocationTime(opc.ScheduleEnd,opc.iTZID,0) as ScheduleEnd,
		tz.sZoneAbbr as TZAbbr,
		ss.fn_LocationTime(GETDATE(),opc.iTZID,0) AS DateStampLocalized,
		dbo.fnGetOrderDeliveryMinutes(opc.iOrderId,null) as DeliveryMinutes,
		opc.RouteId,
		opc.LOX,
		--0 as LOX,
		--rs.SequenceNumber
		SequenceNumber,
		opc.isServiceCall,
		(select count(i.iitemId)
		from ss.tblItem i
		join ss.tblEquipment e on e.iItemRef = i.iItemID
		join ss.tblProduct p on p.iPrimaryEquipRef = e.iEquipmentID
		join ss.tblOrderDetail od on od.iProductID = p.iProductID
		where iItemID in (243,244) and od.iOrderID=Opc.iOrderID) as isSpecialty,
		lu.sLast as sLastViewedByLastName,
		lu.sFirst as sLastViewedByFirstName,
		du.sPhnCell as DriverPhone,
		du.sPhnOffice as DriverOfficePhone


	FROM (
		SELECT *, SequenceNumber = ( SELECT MAX(SequenceNumber) FROM dbo.RouteStop rs1 (NOLOCK) WHERE rs1.OrderId = omd.iOrderID )
		FROM reports_bic.dbo.OrderManagementData omd
		WHERE
			( 
			   ( @DateType = 0 AND ( ( ss.fn_LocationTime(omd.dtScheduled,omd.iTZID,0) BETWEEN @StartDate AND @EndDate ) OR (@StartDate IS NULL AND @EndDate IS NULL) ) )
			OR ( @DateType IS NULL AND (((reports.ss.fn_LocationTime(omd.dtScheduled,omd.iTZID,0) BETWEEN @StartDate AND @EndDate )) OR (omd.dtDateStamp BETWEEN @StartDate AND @EndDate) OR (omd.dtCompleted BETWEEN @StartDate AND @EndDate )))
			OR ( @DateType > 0 )
			)
	) as opc
	join ss.tblAddress as a (NOLOCK) on opc.iAddressRef = a.iAddressID
	left join ss.tblUser as du (NOLOCK) on opc.iDriverID = du.iUserID
	left join ss.tblUser as lu (NOLOCK) on opc.sLastViewedBy = lu.sUser
	join ss.tblType as t (NOLOCK) on opc.cTypeID = t.cTypeID
	left join ss.tblUser as u (NOLOCK) on opc.iOrderedBy = u.iUserID --and opc.iClientID = u.iClientID
	left join ss.tblLookup as lORC (NOLOCK) on 'ORC' = lORC.sGroup and isnull(opc.cReason,'O') = lORC.sCode
	left join ss.tblStatus as s (NOLOCK) on Opc.cStatusID = s.cStatusID
	left join ss.tblQAAnswers as qa (NOLOCK) on opc.iOrderID = qa.iOrderID
	left join ss.tblOrderNotepad np (NOLOCK) on Opc.iOrderID = np.iOrderRef
	left join ss.tblTimeZone tz (NOLOCK) on tz.iTZID = opc.iTZID

	--left join (
	--	SELECT rs1.OrderId, MAX(rs1.SequenceNumber) AS SequenceNumber 
	--	FROM dbo.RouteStop rs1 (NOLOCK)
	--	--JOIN @Orders o1 ON o1.iOrderId = rs1.OrderId
	--	WHERE rs1.OrderId IN ( SELECT DISTINCT iOrderId FROM @Orders )
	--	GROUP BY rs1.OrderId
	--) rs ON rs.OrderId = opc.iOrderid
	ORDER BY 
		CASE 	WHEN @SortBy = 'iOrderID' THEN right('0000000000000000000000000' + CONVERT(varchar(25), Opc.iOrderID),25)
				WHEN @SortBy = 'cTypeID' THEN Opc.cTypeID
				WHEN @SortBy = 'szStatus' THEN s.szStatus
				WHEN @SortBy = 'dtDateStamp' THEN CONVERT(varchar(25), Opc.dtDateStamp, 120)
				WHEN @SortBy = 'dtScheduled' THEN CONVERT(varchar(25), Opc.dtScheduled, 120)
				WHEN @SortBy = 'dtComplete' THEN CONVERT(varchar(25), Opc.dtCompleted, 120)
				WHEN @SortBy = 'szFullName' THEN oPc.szFullName
				WHEN @SortBy = 'szCity' THEN a.szCity
				WHEN @SortBy = 'szZip' THEN a.szZip
				WHEN @SortBy = 'szPhone1' THEN oPc.szPhone1
				WHEN @SortBy = 'szContactName' THEN oPc.szContactName
				WHEN @SortBy = 'szSubmitter' THEN u.sFirst
				WHEN @SortBy = 'szCompanyName' THEN opC.szCompanyName
				WHEN @SortBy = 'Driver' THEN du.sFirst
				WHEN @SortBy = 'iRouteNumber' THEN convert(varchar(25), ISNULL(SequenceNumber,Opc.iRouteNumber))
				WHEN @SortBy = 'blnAddOnStop' THEN CONVERT(char(1), Opc.blnAddOnStop)
				ELSE right('0000000000000000000000000' + CONVERT(varchar(25), Opc.iOrderID),25)
	


END

END
GO
