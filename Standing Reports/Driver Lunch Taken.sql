/****** Script for SelectTopNRows command from SSMS  ******/


-- TODO: Set parameter values here.
Declare @startDate as date,@EndDate as date


--Below code is to fetch the date for the first(sunday) and last day(Saturday) of previous week--

set @StartDate = DATEADD(wk, -1, DATEADD(DAY, 1-DATEPART(WEEKDAY, GETDATE()), DATEDIFF(dd, 0, GETDATE()))) --first day previous week
set @EndDate = DATEADD(wk, 0, DATEADD(DAY, 0-DATEPART(WEEKDAY, GETDATE()), DATEDIFF(dd, 0, GETDATE()))) --last day previous week

print @StartDate
Print @EndDate
IF OBJECT_ID('reports_bic.dbo.DriverLunchWeekly', 'U') IS NOT NULL 
  DROP TABLE reports_bic.dbo.DriverLunchWeekly; 

SELECT  [ShiftID]
      ,[DMEUserID]
      ,[DateTimeIn]
      ,[DateTimeOut]
      ,[MileageStart]
      ,[MileageEnd]
      ,[IpIn]
      ,[IpOut]
      ,[Notes]
      ,[TruckNumber]
      ,[TookLunch] into reports_bic.dbo.DriverLunchWeekly 
  FROM [reports].[ss].[tblDMEDriver] where  [DateTimeIn] between @StartDate and @EndDate;

  --Below code emails the report to the recipients--
 Declare @query nvarchar(max);
    Set @query = 'select * from reports_bic.dbo.DriverLunchWeekly ';

 Execute msdb.dbo.sp_send_dbmail
        @profile_name = 'DMETrack Reports'
      , @recipients = 'CYeretzian@stateserv.com;kkahl@stateserv.com;SiteManagers@stateserv.com' 
	 ,@copy_recipients = 'lsantapoor@stateserv.com'
      , @subject = 'Driver Lunch Time Weekly Report'
      , @body = 'Hi,
	  
	  Please find the monthly Driver lunch time Report attached.

	  Let me know in case of any concerns.

	  Have a nice day.
	  
	  Thanks,
	  Lavanya'
      , @query = @query
      , @query_result_separator='	' -- tab
      , @query_result_header = 1
      , @attach_query_result_as_file = 1
      , @query_attachment_filename = 'Driver Lunch Time Weekly.csv'
	  ,@query_result_no_padding=1 --trim
	 ,@query_result_width = 32767