use reports
declare @iDME as int, @iLimitDataFlag as int, @iReportSum as int
set @iDME = 2
set @iLimitDataFlag = 0
--set @iLimitDataFlag = 1
/*
	version 
	1.4 erickson 20150810 Updated to use reports dev calls
*/
Declare @startDate as datetime,@EndDate as datetime

---Below code is to fetch the date for the first and last day of previous month--

set @StartDate = DATEADD(wk, -1, DATEADD(DAY, 1-DATEPART(WEEKDAY, GETDATE()), DATEDIFF(dd, 0, GETDATE()))) --first day previous week
set @EndDate = DATEADD(wk, 0, DATEADD(DAY, 0-DATEPART(WEEKDAY, GETDATE()), DATEDIFF(dd, 0, GETDATE()))) --last day previous week

print @StartDate
print @EndDate

/*------------------------------------*\
|  Bgn Standard Reporting Window Call  |
\*------------------------------------*/

--declare @cWindow as char(1), @iOffset as int, @iSummaryFlag as int
--set @cWindow = 'M' --'Y'early, 'Q'uarterly, 'M'onthly, 'W'eekly (Su-Sa), 'I'SO Week (Mo-Su), 'D'aily, 'B'i-Monthly
--set @iOffset = -0 --0 for Last (day, week, etc) Negative for older reports, +1 is current time span
--set @iSummaryFlag = 0 --1 will force a 13 x window view for summary data lines.1 is current time span
--set @iSummaryFlag = 1 --1 will force a 13 x window view for summary data lines.1 is current time span
--set @cWindow = 'M' --'Y'early, 'Q'uarterly, 'M'onthly, 'W'eekly (Su-Sa), 'I'SO Week (Mo-Su), 'D'aily, 'B'i-Monthly

--select 'All values returned'
--select * from ss.fn_Report_DateRange(@cWindow,@iOffset,@iSummaryFlag,default,default) --Window, Offset, Summary, Size, Date

select 'Get what is Needed'
declare @dOldest as datetime, @sTitle as varchar(32), @sLabel as char(10), @sInfo as varchar(64), @sVer varchar(8)

select @sTitle as Title, @startDate as dStart, @EndDate as dEnd, @dOldest as dOldest, @sLabel as dLabel,
    @sInfo as info, @sVer as Ver

--select @dS = dS, @dE = dE, @sTitle = sTitle, @sLabel = sLblEnd, @dOldest = dOldest, @sInfo = sInfo, @sVer = sVer
--from reports_dev.dbo.fn_Report_DateRange(@cWindow,@iOffset,@iSummaryFlag,default,default) --Window, Offset, Summary, Size, Date

--select @sTitle as Title, @dS as dStart, @dE as dEnd, @dOldest as dOldest, @sLabel as dLabel,
  --  @sInfo as info, @sVer as Ver

/*------------------------------------*\
|  End Standard Reporting Window Call  |
\*------------------------------------*/

IF OBJECT_ID('reports_bic.[dbo].[ServicecallsbySiteWeekly]', 'U') IS NOT NULL 
  DROP TABLE  reports_bic.[dbo].[ServicecallsbySiteWeekly] ; 

CREATE TABLE reports_bic.[dbo].[ServicecallsbySiteWeekly](
	[DME Site] [varchar](128) NOT NULL,
	[HOS Client] [varchar](128) NOT NULL,
	[Date Completed] [date] NOT NULL,
	[Order ID] [int] NOT NULL,
	[Driver] [varchar](64) NULL,
	[Ordered By] [varchar](64) NULL,
	[User Type] [varchar](16) NULL,
	[Order Reason] [varchar](24) NULL,
	[Location] [varchar](3) NULL,
	[Service Call] [varchar](1) NOT NULL,
	[Beds] [varchar](1) NOT NULL,
	[Conc] [varchar](1) NOT NULL,
	[LAL] [varchar](1) NOT NULL,
	[WC] [varchar](1) NOT NULL,
	[Other] [varchar](1) NOT NULL,
	[Notes] [varchar](8000) NULL,
	[Reason] [varchar](8000) NULL,
	[Resolution] [varchar](8000) NULL,
	[Customer Service Opportunity] [varchar](8000) NULL,
) ON [PRIMARY]


declare @tmp_OpsData as table (
	iSID int not null,
	sDMESite varchar(128) not null,
	sHOSClient varchar(128) not null,
	dCompleted datetime not null,
	iOID int not null,
	sDriver varchar(64),
	sOrderedBy varchar(64),
	sUserType varchar(16),
	sReason varchar(24),
	sLocation varchar(3),
	iServiceCall int not null,
	iCntBeds int not null,
	iCntConc int not null,
	iCntLAL  int not null,
	iCntWC   int not null,
	sNotes varchar(8000)
)

insert into @tmp_OpsData 
select  s.iLocationID as iSID,
		d.sAbbr + ': ' + s.sName as [DME Site],
		h.sAbbr + ': ' + c.sName as [HOS Client],
		isnull(o.dtCompleted,'') as [Date Completed],
		o.iOrderID as [Order ID],
		isnull(ud.sLast + ', ' + ud.sFirst,'') as [Driver],
		rtrim(uo.sLast + ', ' + uo.sFirst + ' ' + uo.cMiddle) as [Ordered By],
		isnull(pl.sName,'Unknown') as [User Type],
		r.sName as [Reason],
		isnull(a.szDeliveryLocation,'Unknown') as [Location],
		case when scc.iCntSC = 0 then 0 else 1 end as iCntSC,
		case when scc.iCntBeds = 0 then 0 else 1 end as iCntBeds,
		case when scc.iCntConc = 0 then 0 else 1 end as iCntConc,
		case when scc.iCntLAL  = 0 then 0 else 1 end as iCntLAL,
		case when scc.iCntWC   = 0 then 0 else 1 end as iCntWC,
		isnull(replace(replace(replace(onp.sFullNote,'<br />',''),'<br>',''),char(13) + char(10),''),'') as [Notes]
from ss.tblorder as o
left join ss.tblOrderNotepad as onp on o.iOrderID = onp.iOrderRef 
join ss.tblPatient as p on o.iPatientID = p.iPatientID
left join ss.tblLookup as r on o.cReason = r.sCode and sGroup = 'ORC'
join ss.tblAddress as a on p.iAddressRef = a.iAddressID
join ss.tblLocation as c on p.iClientRef = c.iLocationID
join ss.tblLocation as s on p.iSiteRef = s.iLocationID
join ss.tblCompany as d on s.iCompanyRef = d.iCompanyID
join ss.tblCompany as h on c.iCompanyRef = h.iCompanyID
left join ss.tblUser ud on o.iDriverID = ud.iUserID
left join ss.tblUser uo on o.iOrderedBy = uo.iUserID
left join dbo.UserLocation as ul on ul.Priority = 1 and ul.UserID = uo.iUserID 
left join (select distinct cPyL, sName from ss.tblPyramid_Levels) as pl on pl.cPyL = ul.cType 
join (

		select distinct c.iOrderID as iOID, sum(c.iCntServiceCall) as iCntSC, 
			SUM(c.iCntBeds) as iCntBeds, SUM(c.iCntConc) as iCntConc, SUM(c.iCntLAL) as iCntLAL, SUM(c.iCntWC) as iCntWC
		from (
			select o.iOrderID, 
				case when i.iCategoryRef = 234 then (
						case when i.sName like 'Service Call' then 1 else 0 end
					) else 0 end as iCntServiceCall,
				case when i.iCategoryRef in (130,132,272) then 1 else 0 end as iCntBeds,
				case when i.iCategoryRef in (166,167) then 1 else 0 end as iCntConc,
				case when i.iCategoryRef = 137 then 1 else 0 end as iCntLAL,
				case when i.iCategoryRef in (115,116,117,118,119) then 1 else 0 end as iCntWC
			from ss.tblOrder as o
			join ss.tblOrderDetail as od on o.iOrderID = od.iOrderID 
			join ss.tblProductEquip as pe on od.iProductID = pe.iProductRef 
			join ss.tblEquipment as e on pe.iEquipmentRef = e.iEquipmentID 
			join ss.tblItem as i on i.iItemID = e.iItemRef 
			where o.dtCompleted between @startDate and @EndDate
		) as c
		group by c.iOrderID
	
) as scc on scc.iOID = o.iOrderID 
where d.iCompanyID = @iDME
and o.dtCompleted between @startDate and @EndDate
and o.cTypeID in ('D','P')
and o.cStatusID in ('D','P')
order by [DME SITE], [HOS Client], o.dtCompleted

if @iLimitDataFlag = 0 begin
insert into reports_bic.[dbo].[ServicecallsbySiteWeekly]
select sDMESite, sHOSClient, dCompleted as DateCompleted, iOID as OrderID, sDriver as Driver, sOrderedBy as OrderedBy, sUserType as UserType, sReason as Reason, sLocation as Location,
	case when iServiceCall = 0 then 'N' else 'Y' end as cCntServiceCall,
	case when iCntBeds = 0 then 'N' else 'Y' end as cCntBeds,
	case when iCntConc = 0 then 'N' else 'Y' end as cCntConc,
	case when iCntLAL  = 0 then 'N' else 'Y' end as cCntLAL,
	case when iCntWC   = 0 then 'N' else 'Y' end as cCntWC,
	case when iCntBeds + iCntConc + iCntLAL + iCntWC = 0 then 'Y' else 'N' end as iCntOther,
	sNotes, '  ','  ','  '
from @tmp_OpsData 
end

-- Below code is to send data by email to the recipients--

declare @Test table (
[Serial Number] int,
[DME Site] varchar(8000) Null,
[Email ID] varchar (8000) Null
) 

insert into @Test values (1,'SSM: Las Vegas, NV','lsantapoor@stateserv.com')
insert into @Test values (2,'SSM: Tucson, AZ','lsantapoor@stateserv.com')
insert into @Test values (3,'SSM: Portland, OR','lsantapoor@stateserv.com')
insert into @Test values (4,'SSM: Denver, CO','lsantapoor@stateserv.com')
insert into @Test values (5,'SSM: San Antonio, TX','lsantapoor@stateserv.com')
insert into @Test values (6,'SSM: Dallas, TX','lsantapoor@stateserv.com')
insert into @Test values (7,'SSM: Albuquerque, NM','lsantapoor@stateserv.com')
insert into @Test values (8,'SSM: Leesburg, FL','lsantapoor@stateserv.com')
insert into @Test values (9,'SSM: Santa Fe, NM','lsantapoor@stateserv.com')
insert into @Test values (10,'SSM: Tempe, AZ','lsantapoor@stateserv.com')
insert into @Test values (11,'SSM: CO Springs, CO','lsantapoor@stateserv.com')
insert into @Test values (12,'SSM: Medford,OR','lsantapoor@stateserv.com')
insert into @Test values (13,'SSM: Miami, FL','lsantapoor@stateserv.com')
insert into @Test values (14,'SSM: Sarasota, FL','lsantapoor@stateserv.com')
insert into @Test values (15,'SSM: Birmingham, AL','lsantapoor@stateserv.com')
insert into @Test values (16,'SSM: Austin, TX','lsantapoor@stateserv.com')
insert into @Test values (17,'SSM: Naples, FL','lsantapoor@stateserv.com')
insert into @Test values (18,'SSM: Gadsden, AL','lsantapoor@stateserv.com')


Declare @DMESiteCount as int , @DMESite_step as int, @DMESite as varchar(8000) ,@DMEEmail as varchar(8000)

select @DMESitecount= count(*) from @Test
print @DMESitecount


set @DMESite_step=1

while (@DMESite_step <= @DMESitecount)
begin


select @DMESite=[DME Site] from @Test where [Serial Number] = @DMESite_step -- read DME Site Id from the list 
select @DMEEmail=[Email ID] from @Test where [Serial Number] = @DMESite_step -- read Email id of each DME Site Id
-----------
----your coode starts here
print @DMESite
print @DMEEmail

--select * from reports_bic.[dbo].[ServicecallsbySiteWeekly] where [DME Site] = @DMESite
--/*
 Declare @thequery nvarchar(max);
    Set @thequery = 'select * from reports_bic.[dbo].[ServicecallsbySiteWeekly] where [DME Site] = '+'"' + cast(@DMESite as nvarchar(max))+'"';
	print @thequery
Declare @email nvarchar(max)= cast(@DMEEmail as nvarchar(max));
Declare @sub varchar(max)
set @sub= 'Service Call Report by Site weekly - '+ cast(@DMESite as nvarchar(max)) + N' ' + N'- '  + CONVERT(VARCHAR(12),@startdate,107);
 Execute msdb.dbo.sp_send_dbmail
        @profile_name = 'DMETrack Reports'
      , @recipients = @email
	 --,@copy_recipients = 'lavanya.santapoor@gmail.com;'
      , @subject = @sub
      , @body = 'Hi,
	  
	  Please find the weekly Service Call Report attached.

	  Let me know in case of any concerns.

	  Have a nice day.
	  
	  Thanks,
	  Lavanya'
      , @query = @thequery
      , @query_result_separator='	' -- tab
      , @query_result_header = 1
      , @attach_query_result_as_file = 1
      , @query_attachment_filename = 'Service Calls by Site.csv'
	  ,@query_result_no_padding=1 --trim
	 ,@query_result_width = 32767
--*/	 
set @DMESite_step = @DMESite_step +1
end