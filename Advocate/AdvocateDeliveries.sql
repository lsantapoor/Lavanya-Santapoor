USE REPORTS
Declare @iHOS as int, @YYYY int, @MM int, @Span int
DECLARE @iSiteRef int, @iDMEID int
DECLARE @iTZRef int
DECLARE @iOrderID int= null
SELECT @iSiteRef = p.iSiteRef FROM ss.tblOrder o (NOLOCK) JOIN ss.tblPatient p (NOLOCK) ON p.iPatientID = o.iPatientID WHERE o.iOrderID = @iOrderID

SET @iTZRef = ss.fn_GetTimeZone(null,@iSiteRef,null)

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
 IF OBJECT_ID('reports_bic.[dbo].[AdvocateDeliveries]', 'U') IS NOT NULL 
  DROP TABLE reports_bic.[dbo].[AdvocateDeliveries]; 

CREATE TABLE reports_bic.[dbo].[AdvocateDeliveries](
	[OrderID] [int] NOT NULL,
	[PatientID] [int] NOT NULL,
	[DMEID] [int] NULL,
	[cStatusID] [char](3) NOT NULL,
	[szStatus] [varchar](16) NOT NULL,
	[cTypeID] [char](3) NOT NULL,
	[szType] [varchar](16) NOT NULL,
	[DateStamp] [date] NULL,
	[UserName] [varchar](128) NOT NULL,
	[vcGUID] [varchar](64) NULL,
	[ContactName] [varchar](128) NULL,
	[Phone1] [varchar](20) NULL,
	[Phone2] [varchar](20) NULL,
	[PATIENT] [varchar](130) NOT NULL,
	[Address1] [varchar](128) NOT NULL,
	[Address2] [varchar](128) NULL,
	[City] [varchar](64) NULL,
	[State] [varchar](2) NULL,
	[Zip] [varchar](10) NULL,
	[ClientID] [int] NOT NULL,
	[SiteRef] [int] NULL,
	[Incident] [bit] NOT NULL,
	[CompletionActionId] [int] NULL,
	[IsRedelivery] [bit] NOT NULL,
	[IsServiceCall] [bit] NOT NULL,
	[Priority] [bit] NULL,
	[ScheduleStart] [date] NULL,
	[ScheduleEnd] [date] NULL,
	[TZAbbr] [varchar](10) NULL,
	[DeliveryMinutes] [numeric](9, 2) NULL
) ON [PRIMARY]


-- Get all orders for Advocate--

insert into reports_bic.[dbo].[AdvocateDeliveries]
SELECT	o.iOrderID,
		o.iPatientID,
		o.iDMEID,
		o.cStatusID,
		s.szStatus,
		o.cTypeID,
		t.szType,
--o.iReferenceOrderID,
		ss.fn_LocationTime(o.dtDateStamp,@iTZRef,0) as 'DateStamp',
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
		ss.fn_LocationTime(o.dtScheduled,@iTZRef,0) as ScheduleStart,
		ss.fn_LocationTime(o.ScheduleEnd,@iTZRef,0) as ScheduleEnd,
		tz.sZoneAbbr as TZAbbr,
		( SELECT dbo.fnGetOrderDeliveryMinutes(@iOrderid,NULL) ) as DeliveryMinutes
	FROM	ss.tblOrder o (NOLOCK)
	JOIN	ss.tblStatus s (NOLOCK)		ON	s.cStatusID = o.cStatusID
	JOIN	ss.tblType t (NOLOCK)		ON	t.cTypeID = o.cTypeID
	JOIN	ss.tblPatient p (NOLOCK)	ON	o.iPatientID = p.iPatientID
	JOIN	ss.tblAddress a (NOLOCK)	ON	o.iAddressRef = a.iAddressID
	join	ss.tblUser u (NOLOCK)		ON	o.iOrderedBy = u.iUserID  
	LEFT JOIN ss.tblTimeZone tz (NOLOCK) on tz.iTZID = @iTZRef
	left join reports.ss.tblLocation w on p.iClientRef=w.iLocationid where  w.iCompanyref=1640 and o.dtcompleted between @StartDate and @EndDate 
	and o.cstatusID='D' 
	--and DATEDIFF(hour,dtxScheduled,dtxCompleted)>48
	

		 --Below code emails the report to the recipients--
 Declare @query nvarchar(max);
    Set @query = 'select * from reports_bic.[dbo].[AdvocateDeliveries]';

 Execute msdb.dbo.sp_send_dbmail
        @profile_name = 'StateServ Reports'
     , @recipients = 'qcoleman@stateserv.com;fred.newman@advocatehealth.com' 
	 ,@copy_recipients = 'lsantapoor@stateserv.com'
      , @subject = 'Advocate Deliveries'
      , @body = 'Hi,
	  
	  Please find the monthly report attached.

	  Let me know in case of any concerns.

	  Have a nice day.
	  
	  Thanks,
	  Lavanya'
      , @query = @query
      , @query_result_separator='	' -- tab
      , @query_result_header = 1
      , @attach_query_result_as_file = 1
      , @query_attachment_filename = 'Deliveries Monthly.csv'
	  ,@query_result_no_padding=1 --trim
	 ,@query_result_width = 32767
	