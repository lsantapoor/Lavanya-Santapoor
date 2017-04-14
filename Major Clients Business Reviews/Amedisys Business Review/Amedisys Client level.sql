use reports
/*--------------------------------------------------------------------------*\
| QA Data for an SRM Report! 
| Pulls back all data by Client / Site Dyad
| Groups by Region
| Groups by National Level
\*--------------------------------------------------------------------------*/
--20140708 v1.2 Added Notes to query, fixed iHOS to load into @CIDs and use it now.
--20160313 v1.3 Added a filter on HOS and/or DME

--Check to see if below is populated in Prod yet?
--select 'I WAS LOADED?' as info, * from ss.tblLookup where sGroup = 'QAFT'

--=[Define what we are looking for]=--
Declare @iHOS as int, @iDME as int , @YYYY as int , @MM as int, @span int ,@loop_step int,@loopdate date

set @iHOS = 87 --Amedisys (201310,201303,201507,201509)


IF OBJECT_ID('reports_bic.dbo.AmedisysQANationalQuestions', 'U') IS NOT NULL 
  DROP TABLE reports_bic.dbo.AmedisysQANationalQuestions; 

create table reports_bic.dbo.AmedisysQANationalQuestions
( Question varchar(50) Not null,
  meet numeric(9,6) NULL,
  fail numeric(9,6),
  exceed numeric(9,6),
  smonth varchar(12)
  )

  
 IF OBJECT_ID('reports_bic.dbo.AmedisysQAregionalQuestions', 'U') IS NOT NULL 
  DROP TABLE reports_bic.dbo.AmedisysQAregionalQuestions; 

create table reports_bic.dbo.AmedisysQAregionalQuestions
( Question varchar(50) Not null,
  meet numeric(9,6) NULL,
  fail numeric(9,6),
  exceed numeric(9,6),
  [smonth] varchar(12),
  [region] varchar(8000)
  )
  
  
  IF OBJECT_ID('reports_bic.dbo.AmedisysQAClientQuestions', 'U') IS NOT NULL 
  DROP TABLE reports_bic.dbo.AmedisysQAClientQuestions; 

create table reports_bic.dbo.AmedisysQAClientQuestions
( Question varchar(50) Not null,
  meet numeric(9,6) NULL,
  fail numeric(9,6),
  exceed numeric(9,6),
  smonth varchar(12),
  Provider varchar(100),
  Client varchar(100)

  )

    IF OBJECT_ID('reports_bic.[dbo].[AmedisysFeedback]', 'U') IS NOT NULL 
  DROP TABLE reports_bic.[dbo].[AmedisysFeedback]; 
  
  CREATE TABLE reports_bic.[dbo].[AmedisysFeedback](
	[iOID] [int] NOT NULL,
	[sType] [varchar](32) NULL,
	[dGiven] varchar(12) NULL,
	[sFeedback] [varchar](8000) NULL,
	RegionName varchar(100) Null,
	Clientname varchar(100) NULL
) ON [PRIMARY]



  IF OBJECT_ID('reports_bic.dbo.TempAmedisysRegional', 'U') IS NOT NULL 
  DROP TABLE reports_bic.dbo.TempAmedisysRegional; 

create table  reports_bic.dbo.TempAmedisysRegional (
	[iHOS] [int] NULL,
	[iRgn] [int] NULL,
	[iTotal] [int] NULL,
	[iNoCnt] [int] NULL,
	[iOpOut] [int] NULL,
	[iNoEng] [int] NULL,
	[iAbort] [int] NULL,
	[iUsable] [int] NULL,
	[iDone] [int] NULL,
	[xQ1] [int] NULL,
	[iQ1y] [int] NULL,
	[iQ1n] [int] NULL,
	[pQ1] [numeric](9, 6) NULL,
	[xQ2] [int] NULL,
	[iQ2y] [int] NULL,
	[iQ2n] [int] NULL,
	[pQ2] [numeric](9, 6) NULL,
	[xQ4] [int] NULL,
	[iQ4m] [int] NULL,
	[iQ4x] [int] NULL,
	[iQ4f] [int] NULL,
	[pQ4m] [numeric](9, 6) NULL,
	[pQ4x] [numeric](9, 6) NULL,
	[pQ4f] [numeric](9, 6) NULL,
	[xQ5] [int] NULL,
	[iQ5m] [int] NULL,
	[iQ5x] [int] NULL,
	[iQ5f] [int] NULL,
	[pQ5m] [numeric](9, 6) NULL,
	[pQ5x] [numeric](9, 6) NULL,
	[pQ5f] [numeric](9, 6) NULL,
	[xQ6] [int] NULL,
	[iQ6m] [int] NULL,
	[iQ6x] [int] NULL,
	[iQ6f] [int] NULL,
	[pQ6m] [numeric](9, 6) NULL,
	[pQ6x] [numeric](9, 6) NULL,
	[pQ6f] [numeric](9, 6) NULL,
	[xQ7] [int] NULL,
	[iQ7m] [int] NULL,
	[iQ7x] [int] NULL,
	[iQ7f] [int] NULL,
	[pQ7m] [numeric](9, 6) NULL,
	[pQ7x] [numeric](9, 6) NULL,
	[pQ7f] [numeric](9, 6) NULL,
	[dtBgn] [char](7) NULL,
	[dtEnd] [char](7) NULL,
	[Client] [varchar](255) NULL,
	[Provider] [varchar](255) NULL,
	[dtActualBeginDate] [char](10) NULL,
	[dtActualEndDate] [char](10) NULL
) ON [PRIMARY]

IF OBJECT_ID('reports_bic.dbo.TempAmedisysClient', 'U') IS NOT NULL 
  DROP TABLE reports_bic.dbo.TempAmedisysClient; 

create table  reports_bic.dbo.TempAmedisysClient (
	[iHOS] [int] NULL,
	[iRgn] [int] NULL,
	[iTotal] [int] NULL,
	[iNoCnt] [int] NULL,
	[iOpOut] [int] NULL,
	[iNoEng] [int] NULL,
	[iAbort] [int] NULL,
	[iUsable] [int] NULL,
	[iDone] [int] NULL,
	[xQ1] [int] NULL,
	[iQ1y] [int] NULL,
	[iQ1n] [int] NULL,
	[pQ1] [numeric](9, 6) NULL,
	[xQ2] [int] NULL,
	[iQ2y] [int] NULL,
	[iQ2n] [int] NULL,
	[pQ2] [numeric](9, 6) NULL,
	[xQ4] [int] NULL,
	[iQ4m] [int] NULL,
	[iQ4x] [int] NULL,
	[iQ4f] [int] NULL,
	[pQ4m] [numeric](9, 6) NULL,
	[pQ4x] [numeric](9, 6) NULL,
	[pQ4f] [numeric](9, 6) NULL,
	[xQ5] [int] NULL,
	[iQ5m] [int] NULL,
	[iQ5x] [int] NULL,
	[iQ5f] [int] NULL,
	[pQ5m] [numeric](9, 6) NULL,
	[pQ5x] [numeric](9, 6) NULL,
	[pQ5f] [numeric](9, 6) NULL,
	[xQ6] [int] NULL,
	[iQ6m] [int] NULL,
	[iQ6x] [int] NULL,
	[iQ6f] [int] NULL,
	[pQ6m] [numeric](9, 6) NULL,
	[pQ6x] [numeric](9, 6) NULL,
	[pQ6f] [numeric](9, 6) NULL,
	[xQ7] [int] NULL,
	[iQ7m] [int] NULL,
	[iQ7x] [int] NULL,
	[iQ7f] [int] NULL,
	[pQ7m] [numeric](9, 6) NULL,
	[pQ7x] [numeric](9, 6) NULL,
	[pQ7f] [numeric](9, 6) NULL,
	[dtBgn] [char](7) NULL,
	[dtEnd] [char](7) NULL,
	[Client] [varchar](255) NULL,
	[Provider] [varchar](255) NULL,
	[dtActualBeginDate] [char](10) NULL,
	[dtActualEndDate] [char](10) NULL
) ON [PRIMARY]


set @loop_step=1

while (@loop_step <= 3) --Loop for 3 months
begin

set @loopdate=DATEADD(month, -(@loop_step), GETDATE())

set @MM = month(@loopdate)
set @YYYY = year(@loopdate) --Last Year and Month of the data to collect (2013-12 = December as Last month of X Span months)

print @loopdate
print @MM
print @YYYY
set @Span = 1 --Three months of Data


--Get any Dyad that ever had a valid budget record and filter by HOS / DME if given.
declare @tDyads as table (
	iHOS int,
	iCID int,
	iSID int,
	iDME int
)

insert into @tDyads
select distinct c.iCompanyRef as iHOS, bu.iClientRef as iCID, bu.iSiteRef as iSID, s.iCompanyRef as iDME
from ss.tblBudget as bu
join ss.tblLocation as c on c.iLocationID = bu.iClientRef
join ss.tblLocation as s on s.iLocationID = bu.iSiteRef
where c.iCompanyRef = isnull(@iHOS, c.iCompanyRef)
  and s.iCompanyRef = isnull(@iDME, s.iCompanyRef)




--Get the name of the hospice for extracts later.
declare @sHospice as varchar(128)
select @sHospice = isnull(sName,'Many Hospices') from ss.tblCompany where iCompanyID = @iHOS

declare @xDate as date, @sDate as datetime, @eDate as char(10)
set @sDate = cast(@YYYY as varchar(4)) + '-' + cast(@MM as varchar(2)) + '-01 00:00:00.000'
set @xDate = dateadd(ms,-3,DATEADD(m,1,@sDate))
set @eDate = cast(year(@xDate) as char(4)) + '-' + right('0' + cast(month(@xDate) as varchar(2)),2) + '-' + right('0' + cast(Day(@xDate) as varchar(2)),2)
set @sDate = DATEADD(m,-1*(@Span-1),@sDate)
--select @sDate, @xDate, @eDate



--set @sDate = DATEADD(mm, DATEDIFF(mm, 0, GETDATE()) - 3, 0)
--set @eDate = CONVERT(VARCHAR(25),DATEADD(dd,-(DAY(GETDATE())),GETDATE()),101)

print 'start date is' 
print @sDate
print 'end date is:'
print @eDate


--set @loop_step = @loop_step+1
--end


--check for records
declare @QA_Count as int, @QA_Total as int
select @QA_Total = sum(1) from ss.tblQAResults
where iPatientRef in (
	select iPatientID from ss.tblPatient as p
	join @tDyads as d on p.iClientRef = d.iCID and p.iSiteRef = d.iSID
--	where iClientRef in (
--		--select iLocationID from ss.tblLocation where iCompanyRef = @iHOS
--		select iCID from @CIDs
--	)
)
and cStatusQA in ('O','E','C','A','U') --('C' = iDone, 'O' = iOpOut, 'E' = iNoEng, 'A' = iAbort, 'U' = iNoCnt)

select @QA_Count = sum(1) from ss.tblQAResults
where iPatientRef in (
	select iPatientID from ss.tblPatient as p
	join @tDyads as d on p.iClientRef = d.iCID and p.iSiteRef = d.iSID
--	where iClientRef in (
--		--select iLocationID from ss.tblLocation where iCompanyRef = @iHOS
--		select iCID from @CIDs
--	)
)
--and dFinished between @sDate and @eDate
and dFinished <= @xDate and dFinished >= @sDate
and cStatusQA in ('O','E','C','A','U') --('C' = iDone, 'O' = iOpOut, 'E' = iNoEng, 'A' = iAbort, 'U' = iNoCnt)

--Info to make sure we pulled what we thought we wanted.
select @sHospice as Hospice, cast(@sDate as date) as dS, @eDate as dE, @QA_Total as QA_Ttl, @QA_Count as QA_DateRange


/*exec ss.sp_Report_QACall_Dump YYYY,MM,Span where Span is number of months before YYYYMM you want to range with 1 = current.*/
/*Use the below to fill in A34 to H34 and below, update the SQL with new Date Range, run and cut a lot. Update the values in N24 to N32 and copy over all black cells*/


--Temp table to store our list of Client Site Dyads
declare @Dyad as table (
	iRgn int,
	sRgn varchar(64),
	iCID int,
	sCName varchar(128),
	iSID int,
	sSName varchar(128),
	iDME int,
	sDMEName  varchar(128)
)

	insert into @Dyad
	/* Get a List of Clients by Region with Site and DME*/
	select distinct r.isetid as iRegion, isnull(rtrim(r.sName),c.sState + ' Region') as sRegion,
		dy.iClientRef as iCID, c.sName as sClient,
		dy.iSiteRef as iSID, s.sName as sSite,
		d.iCompanyID as iDME, d.sName as sDME
	from ss.tblDyad as dy
	join ss.tblLocation as c on dy.iClientRef = c.iLocationID
	join ss.tblLocation as s on dy.iSiteRef = s.iLocationID
	join ss.tblCompany as d on s.iCompanyRef = d.iCompanyID
	left join ss.tblSet as r on r.iSetId = c.iSetRef
	join @tDyads as td on dy.iClientRef = td.iCID and dy.iSiteRef = td.iSID
--	where dy.iClientRef in (
--		--select iLocationID from ss.tblLocation where iCompanyRef = @iHOS
--		--734,121,1951,36,215,268,44,538,1889
--		select iCID from @CIDs
--	)

--437 H1, R4, C39, Raw 86, Feed 301
	--and iClientRef = 466
	order by sRegion, sClient, sSite


--Any Region that was not defined needs a negative Region ID based on the state ID.
declare @USStates table (
	iRID int,
	sState varchar(2)
)
insert into @USStates values (-1,'DE')
insert into @USStates values (-2,'NJ')
insert into @USStates values (-3,'PA')
insert into @USStates values (-4,'GA')
insert into @USStates values (-5,'CT')
insert into @USStates values (-6,'MA')
insert into @USStates values (-7,'MD')
insert into @USStates values (-8,'SC')
insert into @USStates values (-9,'NH')
insert into @USStates values (-10,'VA')
insert into @USStates values (-11,'NY')
insert into @USStates values (-12,'NC')
insert into @USStates values (-13,'RI')
insert into @USStates values (-14,'VT')
insert into @USStates values (-15,'KY')
insert into @USStates values (-16,'TN')
insert into @USStates values (-17,'OH')
insert into @USStates values (-18,'LA')
insert into @USStates values (-19,'IN')
insert into @USStates values (-20,'MS')
insert into @USStates values (-21,'IL')
insert into @USStates values (-22,'AL')
insert into @USStates values (-23,'ME')
insert into @USStates values (-24,'MO')
insert into @USStates values (-25,'AR')
insert into @USStates values (-26,'MI')
insert into @USStates values (-27,'FL')
insert into @USStates values (-28,'TX')
insert into @USStates values (-29,'IA')
insert into @USStates values (-30,'WI')
insert into @USStates values (-31,'CA')
insert into @USStates values (-32,'MN')
insert into @USStates values (-33,'OR')
insert into @USStates values (-34,'KS')
insert into @USStates values (-35,'WV')
insert into @USStates values (-36,'NV')
insert into @USStates values (-37,'NE')
insert into @USStates values (-38,'CO')
insert into @USStates values (-39,'ND')
insert into @USStates values (-40,'SD')
insert into @USStates values (-41,'MT')
insert into @USStates values (-42,'WA')
insert into @USStates values (-43,'ID')
insert into @USStates values (-44,'WY')
insert into @USStates values (-45,'UT')
insert into @USStates values (-46,'OK')
insert into @USStates values (-47,'NM')
insert into @USStates values (-48,'AZ')
insert into @USStates values (-49,'AK')
insert into @USStates values (-50,'HI')
insert into @USStates values (-51,'DC')

update @Dyad
set iRgn = us.iRID
from @Dyad as dy
join @USStates as us on left(dy.sRgn,2) = us.sState
where iRgn is null

--select * from ss.tblLocation where iLocationID = 466
--select * from ss.tblDyad where iClientRef = 466

--If there is no region data, this will blow things up. 
--This was the case for a Washington DC with DC as the State name under Vitas.
select 'ERROR' as info, 'Missing iRGN' as note, * from @Dyad
where iRgn is null

--select * from ss.tblSet where iSetID = 41

--Lets get a place to store QA Data we are dumpping out by Dyad.
declare @QA_Dump as table (
	iCID int, iSID int, 
	iTotal int, iNoCnt int, iOpOut int, iNoEng int, iAbort int, iUsable int, iDone int,
	xQ1 int, iQ1y int, iQ1n int, pQ1 numeric(9,6),
	xQ2 int, iQ2y int, iQ2n int, pQ2 numeric(9,6),
	xQ3 int, iQ3y int, iQ3n int, pQ3 numeric(9,6),
	xQ4 int, iQ4m int, iQ4x int, iQ4f int, pQ4m numeric(9,6), pQ4x numeric(9,6), pQ4f numeric(9,6), 
	xQ5 int, iQ5m int, iQ5x int, iQ5f int, pQ5m numeric(9,6), pQ5x numeric(9,6), pQ5f numeric(9,6), 
	xQ6 int, iQ6m int, iQ6x int, iQ6f int, pQ6m numeric(9,6), pQ6x numeric(9,6), pQ6f numeric(9,6), 
	xQ7 int, iQ7m int, iQ7x int, iQ7f int, pQ7m numeric(9,6), pQ7x numeric(9,6), pQ7f numeric(9,6), 
	dtBgn char(7), dtEnd char(7),
	Client varchar(255), Provider varchar(255),
	dtActualBeginDate char(10),	dtActualEndDate char(10)
)



--Cursor Loop
--Declare Loop Vars
DECLARE @z_iCID int, @z_iSID int
--Declare Cursor
DECLARE dyad_cursor CURSOR FOR
--Select Loop Data
SELECT iCID, iSID
FROM @Dyad
--Open Loop
OPEN dyad_cursor
	-- Perform the first fetch and store the values in variables.
	FETCH NEXT FROM dyad_cursor INTO @z_iCID, @z_iSID
	-- Check @@FETCH_STATUS to see if there are any more rows to fetch.
	WHILE @@FETCH_STATUS = 0 BEGIN
		--Do Stuff
		insert into @QA_Dump (
			iCID, iSID, 
			iTotal, iNoCnt, iOpOut, iNoEng, iAbort, iUsable, iDone,
			xQ1, iQ1y, iQ1n, pQ1,
			xQ2, iQ2y, iQ2n, pQ2,
			xQ3, iQ3y, iQ3n, pQ3,
			xQ4, iQ4m, iQ4x, iQ4f, pQ4m, pQ4x, pQ4f,
			xQ5, iQ5m, iQ5x, iQ5f, pQ5m, pQ5x, pQ5f,
			xQ6, iQ6m, iQ6x, iQ6f, pQ6m, pQ6x, pQ6f,
			xQ7, iQ7m, iQ7x, iQ7f, pQ7m, pQ7x, pQ7f,
			dtBgn, dtEnd,
			Client, Provider,
			dtActualBeginDate,	dtActualEndDate
		) 
		exec reports_bic.dbo.sp_Report_QACall_DumpV1 @YYYY,@MM,@Span,@z_iCID,@z_iSID,0,1,0 --@iCID, @iSID, No Dates, Show Results, No Notes
		-- This is executed as long as the previous fetch succeeds.
		FETCH NEXT FROM dyad_cursor INTO @z_iCID, @z_iSID
	END
--Close the loop
CLOSE dyad_cursor
DEALLOCATE dyad_cursor


--Bad Actual End date, it goes to last ms of month, but updates to SP have it showing first day of last month.
--So we wil force it back to the last day of month.
update @QA_Dump set dtActualEndDate = @eDate 


--Hold and sort Rollups.
declare @QA_Rollup as table (
	cType char(1), iLvl int,
	--Dyad Data
	iRgn int,
	sRgn varchar(64),
	iCID int,
	sCName varchar(128),
	iSID int,
	sSName varchar(128),
	iDME int,
	sDMEName  varchar(128),
	--Dump Data	
	iHC_ID int, iSR_ID int, 
	iTotal int, iNoCnt int, iOpOut int, iNoEng int, iAbort int, iUsable int, iDone int,
	xQ1 int, iQ1y int, iQ1n int, pQ1 numeric(9,6),
	xQ2 int, iQ2y int, iQ2n int, pQ2 numeric(9,6),
	xQ3 int, iQ3y int, iQ3n int, pQ3 numeric(9,6),
	xQ4 int, iQ4m int, iQ4x int, iQ4f int, pQ4m numeric(9,6), pQ4x numeric(9,6), pQ4f numeric(9,6), 
	xQ5 int, iQ5m int, iQ5x int, iQ5f int, pQ5m numeric(9,6), pQ5x numeric(9,6), pQ5f numeric(9,6), 
	xQ6 int, iQ6m int, iQ6x int, iQ6f int, pQ6m numeric(9,6), pQ6x numeric(9,6), pQ6f numeric(9,6), 
	xQ7 int, iQ7m int, iQ7x int, iQ7f int, pQ7m numeric(9,6), pQ7x numeric(9,6), pQ7f numeric(9,6), 
	dtBgn char(7), dtEnd char(7),
	Client varchar(255), Provider varchar(255),
	dtActualBeginDate char(10),	dtActualEndDate char(10)
)

--Levels 
--10 = Hospice Level
--20 = Region Level
--30 = Sub Region Level (Amedisys is only one using it)
--40 = Client Level

insert into @QA_Rollup
--Put in the Dyad Level
select 'C', 40, * from @Dyad as d
left join @QA_Dump as q on d.iCID = q.iCID and d.iSID = q.iSID


insert into @QA_Rollup
--Put in the Region Level
select 'R', 20, iRgn, sRgn, null, 'Many' as sCName, null, 'Many' as sSName, null, 'Many' as sDMEName, @iHOS, iRgn,
	sum(isnull(iTotal,0)), sum(isnull(iNoCnt,0)), sum(isnull(iOpOut,0)), sum(isnull(iNoEng,0)), 
	sum(isnull(iAbort,0)), sum(isnull(iUsable,0)), sum(isnull(iDone,0)),
	sum(isnull(xQ1,0)), sum(isnull(iQ1y,0)), sum(isnull(iQ1n,0)), 0 as pQ1,
	sum(isnull(xQ2,0)), sum(isnull(iQ2y,0)), sum(isnull(iQ2n,0)), 0 as pQ2,
	sum(isnull(xQ3,0)), sum(isnull(iQ3y,0)), sum(isnull(iQ3n,0)), 0 as pQ3,
	sum(isnull(xQ4,0)), sum(isnull(iQ4m,0)), sum(isnull(iQ4x,0)), sum(isnull(iQ4f,0)), 0 as pQ4m, 0 as pQ4x, 0 as pQ4f,
	sum(isnull(xQ5,0)), sum(isnull(iQ5m,0)), sum(isnull(iQ5x,0)), sum(isnull(iQ5f,0)), 0 as pQ5m, 0 as pQ5x, 0 as pQ5f,
	sum(isnull(xQ6,0)), sum(isnull(iQ6m,0)), sum(isnull(iQ6x,0)), sum(isnull(iQ6f,0)), 0 as pQ6m, 0 as pQ6x, 0 as pQ6f,
	sum(isnull(xQ7,0)), sum(isnull(iQ7m,0)), sum(isnull(iQ7x,0)), sum(isnull(iQ7f,0)), 0 as pQ7m, 0 as pQ7x, 0 as pQ7f,
	dtBgn, dtEnd,
	@sHospice as Client, sRgn as Provider,
	dtActualBeginDate, dtActualEndDate
from @QA_Rollup
where dtBgn is not null --remove the client locations with null data
group by iRgn, sRgn, dtBgn, dtEnd, dtActualBeginDate, dtActualEndDate
order by sRgn


insert into @QA_Rollup
--Put in the Hospice Level
select 'H', 10, 0 as iRgn, 'All' as sRgn, null, 'All' as sCName, null, 'All' as sSName, null, 'All' as sDMEName, @iHOS, 0,
	sum(isnull(iTotal,0)), sum(isnull(iNoCnt,0)), sum(isnull(iOpOut,0)), sum(isnull(iNoEng,0)), 
	sum(isnull(iAbort,0)), sum(isnull(iUsable,0)), sum(isnull(iDone,0)),
	sum(isnull(xQ1,0)), sum(isnull(iQ1y,0)), sum(isnull(iQ1n,0)), 0 as pQ1,
	sum(isnull(xQ2,0)), sum(isnull(iQ2y,0)), sum(isnull(iQ2n,0)), 0 as pQ2,
	sum(isnull(xQ3,0)), sum(isnull(iQ3y,0)), sum(isnull(iQ3n,0)), 0 as pQ3,
	sum(isnull(xQ4,0)), sum(isnull(iQ4m,0)), sum(isnull(iQ4x,0)), sum(isnull(iQ4f,0)), 0 as pQ4m, 0 as pQ4x, 0 as pQ4f,
	sum(isnull(xQ5,0)), sum(isnull(iQ5m,0)), sum(isnull(iQ5x,0)), sum(isnull(iQ5f,0)), 0 as pQ5m, 0 as pQ5x, 0 as pQ5f,
	sum(isnull(xQ6,0)), sum(isnull(iQ6m,0)), sum(isnull(iQ6x,0)), sum(isnull(iQ6f,0)), 0 as pQ6m, 0 as pQ6x, 0 as pQ6f,
	sum(isnull(xQ7,0)), sum(isnull(iQ7m,0)), sum(isnull(iQ7x,0)), sum(isnull(iQ7f,0)), 0 as pQ7m, 0 as pQ7x, 0 as pQ7f,
	dtBgn, dtEnd,
	@sHospice as Client, 'Region: All' as Provider,
	dtActualBeginDate, dtActualEndDate
from @QA_Rollup
where dtBgn is not null --remove the client locations with null data
and iLvl = 40
group by dtBgn, dtEnd, dtActualBeginDate, dtActualEndDate



--Get Calculated Percentges after the records have been updated
update @QA_Rollup set 
	pQ1 =  case xQ1 when 0 then 0 else (iQ1y * 1.0) / xQ1 end,
	pQ2 =  case xQ2 when 0 then 0 else (iQ2y * 1.0) / xQ2 end,
	pQ3 =  case xQ3 when 0 then 0 else (iQ3y * 1.0) / xQ3 end,
	pQ4m = case xQ4 when 0 then 0 else (iQ4m * 1.0) / xQ4 end,
	pQ4x = case xQ4 when 0 then 0 else (iQ4x * 1.0) / xQ4 end,
	pQ4f = case xQ4 when 0 then 0 else (iQ4f * 1.0) / xQ4 end,
	pQ5m = case xQ5 when 0 then 0 else (iQ5m * 1.0) / xQ5 end,
	pQ5x = case xQ5 when 0 then 0 else (iQ5x * 1.0) / xQ5 end,
	pQ5f = case xQ5 when 0 then 0 else (iQ5f * 1.0) / xQ5 end,
	pQ6m = case xQ6 when 0 then 0 else (iQ6m * 1.0) / xQ6 end,
	pQ6x = case xQ6 when 0 then 0 else (iQ6x * 1.0) / xQ6 end,
	pQ6f = case xQ6 when 0 then 0 else (iQ6f * 1.0) / xQ6 end,
	pQ7m = case xQ7 when 0 then 0 else (iQ7m * 1.0) / xQ7 end,
	pQ7x = case xQ7 when 0 then 0 else (iQ7x * 1.0) / xQ7 end,
	pQ7f = case xQ7 when 0 then 0 else (iQ7f * 1.0) / xQ7 end
where iLvl <> 40

---------
--National Level
------------
select 'Hospice Level' as info
select iHC_ID as iHOS, iSR_ID as iRgn, 
	iTotal, iNoCnt, iOpOut, iNoEng, iAbort, iUsable, iDone,
	xQ1, iQ1y, iQ1n, pQ1,
	xQ2, iQ2y, iQ2n, pQ2,
	xQ3, iQ3y, iQ3n, pQ3,
	xQ4, iQ4m, iQ4x, iQ4f, pQ4m, pQ4x, pQ4f,
	xQ5, iQ5m, iQ5x, iQ5f, pQ5m, pQ5x, pQ5f,
	xQ6, iQ6m, iQ6x, iQ6f, pQ6m, pQ6x, pQ6f,
	xQ7, iQ7m, iQ7x, iQ7f, pQ7m, pQ7x, pQ7f,
	dtBgn, dtEnd,
	Client, Provider,
	dtActualBeginDate,	dtActualEndDate 
from @QA_Rollup
where iLvl = 10
--get Notes

  
    declare @pq1 as numeric(9,6),@pq2 as numeric(9,6)
	declare @pQ4m as numeric(9,6), @pQ4x as numeric(9,6), @pQ4f as numeric(9,6)
	declare @pQ5m as numeric(9,6), @pQ5x as numeric(9,6), @pQ5f as numeric(9,6)
	declare @pQ6m as numeric(9,6), @pQ6x as numeric(9,6), @pQ6f as numeric(9,6)
	declare @pQ7m as numeric(9,6), @pQ7x as numeric(9,6), @pQ7f as numeric(9,6)
	declare @smonth varchar(12)

	set @smonth=DATENAME(month ,@sDate)


  select @pq1 = pQ1 from @QA_Rollup where iLvl = 10 
  select @pq2 = pQ2 from @QA_Rollup where iLvl = 10 
  select @pq4m = pQ4m from @QA_Rollup where iLvl = 10 
  select @pq4x = pQ4x from @QA_Rollup where iLvl = 10 
  select @pq4f = pQ4f from @QA_Rollup where iLvl = 10 
  select @pq5m = pQ5m from @QA_Rollup where iLvl = 10 
  select @pq5x = pQ5x from @QA_Rollup where iLvl = 10 
  select @pq5f = pQ5f from @QA_Rollup where iLvl = 10 
  select @pq6m = pQ6m from @QA_Rollup where iLvl = 10 
  select @pq6x = pQ6x from @QA_Rollup where iLvl = 10 
  select @pq6f = pQ6f from @QA_Rollup where iLvl = 10 
  select @pq7m = pQ7m from @QA_Rollup where iLvl = 10 
  select @pq7x = pQ7x from @QA_Rollup where iLvl = 10 
  select @pq7f = pQ7f from @QA_Rollup where iLvl = 10 



  insert into reports_bic.dbo.AmedisysQANationalQuestions values ('Equipment',@pq1,1-@pq1,null,@smonth);
  insert into reports_bic.dbo.AmedisysQANationalQuestions values ('Instruction',@pq2,1-@pq2,null,@smonth);
  insert into reports_bic.dbo.AmedisysQANationalQuestions values ('Delivery Person',@pQ4m, @pQ4f, @pQ4x,@smonth);
  insert into reports_bic.dbo.AmedisysQANationalQuestions values ('Phone Service',@pQ5m, @pQ5f, @pQ5x,@smonth);
  insert into reports_bic.dbo.AmedisysQANationalQuestions values ('Timely Delivery',@pQ6m, @pQ6f, @pQ6x,@smonth);
  insert into reports_bic.dbo.AmedisysQANationalQuestions values ('Timely Pickup',@pQ7m, @pQ7f, @pQ7x,@smonth);

  
------------------
--Region Level
----------------


select 'Region Level' as info
insert into  reports_bic.dbo.TempAmedisysRegional
select iHC_ID as iHOS, iSR_ID as iRgn, 
	iTotal, iNoCnt, iOpOut, iNoEng, iAbort, iUsable, iDone,
	xQ1, iQ1y, iQ1n, pQ1,
	xQ2, iQ2y, iQ2n, pQ2,
	xQ4, iQ4m, iQ4x, iQ4f, pQ4m, pQ4x, pQ4f,
	xQ5, iQ5m, iQ5x, iQ5f, pQ5m, pQ5x, pQ5f,
	xQ6, iQ6m, iQ6x, iQ6f, pQ6m, pQ6x, pQ6f,
	xQ7, iQ7m, iQ7x, iQ7f, pQ7m, pQ7x, pQ7f,
	dtBgn, dtEnd,
	Client, Provider,
	dtActualBeginDate,	dtActualEndDate 
from @QA_Rollup
where iLvl = 20
--get Notes


------------------
--Client Level
----------------


select 'Client Level' as info
insert into  reports_bic.dbo.TempAmedisysClient
select iHC_ID as iHOS, iSR_ID as iRgn, 
	iTotal, iNoCnt, iOpOut, iNoEng, iAbort, iUsable, iDone,
	xQ1, iQ1y, iQ1n, pQ1,
	xQ2, iQ2y, iQ2n, pQ2,
--	xQ3, iQ3y, iQ3n, pQ3,
	xQ4, iQ4m, iQ4x, iQ4f, pQ4m, pQ4x, pQ4f,
	xQ5, iQ5m, iQ5x, iQ5f, pQ5m, pQ5x, pQ5f,
	xQ6, iQ6m, iQ6x, iQ6f, pQ6m, pQ6x, pQ6f,
	xQ7, iQ7m, iQ7x, iQ7f, pQ7m, pQ7x, pQ7f,
	dtBgn, dtEnd,
	Client, Provider,
	dtActualBeginDate,	dtActualEndDate
from @QA_Rollup
where iLvl = 40
and iHC_ID is not null


--select ss.fn_Qts_Show('He&#39;s doin&#36; a &#34;great&#34; Job.')
insert into reports_bic.[dbo].[AmedisysFeedback]
select QAR.iOrderRef as iOID, --QAF.cType, 
	QAFT.sName as sType, DATENAME(month ,QAF.dCreated) as dGiven,
	rtrim(ss.fn_Qts_Show(QAF.sNote)) as sFeedback, --Remove the markup
	rtrim(re.sname) as RegionName, rtrim(c.sName) as ClientName
	
from ss.tblQAFeedback as QAF
join ss.tblQAResults as QAR on QAF.iQAResultsRef = QAR.iQAResultsID
join ss.tblLookup as QAFT on QAFT.sGroup = 'QAFT' and QAF.cType = QAFT.sCode
join ss.tblOrder as O on o.iOrderID = QAR.iOrderRef
join ss.tblPatient as P on p.iPatientID = o.iPatientID
--join ss.tblLocation as S on s.iLocationID = p.iSiteRef
join ss.tblLocation as C on c.iLocationID = p.iClientRef
join @USStates as us on us.sState = c.sState
left join ss.tblSet as re on re.iSetId = c.iSetRef
left join ss.tblIPU as I on i.iPatientRef = p.iPatientID
where iQAResultsRef in (
	--Get all the QA IDs that fall in the date range and are for these CIDs
	select iQAResultsID from ss.tblQAResults
	where iPatientRef in (
		select iPatientID from ss.tblPatient as p
		join @tDyads as d on p.iClientRef = d.iCID and p.iSiteRef = d.iSID
--		where iClientRef in (
--		select iLocationID from ss.tblLocation where iCompanyRef = @iHOS
--			select iCID from @CIDs
--)
	)
	and dFinished <= @xDate and dFinished >= @sDate
	and cStatusQA in ('O','E','C','A','U') --('C' = iDone, 'O' = iOpOut, 'E' = iNoEng, 'A' = iAbort, 'U' = iNoCnt)
) and  c.iCompanyRef = @iHOS
order by QAF.dCreated


delete from @QA_Rollup 
delete from @QA_Dump
delete from @Dyad
delete from @tDyads
delete from @USStates

---your code ends here----
set @loop_step=@loop_step+1
end



/*Region Level Transpose*/



IF OBJECT_ID('reports_bic.dbo.AmedisysRegional', 'U') IS NOT NULL 
  DROP TABLE reports_bic.dbo.AmedisysRegional; 

create table  reports_bic.dbo.AmedisysRegional (
	[seqno] [bigint] NULL,
	[iHOS] [int] NULL,
	[iRgn] [int] NULL,
	[iTotal] [int] NULL,
	[iNoCnt] [int] NULL,
	[iOpOut] [int] NULL,
	[iNoEng] [int] NULL,
	[iAbort] [int] NULL,
	[iUsable] [int] NULL,
	[iDone] [int] NULL,
	[xQ1] [int] NULL,
	[iQ1y] [int] NULL,
	[iQ1n] [int] NULL,
	[pQ1] [numeric](9, 6) NULL,
	[xQ2] [int] NULL,
	[iQ2y] [int] NULL,
	[iQ2n] [int] NULL,
	[pQ2] [numeric](9, 6) NULL,
	[xQ4] [int] NULL,
	[iQ4m] [int] NULL,
	[iQ4x] [int] NULL,
	[iQ4f] [int] NULL,
	[pQ4m] [numeric](9, 6) NULL,
	[pQ4x] [numeric](9, 6) NULL,
	[pQ4f] [numeric](9, 6) NULL,
	[xQ5] [int] NULL,
	[iQ5m] [int] NULL,
	[iQ5x] [int] NULL,
	[iQ5f] [int] NULL,
	[pQ5m] [numeric](9, 6) NULL,
	[pQ5x] [numeric](9, 6) NULL,
	[pQ5f] [numeric](9, 6) NULL,
	[xQ6] [int] NULL,
	[iQ6m] [int] NULL,
	[iQ6x] [int] NULL,
	[iQ6f] [int] NULL,
	[pQ6m] [numeric](9, 6) NULL,
	[pQ6x] [numeric](9, 6) NULL,
	[pQ6f] [numeric](9, 6) NULL,
	[xQ7] [int] NULL,
	[iQ7m] [int] NULL,
	[iQ7x] [int] NULL,
	[iQ7f] [int] NULL,
	[pQ7m] [numeric](9, 6) NULL,
	[pQ7x] [numeric](9, 6) NULL,
	[pQ7f] [numeric](9, 6) NULL,
	[dtBgn] [char](7) NULL,
	[dtEnd] [char](7) NULL,
	[Client] [varchar](255) NULL,
	[Provider] [varchar](255) NULL,
	[dtActualBeginDate] [char](10) NULL,
	[dtActualEndDate] [char](10) NULL
) ON [PRIMARY]



select 'Amedisys Region Level' as info
insert into  reports_bic.dbo.AmedisysRegional
select ROW_NUMBER() over (order by Provider) as seqno,iHOS,iRgn, 
	iTotal, iNoCnt, iOpOut, iNoEng, iAbort, iUsable, iDone,
	xQ1, iQ1y, iQ1n, pQ1,
	xQ2, iQ2y, iQ2n, pQ2,
	xQ4, iQ4m, iQ4x, iQ4f, pQ4m, pQ4x, pQ4f,
	xQ5, iQ5m, iQ5x, iQ5f, pQ5m, pQ5x, pQ5f,
	xQ6, iQ6m, iQ6x, iQ6f, pQ6m, pQ6x, pQ6f,
	xQ7, iQ7m, iQ7x, iQ7f, pQ7m, pQ7x, pQ7f,
	dtBgn, dtEnd,
	Client, Provider,
	dtActualBeginDate,	dtActualEndDate 
from reports_bic.dbo.TempAmedisysRegional
--get Notes

declare @regcnt as int,@rgn_step as int,@regionname varchar(100)

select @regcnt=count(*) from reports_bic.dbo.AmedisysRegional

print 'region count is'
print @regcnt
  
 
set @rgn_step=1
while (@rgn_step <= @regcnt)
begin


declare @perQ1 as numeric(9,6),@perQ2 as numeric(9,6)declare @perQ4m as numeric(9,6), @perQ4x as numeric(9,6), @perQ4f as numeric(9,6)
declare @perQ5m as numeric(9,6), @perQ5x as numeric(9,6), @perQ5f as numeric(9,6)
declare @perQ6m as numeric(9,6), @perQ6x as numeric(9,6), @perQ6f as numeric(9,6)
declare @perQ7m as numeric(9,6), @perQ7x as numeric(9,6), @perQ7f as numeric(9,6)
declare @gmonth varchar(12)
declare @providername varchar(100)

	select @gmonth=DATENAME(month ,dtActualBeginDate) from reports_bic.dbo.AmedisysRegional where seqno=@rgn_step
	select @providername=  Provider from reports_bic.dbo.AmedisysRegional where seqno=@rgn_step


  select @perQ1 = pQ1 from reports_bic.dbo.AmedisysRegional where seqno=@rgn_step 
  select @perQ2 = pQ2 from reports_bic.dbo.AmedisysRegional where seqno=@rgn_step 
  select @perQ4m = pQ4m from reports_bic.dbo.AmedisysRegional where seqno=@rgn_step 
  select @perQ4x = pQ4x from reports_bic.dbo.AmedisysRegional where seqno=@rgn_step 
  select @perQ4f = pQ4f from reports_bic.dbo.AmedisysRegional where seqno=@rgn_step 
  select @perQ5m = pQ5m from reports_bic.dbo.AmedisysRegional where seqno=@rgn_step 
  select @perQ5x = pQ5x from reports_bic.dbo.AmedisysRegional where seqno=@rgn_step 
  select @perQ5f = pQ5f from reports_bic.dbo.AmedisysRegional where seqno=@rgn_step 
  select @perQ6m = pQ6m from reports_bic.dbo.AmedisysRegional where seqno=@rgn_step 
  select @perQ6x = pQ6x from reports_bic.dbo.AmedisysRegional where seqno=@rgn_step 
  select @perQ6f = pQ6f from reports_bic.dbo.AmedisysRegional where seqno=@rgn_step 
  select @perQ7m = pQ7m from reports_bic.dbo.AmedisysRegional where seqno=@rgn_step 
  select @perQ7x = pQ7x from reports_bic.dbo.AmedisysRegional where seqno=@rgn_step 
  select @perQ7f = pQ7f from reports_bic.dbo.AmedisysRegional where seqno=@rgn_step 



  insert into reports_bic.dbo.AmedisysQAregionalQuestions values ('Equipment',@perQ1,1-@perQ1,null,@gmonth,@providername);
  insert into reports_bic.dbo.AmedisysQAregionalQuestions values ('Instruction',@perQ2,1-@perQ2,null,@gmonth,@providername);
  insert into reports_bic.dbo.AmedisysQAregionalQuestions values ('Delivery Person',@perQ4m, @perQ4f, @perQ4x,@gmonth,@providername);
  insert into reports_bic.dbo.AmedisysQAregionalQuestions values ('Phone Service',@perQ5m, @perQ5f, @perQ5x,@gmonth,@providername);
  insert into reports_bic.dbo.AmedisysQAregionalQuestions values ('Timely Delivery',@perQ6m, @perQ6f, @perQ6x,@gmonth,@providername);
  insert into reports_bic.dbo.AmedisysQAregionalQuestions values ('Timely Pickup',@perQ7m, @perQ7f, @perQ7x,@gmonth,@providername);


set @rgn_step=@rgn_step+1
end


/*Client level transpose*/



IF OBJECT_ID('reports_bic.dbo.AmedisysClient', 'U') IS NOT NULL 
  DROP TABLE reports_bic.dbo.AmedisysClient; 

create table  reports_bic.dbo.AmedisysClient (
	[seqno] [bigint] NULL,
	[iHOS] [int] NULL,
	[iRgn] [int] NULL,
	[iTotal] [int] NULL,
	[iNoCnt] [int] NULL,
	[iOpOut] [int] NULL,
	[iNoEng] [int] NULL,
	[iAbort] [int] NULL,
	[iUsable] [int] NULL,
	[iDone] [int] NULL,
	[xQ1] [int] NULL,
	[iQ1y] [int] NULL,
	[iQ1n] [int] NULL,
	[pQ1] [numeric](9, 6) NULL,
	[xQ2] [int] NULL,
	[iQ2y] [int] NULL,
	[iQ2n] [int] NULL,
	[pQ2] [numeric](9, 6) NULL,
	[xQ4] [int] NULL,
	[iQ4m] [int] NULL,
	[iQ4x] [int] NULL,
	[iQ4f] [int] NULL,
	[pQ4m] [numeric](9, 6) NULL,
	[pQ4x] [numeric](9, 6) NULL,
	[pQ4f] [numeric](9, 6) NULL,
	[xQ5] [int] NULL,
	[iQ5m] [int] NULL,
	[iQ5x] [int] NULL,
	[iQ5f] [int] NULL,
	[pQ5m] [numeric](9, 6) NULL,
	[pQ5x] [numeric](9, 6) NULL,
	[pQ5f] [numeric](9, 6) NULL,
	[xQ6] [int] NULL,
	[iQ6m] [int] NULL,
	[iQ6x] [int] NULL,
	[iQ6f] [int] NULL,
	[pQ6m] [numeric](9, 6) NULL,
	[pQ6x] [numeric](9, 6) NULL,
	[pQ6f] [numeric](9, 6) NULL,
	[xQ7] [int] NULL,
	[iQ7m] [int] NULL,
	[iQ7x] [int] NULL,
	[iQ7f] [int] NULL,
	[pQ7m] [numeric](9, 6) NULL,
	[pQ7x] [numeric](9, 6) NULL,
	[pQ7f] [numeric](9, 6) NULL,
	[dtBgn] [char](7) NULL,
	[dtEnd] [char](7) NULL,
	[Client] [varchar](255) NULL,
	[Provider] [varchar](255) NULL,
	[dtActualBeginDate] [char](10) NULL,
	[dtActualEndDate] [char](10) NULL
) ON [PRIMARY]



select 'Amedisys Client Level' as info
insert into  reports_bic.dbo.AmedisysClient
select ROW_NUMBER() over (order by Client) as seqno,iHOS,iRgn, 
	iTotal, iNoCnt, iOpOut, iNoEng, iAbort, iUsable, iDone,
	xQ1, iQ1y, iQ1n, pQ1,
	xQ2, iQ2y, iQ2n, pQ2,
	xQ4, iQ4m, iQ4x, iQ4f, pQ4m, pQ4x, pQ4f,
	xQ5, iQ5m, iQ5x, iQ5f, pQ5m, pQ5x, pQ5f,
	xQ6, iQ6m, iQ6x, iQ6f, pQ6m, pQ6x, pQ6f,
	xQ7, iQ7m, iQ7x, iQ7f, pQ7m, pQ7x, pQ7f,
	dtBgn, dtEnd,
	Client, Provider,
	dtActualBeginDate,	dtActualEndDate 
from reports_bic.dbo.TempAmedisysClient
--get Notes

declare @clientcnt as int,@client_step as int

select @clientcnt=count(*) from reports_bic.dbo.AmedisysClient

print 'Client count is'
print @clientcnt
  
 
set @client_step=1
while (@client_step <= @clientcnt)
begin


declare @percQ1 as numeric(9,6),@percQ2 as numeric(9,6)declare @percQ4m as numeric(9,6), @percQ4x as numeric(9,6), @percQ4f as numeric(9,6)
declare @percQ5m as numeric(9,6), @percQ5x as numeric(9,6), @percQ5f as numeric(9,6)
declare @percQ6m as numeric(9,6), @percQ6x as numeric(9,6), @percQ6f as numeric(9,6)
declare @percQ7m as numeric(9,6), @percQ7x as numeric(9,6), @percQ7f as numeric(9,6)
declare @gcmonth varchar(12)
declare @cprovidername varchar(100)
declare @clientname varchar(100)

	select @gcmonth=DATENAME(month ,dtActualBeginDate) from reports_bic.dbo.AmedisysClient where seqno=@client_step
	select @cprovidername=  Provider from reports_bic.dbo.AmedisysClient where seqno=@client_step
	select @clientname= client from reports_bic.dbo.AmedisysClient where seqno=@client_step


  select @percQ1 = pQ1 from reports_bic.dbo.AmedisysClient where seqno=@client_step 
  select @percQ2 = pQ2 from reports_bic.dbo.AmedisysClient where seqno=@client_step 
  select @percQ4m = pQ4m from reports_bic.dbo.AmedisysClient where seqno=@client_step 
  select @percQ4x = pQ4x from reports_bic.dbo.AmedisysClient where seqno=@client_step 
  select @percQ4f = pQ4f from reports_bic.dbo.AmedisysClient where seqno=@client_step 
  select @percQ5m = pQ5m from reports_bic.dbo.AmedisysClient where seqno=@client_step 
  select @percQ5x = pQ5x from reports_bic.dbo.AmedisysClient where seqno=@client_step 
  select @percQ5f = pQ5f from reports_bic.dbo.AmedisysClient where seqno=@client_step 
  select @percQ6m = pQ6m from reports_bic.dbo.AmedisysClient where seqno=@client_step 
  select @percQ6x = pQ6x from reports_bic.dbo.AmedisysClient where seqno=@client_step 
  select @percQ6f = pQ6f from reports_bic.dbo.AmedisysClient where seqno=@client_step 
  select @percQ7m = pQ7m from reports_bic.dbo.AmedisysClient where seqno=@client_step 
  select @percQ7x = pQ7x from reports_bic.dbo.AmedisysClient where seqno=@client_step 
  select @percQ7f = pQ7f from reports_bic.dbo.AmedisysClient where seqno=@client_step 



  insert into reports_bic.dbo.AmedisysQAClientQuestions values ('Equipment',@percQ1,1-@percQ1,null,@gcmonth,@cprovidername,@clientname);
  insert into reports_bic.dbo.AmedisysQAClientQuestions values ('Instruction',@percQ2,1-@percQ2,null,@gcmonth,@cprovidername,@clientname);
  insert into reports_bic.dbo.AmedisysQAClientQuestions values ('Delivery person',@percQ4m, @percQ4f, @percQ4x,@gcmonth,@cprovidername,@clientname);
  insert into reports_bic.dbo.AmedisysQAClientQuestions values ('Phone Service',@percQ5m, @percQ5f, @percQ5x,@gcmonth,@cprovidername,@clientname);
  insert into reports_bic.dbo.AmedisysQAClientQuestions values ('Timely Delivery',@percQ6m, @percQ6f, @percQ6x,@gcmonth,@cprovidername,@clientname);
  insert into reports_bic.dbo.AmedisysQAClientQuestions values ('Timely Pickup',@percQ7m, @percQ7f, @percQ7x,@gcmonth,@cprovidername,@clientname);


set @client_step=@client_step+1
end


  
 