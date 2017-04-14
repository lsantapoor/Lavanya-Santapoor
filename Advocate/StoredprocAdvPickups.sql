-- ================================================
-- Template generated from Template Explorer using:
-- Create Procedure (New Menu).SQL
--
-- Use the Specify Values for Template Parameters 
-- command (Ctrl-Shift-M) to fill in the parameter 
-- values below.
--
-- This block of comments will not be included in
-- the definition of the procedure.
-- ================================================
USE [reports_bic]
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Lavanya Santapoor
-- Create date: 2017-02-27
-- Description:	This is used to pull all the pickups in the past 20 days which were completed within 48 hours. 
-- =============================================
CREATE PROCEDURE [dbo].[AdvocatePickupsProc]

AS
BEGIN

Declare @iHOS as int, @YYYY int, @MM int, @Span int
DECLARE @iSiteRef int, @iDMEID int
DECLARE @iTZRef int
DECLARE @iOrderID int= null
SELECT @iSiteRef = p.iSiteRef FROM reports.ss.tblOrder o (NOLOCK) JOIN reports.ss.tblPatient p (NOLOCK) ON p.iPatientID = o.iPatientID WHERE o.iOrderID = @iOrderID

SET @iTZRef = reports.ss.fn_GetTimeZone(null,@iSiteRef,null)

-- Set time span for pulling orders--
Declare @startDate as datetime,@EndDate as datetime
set @StartDate = DATEADD(mm, DATEDIFF(mm, 0, GETDATE()) - 1, 0)
set @EndDate = CONVERT(VARCHAR(25),DATEADD(dd,-(DAY(GETDATE())),GETDATE()),101)
print @StartDate
print @EndDate

--Declare the DME ID of Advocate--
--set @iDMEID= 1639  --(Advocate DME ID)
--print @iDMEID
--Create a permanent table to input data for every 20 days--
 IF OBJECT_ID('reports_bic.[dbo].[AdvocatePickups]', 'U') IS NOT NULL 
  DROP TABLE reports_bic.[dbo].[AdvocatePickups]; 

CREATE TABLE reports_bic.[dbo].[AdvocatePickups](
	[iOrderID] [int] NOT NULL,
	[iPatientID] [int] NOT NULL,
	[iDMEID] [int] NULL,
	[cStatusID] [char](3) NOT NULL,
	[szStatus] [varchar](16) NOT NULL,
	[cTypeID] [char](3) NOT NULL,
	[szType] [varchar](16) NOT NULL,
	[DateStamp] [datetime] NULL,
	[vcUserName] [varchar](128) NOT NULL,
	[vcGUID] [varchar](64) NULL,
	[szContactName] [varchar](128) NULL,
	[szPhone1] [varchar](20) NULL,
	[szPhone2] [varchar](20) NULL,
	[PATIENT] [varchar](130) NOT NULL,
	[szAddress1] [varchar](128) NOT NULL,
	[szAddress2] [varchar](128) NULL,
	[szCity] [varchar](64) NULL,
	[szState] [varchar](2) NULL,
	[szZip] [varchar](10) NULL,
	[iClientID] [int] NOT NULL,
	[iSiteRef] [int] NULL,
	[blnIncident] [bit] NOT NULL,
	[CompletionActionId] [int] NULL,
	[IsRedelivery] [bit] NOT NULL,
	[IsServiceCall] [bit] NOT NULL,
	[Priority] [bit] NULL,
	[ScheduleStart] [datetime] NULL,
	[ScheduleEnd] [datetime] NULL,
	[TZAbbr] [varchar](10) NULL,
	[DeliveryMinutes] [numeric](9, 2) NULL
) ON [PRIMARY]


-- Get all orders for Advocate--

insert into reports_bic.[dbo].[AdvocatePickups]
SELECT	o.iOrderID,
		o.iPatientID,
		o.iDMEID,
		o.cStatusID,
		s.szStatus,
		o.cTypeID,
		t.szType,
--o.iReferenceOrderID,
		reports.ss.fn_LocationTime(o.dtDateStamp,@iTZRef,0) as 'DateStamp',
		u.sFull as vcUserName,
		o.vcGUID,
		o.szContactName,
		o.szPhone1,
		o.szPhone2,
		p.szLastName + ', ' + p.szFirstName AS PATIENT,
		a.szAddress1,
		a.szAddress2,
		a.szCity,
		a.szState,
		a.szZip,
		p.iClientRef as iClientID,
		p.iSiteRef,
		o.blnIncident,
		o.CompletionActionId,
		o.IsRedelivery,
		o.IsServiceCall,
		o.Priority,
		reports.ss.fn_LocationTime(o.dtScheduled,@iTZRef,0) as ScheduleStart,
		reports.ss.fn_LocationTime(o.ScheduleEnd,@iTZRef,0) as ScheduleEnd,
		tz.sZoneAbbr as TZAbbr,
		( SELECT reports.dbo.fnGetOrderDeliveryMinutes(@iOrderid,NULL) ) as DeliveryMinutes
	FROM	reports.ss.tblOrder o (NOLOCK)
	JOIN	reports.ss.tblStatus s (NOLOCK)		ON	s.cStatusID = o.cStatusID
	JOIN	reports.ss.tblType t (NOLOCK)		ON	t.cTypeID = o.cTypeID
	JOIN	reports.ss.tblPatient p (NOLOCK)	ON	o.iPatientID = p.iPatientID
	JOIN	reports.ss.tblAddress a (NOLOCK)	ON	o.iAddressRef = a.iAddressID
	join	reports.ss.tblUser u (NOLOCK)		ON	o.iOrderedBy = u.iUserID  
	LEFT JOIN reports.ss.tblTimeZone tz (NOLOCK) on tz.iTZID = @iTZRef
	left join reports.ss.tblLocation w on p.iClientRef=w.iLocationid where iDMEID in (1639,336,1640) and o.dtcompleted between @StartDate and @EndDate 
	and o.cstatusID='P' 
	and DATEDIFF(hour,ScheduleEnd,dtCompleted)>48
	END
	GO