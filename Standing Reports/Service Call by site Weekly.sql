USE [reports]
GO

Declare @CompanyId int,	
	@HospiceId int = null

Declare @startDate as date,@EndDate as date

---Below code is to fetch the date for the first and last day of previous month--

set @StartDate = DATEADD(wk, -1, DATEADD(DAY, 1-DATEPART(WEEKDAY, GETDATE()), DATEDIFF(dd, 0, GETDATE()))) --first day previous week
set @EndDate = DATEADD(wk, 0, DATEADD(DAY, 0-DATEPART(WEEKDAY, GETDATE()), DATEDIFF(dd, 0, GETDATE()))) --last day previous week

-- TODO: Set parameter values here.

IF OBJECT_ID('reports_bic.dbo.ServiceCallOrdersWeekly', 'U') IS NOT NULL 
  DROP TABLE  reports_bic.dbo.ServiceCallOrdersWeekly; 
  
  
  CREATE TABLE reports_bic.dbo.ServiceCallOrdersWeekly (
		OrderId INT,
		OrderDate date,
		DeliveryDate date,
		PatientId INT,
		AddressId INT,
		ReasonCode varChar(2)
	)ON [PRIMARY]

	INSERT INTO reports_bic.dbo.ServiceCallOrdersWeekly

	SELECT DISTINCT o.iOrderID AS OrderId, o.dtDateStamp AS OrderDate, o.dtCompleted AS DeliveryDate, o.iPatientID AS PatientId, iAddressRef AS AddressId, cReason AS ReasonCode
	FROM ss.tblOrder o
	JOIN ss.tblOrderDetail od ON od.iOrderID = o.iOrderID
	JOIN OrderDetailServiceCall s ON s.OrderDetailId = od.iOrderDetailID
	WHERE 1=1
	AND o.dtDateStamp between @startDate and @EndDate
	

	SELECT lc.sName as HospiceName,
		lc.iLocationID as HospiceId,
		o.OrderID AS OrderId,
		(p.szLastName + ', ' + p.szFirstName) as PatientName,
		a.szAddress1 AS [Address],
		a.szCity AS City,
		a.szState AS [State],
		a.szZip AS ZipCode,
		r.Name AS ReasonForDelivery,
		o.OrderDate,
		o.DeliveryDate,			
		STUFF(
				(SELECT ', ' + ont.sNote
				FROM ss.tblOrderNote ont
				where ont.iOrderRef = o.OrderId
				FOR XML PATH (''))
				, 1, 1, '')  AS OrderNotes,
		tp.szProductName AS ProductName
	FROM OrderDetailServiceCall s
	INNER JOIN ss.tblOrderDetail d on s.OrderDetailId = d.iOrderDetailID
	INNER JOIN reports_bic.dbo.ServiceCallOrdersWeekly o on o.OrderID = d.iOrderID
	INNER JOIN ss.tblPatient p on o.PatientId = p.iPatientId
	INNER JOIN ss.tblLocation dme on p.iSiteRef = dme.iLocationID
	INNER JOIN ss.tblLocation lc on p.iClientRef = lc.iLocationID
	INNER JOIN ss.tblAddress a on o.AddressId = a.iAddressID	
	INNER JOIN ReasonForDelivery r ON o.ReasonCode = r.Code
	INNER JOIN ss.tblProduct tp ON d.iProductID = tp.iProductID
	WHERE dme.iCompanyRef = @companyid AND
			(@HospiceId is NULL OR lc.iLocationID = @HospiceId)
	ORDER BY o.OrderDate


--This code is to fetch data for Driver Accuracy Weekly and email it to the recipients--

 Declare @query nvarchar(max);
    Set @query = 'select * from reports_bic.dbo.ServiceCallOrdersWeekly';

 Execute msdb.dbo.sp_send_dbmail
        @profile_name = 'DMETrack Reports'
      , @recipients = 'lsantapoor@stateserv.com;lavanya.santapoor@gmail.com' 
	 --,@copy_recipients = 'lavanya.santapoor@gmail.com'
      , @subject = 'Service Calls Weekly Report'
      , @body = 'Hi,
	  
	  Please find the Weekly Service Calls Report attached.

	  Let me know in case of any concerns.

	  Have a nice day.
	  
	  Thanks,
	  Lavanya'
      , @query = @query
      , @query_result_separator='	' -- tab
      , @query_result_header = 1
      , @attach_query_result_as_file = 1
      , @query_attachment_filename = 'Service Calls Weekly.csv'
	  ,@query_result_no_padding=1 --trim
	 ,@query_result_width = 32767