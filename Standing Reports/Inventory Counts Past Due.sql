USE [reports]
GO
/****** Object:  StoredProcedure [ss].[sp_Report_Inv_CountsPastDue]    Script Date: 8/3/2016 7:11:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*
-=[Version Infomration]=-
Name        Date     VER Update
I. Erickson 20100604 2.0 Update for Version 2.0 DME Track network backend.
I. Erickson 20120420 2.1 Added case statement to avoid divid by zero result for network accounts.

-=[Called By]=-
4.0 Reporting

-=[Example Calls]=-
Exec ss.sp_Report_Inv_CountsPastDue

-=[Function]=-
Gets Inventory Passed Due by Site.
*/
/*	Declare @YYYY as char(4)
	Declare @MM as char(2)
	Declare @DD as char(2)
	Declare @X as datetime
	select @X = dateadd(d,-1,max(dtTimeStamp)) from ss.tblInventoryDaily
	set @YYYY = year(@X)
	set @MM = right('00' + ltrim(str(month(@X))),2)
	set @DD = right('00' + ltrim(str(day(@X))),2)*/
	
	Declare @xCnt as int
		Declare @startDate as datetime,@EndDate as datetime

--Below code is to fetch the date for the first(sunday) and last day(Saturday) of previous week--

set @StartDate = DATEADD(wk, -1, DATEADD(DAY, 1-DATEPART(WEEKDAY, GETDATE()), DATEDIFF(dd, 0, GETDATE()))) --first day previous week
set @EndDate = DATEADD(wk, 0, DATEADD(DAY, 0-DATEPART(WEEKDAY, GETDATE()), DATEDIFF(dd, 0, GETDATE()))) --last day previous week

print @StartDate
print @EndDate

IF OBJECT_ID('reports_bic.dbo.InventoryPastCountDue_WKLY', 'U') IS NOT NULL 
  DROP TABLE  reports_bic.dbo.InventoryPastCountDue_WKLY; 

	CREATE TABLE reports_bic.dbo.InventoryPastCountDue_WKLY(
	[SID] [int] NOT NULL,
	[Site] [varchar](64) NULL,
	[iPastDue] [int] NULL,
	[iTracking] [int] NULL,
	[iTotalItems] [int] NULL,
	[PercentPastDue] [numeric](4, 2) NULL,
	[PercentTracking] [numeric](4, 2) NULL)
	ON [PRIMARY]
	
	insert into reports_bic.dbo.InventoryPastCountDue_WKLY
	
	select y.iSID as SID, s.sName as Site, y.iPastDue, y.iTracking, y.xCnt as iTotalItems,
		--cast((y.iPastDue / cast(y.iTracking as numeric(9,5))) * 100 as numeric(4,2)) as PercentPastDue,
		case when y.iTracking = 0 then 0 else cast((y.iPastDue / cast(y.iTracking as numeric(9,5))) * 100 as numeric(4,2)) end as PercentPastDue,
		cast((y.iTracking / cast(y.xCnt as numeric(9,5))) * 100 as numeric(4,2)) as PercentTracking 
	from (
		select iSiteRef as iSID, sum(iPastDue) as iPastDue, sum(iTracking) as iTracking, sum(1) as xCnt
		from (
			--Get Past Due Number
			select iSiteRef, case when iCountDue < 0 then 1 else 0 end as iPastDue, 
			case when isnull(iInventoryRef,0) > 0 then 1 else 0 end as iTracking
			from ss.tblInventoryDaily
	--		where cYYYY = @YYYY and cMM = @MM and cDD = @DD
	where dtTimeStamp between @StartDate and @EndDate
		) as x
		group by iSiteRef
	) as y
	left join ss.tblLocation as s on s.iLocationID = y.iSID and s.cType = 'S'
	Order by Site

	-- Below code is to send data by email to the recipients--

 Declare @query nvarchar(max);
    Set @query = 'select * from reports_bic.[dbo].[InventoryPastCountDue_WKLY]';

 Execute msdb.dbo.sp_send_dbmail
        @profile_name = 'DMETrack Reports'
      , @recipients = 'lsantapoor@stateserv.com;lavanya.santapoor@gmail.com' 
	 --,@copy_recipients = 'lavanya.santapoor@gmail.com'
      , @subject = 'Inventory Reports Past Due Weekly'
      , @body = 'Hi,
	  
	  Please find the weekly Inventory Report attached.

	  Let me know in case of any concerns.

	  Have a nice day.
	  
	  Thanks,
	  Lavanya'
      , @query = @query
      , @query_result_separator='	' -- tab
      , @query_result_header = 1
      , @attach_query_result_as_file = 1
      , @query_attachment_filename = 'Inventory Counts Past Due.csv'
	  ,@query_result_no_padding=1 --trim
	 ,@query_result_width = 32767