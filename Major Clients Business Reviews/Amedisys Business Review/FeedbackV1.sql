use reports
/*--------------------------------------------------------------------------*\
| QA Data for an SRM Report! 
| Pulls back all data by Client / Site Dyad
| Groups by Region
| Groups by National Level
\*--------------------------------------------------------------------------*/
--Updated by Date     Version  Information
------------ -------- -------- -----------------------------------------------
--Erickson   20140708 01.02.00 Added Notes to query, fixed iHOS to load into @CIDs and use it now.
--Erickson   20160313 01.03.00 Added a filter on HOS and/or DME
--Erickson   20160829 01.03.01 Hospices Added
--Erickson   20160926 01.04.00 Updated Feedback pull to include Simple Pyramid data on extract.


--Check to see if below is populated in Prod yet?
--select 'I WAS LOADED?' as info, * from ss.tblLookup where sGroup = 'QAFT'

--=[Define what we are looking for]=--
Declare @iHOS as int, @iDME as int, @YYYY int, @MM int, @Span int
set @YYYY = 2016 --Last Year and Month of the data to collect (2013-12 = December as Last month of X Span months)
set @MM = 7
set @Span = 6 --Six months of Data

--=[ Pick Target Company ]=--
set @iHOS = 87 --Amedisys (201310,201303,201507,201509,201606,201608)
--set @iHOS = 29 --Odyssey / Gentiva (201310,201401)
--set @iHOS = 10 --Evercare (201312)
--set @iHOS = 12 --Alacare (201401)
--set @iHOS = 86 --(BN-) Vitas (201401, 201506, 201507, 201508, 201509, 201510, 201511, 201512, 201601, 201607)
--set @iHOS = 299 --Tidewell Hospice (201405,201503,201508,201601,201607)
--set @iHOS = 257 --Harbor Light Hospice (201405)
--set @iHOS = 238 --SouthernCare, Inc {Curo} (201410)
--set @iHOS = 187 --Santa Cruz (201501)
--set @iHOS = 1058 --Elizabeth Hospice, Inc (201501)
--set @iHOS = 269 --Suncrest Health Services (201502)
--set @iHOS = 1057 --Sta-Home Health & Hospice, Inc. (201503,201509)
--set @iHOS = 120 --Banner Hospice (201503,201606)
--set @iHOS = 27 --Brookdale Senior Living, Inc (201503)
--set @iHOS = 232 --Hospice Partners of America (201505)
--set @iHOS = 295 --Encompass Home Health & Hospice (201411,201505,201601a,201601b,201607)
--set @iHOS = 227 -- Delaware Hospice (201507)
--set @iHOS = 1334 -- Cornerstone Hospice & Palliative Care (201601)
--set @iHOS = 144 -- Signature Hospice (201601)
--set @iHOS = 136 -- Nathan Adelson Hospice (201602)
--set @iHOS = 1547 --Heartlite Hospice (201605)
--set @iHOS = 1147 --Big Bend Hospice (201608)

--select @iHOS = 12, @iDME = 2 --Alacare (201401)

--select * from ss.tblCompany where sname like '%Big Bend%'
--select * from ss.tblCompany where iCompanyID = 136

--You can set the HOS ID = 0 and define a list of CIDs to run a multi Hospice roll up of a city or state.
--Denver CO data.
--set @iHOS = 0
--declare @CIDs as table (
--	iCID int
--)
--insert into @CIDs (iCID) select 734
--insert into @CIDs (iCID) select 121
--insert into @CIDs (iCID) select 1951
--insert into @CIDs (iCID) select 36
--insert into @CIDs (iCID) select 215
--insert into @CIDs (iCID) select 268
--insert into @CIDs (iCID) select 44
--insert into @CIDs (iCID) select 538
--insert into @CIDs (iCID) select 1889

--select * from ss.tblCompany where sName like 'Harbor%'

--If using a iHOS ID then we will get all Locations based on it.
--insert into @CIDs select iLocationID from ss.tblLocation where iCompanyRef = @iHOS 
--select * from @CIDs


--select * from ss.tblCompany where sName like '%Alacare%'
--select @iHOS = null, @iDME = 2 --All of SSMedical
--select @iHOS = 12, @iDME = 2 --All of Alacare and SSMedical

--Get any Dyad that ever had a valid budget record and filter by HOS / DME if given.
declare @tDyads as table (
	iHOS int,
	iCID int,
	iSID int,
	iDME int
)
--3775
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
	select distinct r.isetid as iRegion, isnull(r.sName,c.sState + ' Region') as sRegion,
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
	sState char(2)
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
		exec ss.sp_Report_QACall_Dump @YYYY,@MM,@Span,@z_iCID,@z_iSID,0,1,0 --@iCID, @iSID, No Dates, Show Results, No Notes
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
	@sHospice as Client, 'Region: ' + sRgn as Provider,
	dtActualBeginDate, dtActualEndDate
from @QA_Rollup
where dtBgn is not null --remove the client locations with null data
group by iRgn, sRgn, dtBgn, dtEnd, dtActualBeginDate, dtActualEndDate
order by sRgn

-- if we are Amedisys then there is sub regions.
if @iHOS = -87 begin	--Changed from 87 to -87 as sub regions are now not in use! 
	update @QA_Rollup set cType = 'S', iLvl = 30,
		sCName = 'Some', sSName = 'Some', sDMEName = 'Some',
		Provider = 'Sub' + Provider
	where iLvl = 20
	and left(sRgn,9) in ('Northeast','Southeast')

	insert into @QA_Rollup
	--Put in the Added Region Levels - from the New SubRegions
	select 'R', 20, min(iRgn) * -100000 as iRgn, left(sRgn,9) as sRgn, null, 'Many' as sCName, null, 'Many' as sSName, null, 'Many' as sDMEName, @iHOS, min(iRgn) * -1,
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
		@sHospice as Client, 'Region: ' + left(sRgn,9) as Provider,
		dtActualBeginDate, dtActualEndDate
	from @QA_Rollup
	where dtBgn is not null --remove the client locations with null data
	and iLvl = 30
	group by left(sRgn,9), dtBgn, dtEnd, dtActualBeginDate, dtActualEndDate
	order by left(sRgn,9)

	--Done with Amedisys Custom SubRegion Logic
end

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

--Pull Back Each Levels Data for the Report

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

select 'Region Level' as info
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
where iLvl = 20

if @iHOS = 87 begin
	select 'SubRegion Level' as info
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
	where iLvl = 30
end

select 'Client Level' as info
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
where iLvl = 40
and iHC_ID is not null


select 'Raw Data' as info
select *
from @QA_Rollup
order by iLvl

--get Notes
--select ss.fn_Qts_Show('He&#39;s doin&#36; a &#34;great&#34; Job.')
select 'Feedback' as info
select QAR.iOrderRef as iOID, --QAF.cType, 
	QAFT.sName as sType, QAF.dCreated as dGiven,
	ss.fn_Qts_Show(QAF.sNote) as sFeedback --Remove the markup
from ss.tblQAFeedback as QAF
join ss.tblQAResults as QAR on QAF.iQAResultsRef = QAR.iQAResultsID
join ss.tblLookup as QAFT on QAFT.sGroup = 'QAFT' and QAF.cType = QAFT.sCode
where iQAResultsRef in (
	--Get all the QA IDs that fall in the date range and are for these CIDs
	select iQAResultsID from ss.tblQAResults
	where iPatientRef in (
		select iPatientID from ss.tblPatient as p
		join @tDyads as d on p.iClientRef = d.iCID and p.iSiteRef = d.iSID
--			where iClientRef in (
--			--select iLocationID from ss.tblLocation where iCompanyRef = @iHOS
--			select iCID from @CIDs
--		)
	)
	and dFinished <= @xDate and dFinished >= @sDate
	and cStatusQA in ('O','E','C','A','U') --('C' = iDone, 'O' = iOpOut, 'E' = iNoEng, 'A' = iAbort, 'U' = iNoCnt)
)
order by QAF.dCreated





select 'Feedback w/ Simple Pyramid' as info
select QAR.iOrderRef as iOID, --QAF.cType, 
	QAFT.sName as sType, QAF.dCreated as dGiven,
	ss.fn_Qts_Show(QAF.sNote) as sFeedback, --Remove the markup
	c.iCompanyRef as iHOS, isnull(c.iSetRef,us.iRID) as iRGN, p.iClientRef as iCID, re.sname as RegionName, s.sName as ClientName,
	i.iIPUID as iIPU, p.iSiteRef as iSID, s.iCompanyRef as iDME
from ss.tblQAFeedback as QAF
join ss.tblQAResults as QAR on QAF.iQAResultsRef = QAR.iQAResultsID
join ss.tblLookup as QAFT on QAFT.sGroup = 'QAFT' and QAF.cType = QAFT.sCode
join ss.tblOrder as O on o.iOrderID = QAR.iOrderRef
join ss.tblPatient as P on p.iPatientID = o.iPatientID
join ss.tblLocation as S on s.iLocationID = p.iSiteRef
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
--			where iClientRef in (
--			--select iLocationID from ss.tblLocation where iCompanyRef = @iHOS
--			select iCID from @CIDs
--		)
	)
	and dFinished <= @xDate and dFinished >= @sDate
	and cStatusQA in ('O','E','C','A','U') --('C' = iDone, 'O' = iOpOut, 'E' = iNoEng, 'A' = iAbort, 'U' = iNoCnt)
)
order by QAF.dCreated


/*
select cType, sum(1) from ss.tblQAFeedback group by cType
select * from ss.tblLookup where sGroup = 'INDEX' and sName like '%QA%'
select * from ss.tblLookup where sGroup = 'QAFT'
insert into ss.tblLookup (sGroup, sCode, sName, sDescription) values ('INDEX','QAFT','QA Feedback Type','Lookup for ss.tblQAFeedback.cType')
insert into ss.tblLookup (sGroup, sCode, sName, sDescription) values ('QAFT','G','General','QA Feedback: General Comments')
insert into ss.tblLookup (sGroup, sCode, sName, sDescription) values ('QAFT','N','Negative','QA Feedback: Negative Comments')
insert into ss.tblLookup (sGroup, sCode, sName, sDescription) values ('QAFT','P','Positive','QA Feedback: Positive Comments')
insert into ss.tblLookup (sGroup, sCode, sName, sDescription) values ('QAFT','S','Escalation','QA Escalation: Note to Supervisor')
select * from ss.tblLookup where sGroup = 'INDEX' and sName like '%QA%'
select * from ss.tblLookup where sGroup = 'QAFT'
*/