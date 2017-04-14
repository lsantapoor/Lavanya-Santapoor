USE [reports]
GO


DECLARE @DmeID int
Declare @startDate as date,@EndDate as date

---Below code is to fetch the date for the first and last day of previous week--

set @StartDate = DATEADD(wk, -1, DATEADD(DAY, 1-DATEPART(WEEKDAY, GETDATE()), DATEDIFF(dd, 0, GETDATE()))) --first day previous week
set @EndDate = DATEADD(wk, 0, DATEADD(DAY, 0-DATEPART(WEEKDAY, GETDATE()), DATEDIFF(dd, 0, GETDATE()))) --last day previous week

-- TODO: Set parameter values here.

--set @DmeID=2


IF OBJECT_ID('reports_bic.dbo.dme_sorted_WKLY', 'U') IS NOT NULL 
  DROP TABLE reports_bic.dbo.dme_sorted_WKLY; 

IF OBJECT_ID('reports_bic.dbo.ReconcilePastDueWeekly', 'U') IS NOT NULL 
  DROP TABLE  reports_bic.dbo.ReconcilePastDueWeekly; 

 CREATE TABLE reports_bic.dbo.ReconcilePastDueWeekly(
	[type] [varchar](10) NOT NULL,
	[CompanyName] [varchar](64) NULL,
	[sName] [varchar](64) NULL,
	[sUser] [varchar](192) NOT NULL,
	[sFull] [varchar](128) NOT NULL,
	[OrderNumber] [int] NOT NULL,
	[DateReconciled] [date] NOT NULL,
	[OrderType] [varchar](8) NOT NULL,
	[Reason] [varchar](32) NOT NULL,
	[Warehouse] [varchar](64) NULL
	) ON [PRIMARY]
	

Declare @DMECount as int , @DME_step as int ,@DME as int, @DME_ID as int,@DME_SEQ_NO as int

select distinct(dmeid) into reports_bic.dbo.dme_sorted_WKLY from reports.ss.vBudget order by dmeid ASC
select @DMEcount= count(*) from reports_bic.dbo.dme_sorted_WKLY

print @DMEcount

set @DME_step=1

--while (@DME_step <= @DMEcount)

while (@DME_step <= 3)
begin

select @DMEID= min(dmeid) from reports_bic.dbo.dme_sorted_WKLY -- read min DME id from the list 
-----------
----your coode starts here
print @DmeID



	insert into reports_bic.dbo.ReconcilePastDueWeekly
	select 
		'Reconciled' AS type, 
		hos.CompanyName, 
		hos.sName, 
		u.sUser, 
		u.sFull, 
		oh.iOrderRef AS OrderNumber, 
		oh.dAction AS DateReconciled,
		case o.cTypeID
			when 'D' then 'Delivery'
			when 'P' then 'Pick Up'
			else 'Unknown'
		end as OrderType,
		ISNULL(orc.sName,'') as Reason,
		dme.sName AS Warehouse
	from ss.tblOrderHistory oh
	join ss.tblorder o on o.iOrderID = oh.iOrderRef
	join ss.tblPatient p on p.iPatientID = o.iPatientID
	join ss.vBudget b on b.iSiteRef = p.iSiteRef and b.iClientRef = p.iClientRef
	join ss.vCompanyLocation hos on hos.ilocationid = b.iclientref
	join ss.tbluser u on u.iuserid = oh.iUserRef
	join ss.tblLocation dme on dme.iLocationID = b.iSiteRef
	left join ss.tblLookup orc on orc.sCode = o.cReason and orc.sGroup = 'ORC'
	where b.DMEID = @dmeID and o.iorderedby <> 1286
	and o.dtDateStamp >=  @StartDate AND o.dtDateStamp <= @EndDate
	and oh.cAction = 'Rcd'

	---your code ends here----

delete from reports_bic.dbo.dme_sorted_WKLY where dmeid=@DMEId

set @DME_step = @DME_step +1
end

-- Below code is to send data by email to the recipients--

 Declare @query nvarchar(max);
    Set @query = 'select * from reports_bic.dbo.ReconcilePastDueWeekly';

 Execute msdb.dbo.sp_send_dbmail
        @profile_name = 'DMETrack Reports'
      , @recipients = 'CYeretzian@stateserv.com;croode@stateserv.com;kkahl@stateserv.com;SiteManagers@stateserv.com' 
	 ,@copy_recipients = 'lsantapoor@stateserv.com'
      , @subject = 'Reconcile Past Due Weekly'
      , @body = 'Hi,
	  
	  Please find the Weekly Reconcile Past Due Report attached.

	  Let me know in case of any concerns.

	  Have a nice day.
	  
	  Thanks,
	  Lavanya'
      , @query = @query
      , @query_result_separator='	' -- tab
      , @query_result_header = 1
      , @attach_query_result_as_file = 1
      , @query_attachment_filename = 'Reconcile Past Due Weekly.csv'
	  ,@query_result_no_padding=1 --trim
	 ,@query_result_width = 32767