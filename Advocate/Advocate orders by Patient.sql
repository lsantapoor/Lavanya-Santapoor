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
 IF OBJECT_ID('reports_bic.[dbo].[AdvocatePatientInfo]', 'U') IS NOT NULL 
  DROP TABLE reports_bic.[dbo].[AdvocatePatientInfo]; 

CREATE TABLE reports_bic.[dbo].[AdvocatePatientInfo](
	[PATIENT] [varchar](130) NOT NULL,
	OrderCount int,
) ON [PRIMARY]


-- Get all orders for Advocate--

insert into reports_bic.[dbo].[AdvocatePatientInfo]
SELECT
		p.szLastName + ', ' + p.szFirstName AS PATIENT, count(*) as OrderCount
	FROM	ss.tblOrder o (NOLOCK)
	JOIN	ss.tblStatus s (NOLOCK)		ON	s.cStatusID = o.cStatusID
	JOIN	ss.tblType t (NOLOCK)		ON	t.cTypeID = o.cTypeID
	JOIN	ss.tblPatient p (NOLOCK)	ON	o.iPatientID = p.iPatientID
	JOIN	ss.tblAddress a (NOLOCK)	ON	o.iAddressRef = a.iAddressID
	join	ss.tblUser u (NOLOCK)		ON	o.iOrderedBy = u.iUserID  
	LEFT JOIN ss.tblTimeZone tz (NOLOCK) on tz.iTZID = @iTZRef
	left join reports.ss.tblLocation w on p.iClientRef=w.iLocationid where  w.iCompanyref=1640 and o.dtcompleted between @StartDate and @EndDate and o.cstatusID='D' 
	group by p.szLastName + ', ' + p.szFirstName;
	
		 --Below code emails the report to the recipients--
 Declare @query nvarchar(max);
    Set @query = 'select * from reports_bic.[dbo].[AdvocatePatientInfo]';

 Execute msdb.dbo.sp_send_dbmail
        @profile_name = 'StateServ Reports'
    , @recipients = 'qcoleman@stateserv.com;fred.newman@advocatehealth.com' 
	 ,@copy_recipients = 'lsantapoor@stateserv.com'
      , @subject = 'Advocate orders by Patient'
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
      , @query_attachment_filename = 'Orders by patient monthly.csv'
	  ,@query_result_no_padding=1 --trim
	 ,@query_result_width = 32767
	