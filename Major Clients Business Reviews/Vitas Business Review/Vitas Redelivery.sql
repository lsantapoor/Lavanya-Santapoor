Use reports
/*
-=[Version Infomration]=-
Name        Date     VER   Update
I. Erickson 20130129 1.0   Moving hand run reports into a Stored Procedure
I. Erickson 20150810 1.3   Updated to use reports_dev
I. Erickson 20150903 1.4   Updated to be for all of SSM not just a single site. Plus pushed out to 7 days!
I. Erickson 20150928 1.5   Updated to handle HME, or DME IDs. Show Equipment Detail if DME is Provide
I. Erickson 20151012 1.6   Was looking at last order id, when backdating can make any order before another --Fixed
I. Erickson 20151015 1.7   Debuging logic and testing.
I. Erickson 20151016 1.8   Fixed issue when no ss.tblClientEquipmentList values existed on equipment lookup.
I. Erickson 20151021 1.9   Added Validation Logic
I. Erickson 20160428 2.0   New logic to look at paired items to classify if a redelivery could have been resolved with earlier order.
I. Erickson 20160428 2.1   Droped report to 5 days of data. Per email from Roode on 5/1/2016 - "I’d like to limit data set to 120hrs, 5 days"
I. Erickson 20160428 2.1.1 Pairing Data updated
I. Erickson 20160619 2.1.2 Added %!Paired to Summary Output

-=[Issues]=-
select 24/35.0, 24/49.0

-=[Called By]=-
Report Automation Bot
 
-=[Example Calls]=-


-=[Information]=-

Summary Data
-------------- - ------------------------------------------------------------------------------------------------------------
Provider       - Name of DME and Site Location.
Client         - Name of Client Branch Office Location.
Cnt Orders     - Number of Orders Completed in Time Span.
Cnt Redelivery - Number of Orders that fit ReDelivery Requirements.
% Redelivery   - Percent of Orders that are ReDeliveries.
% 24 hrs       - Percent that were redelivered in  24 hours, 1 Day
% 48 hrs       - Percent that were redelivered in  48 hours, 2 Days
% 72 hrs       - Percent that were redelivered in  72 hours, 3 Days
% 96 hrs       - Percent that were redelivered in  96 hours, 4 Days
% 120 hrs      - Percent that were redelivered in 120 hours, 5 Days
% 144 hrs      - Percent that were redelivered in 144 hours, 6 Days
% 168 hrs      - Percent that were redelivered in 168 hours, 7 Days

Detail Data
-------------- - ------------------------------------------------------------------------------------------------------------
Provider       - Name of DME and Site Location.
Client         - Name of Client Branch Office Location.
Patient Name   - Name of Patient in the System.
Completed      - Date when the order was marked completed in the System.
Order ID       - Order Number.
Reason         - Reason Code selected for the Order.
Prior Order    - Order Number of the Order before this one.
Prior Complete - Date the Prior Order was marked completed in the System.
Hours		   - Number of hours after last delivery.
Note           - Reason why the order was a Redelivery or not listed as a redelivery.
Paired         - Paired Item Flag
sOrderNote     - Notes on the Order.
sOrderItems    - Items on the Order.
sPreOrderNote  - Notes on the Order before this one.
sPreOrderItems - Items on the Order before this one.

Notes on why an order is not a ReDelivery
--------- - -----------------------------------------------------------------------------------------------------------------
PickupOnly - This is a Pickup Order No Delivery was made.
NoDetails  - No items, everything was removed from order. (Disposable, O2, DME, or Pickups; not found in Detail Records.)
StandingO2 - This was for O2 Refill, no DME Delivered.
Service    - Service Calls, normally a equipment issue, not a miss use of ordering system.
NoValidPre - Unable to find a valid Pre Order after dropping invalid orders.
NoPreOrd   - Did not have a PreOrder before X hours from start of time window, or this is first order for Patient.
GT>Days    - Prior order was more than X hours before this order. X = Number of Days times 24 houts a day.
SameStop   - If Same Driver on Same Route at Same Time, this is not a new Stop, Group with other Stop.
SameRoute  - If Same Driver on Same Route on Same Day, this is not a new Stop, Group with other Stop.
2xPost     - If More than one order is traced back to the same preOrder ID, only the first of the Stop Group is a ReDelivery.
NoPrior    - Did not have a PreOrder ID reference.
[Re-Del]   - This is a valid Redelivery Record, not same driver, same route, same day, and within 48 hours of another stop.

*/


--declare @iDays int = 7 --Number of days to check for a redelivery
declare @iDays int = 5 --Number of days to check for a redelivery
declare @iDME int = null --All
declare @iHOS int = null --All
declare @iSID int = null --All
declare @iCID int = null --All
--select @iDME = 2, @iHOS = null --B&M
set @iHOS = 86 --(BN-) Vitas (201401, 201506, 201507, 201508, 201509, 201510, 201511, 201512, 201601)
--Debug Stuff						--Steps show us result of step, debug with oid/pid to watch it change trough steps.
declare @iDebug int = 0--1			--@iDebug = 1 will track an order or a patient through all steps.
declare @iOID_Debug int = null		--Tracking at Order Level
declare @iPID_Debug int = null		--Tracking at Patient Level
declare @iDebugStep_Bgn int = null 	--View one to many steps (First Step) (default to last or 0)
declare @iDebugStep_End int = null	--View one to many steps (Last Step)  (default to first or 0)
declare @iForceYM int = null		--Forces a specific Date window. (this allows us to find debug stuff for a target month)
declare @dForced datetime = null	--Do not use, auto set when forcing iForceYM Above.
/*
Debug Steps
1 - Sort Raw by Complete Date
2 - Copy the Data into Working Table
3 - Link with Patient, populate CID & SID
4 - Count Items on Order and put them into buckets, DME, O2, Disp, Pickup, Service
5 - Label Pickup Only Orders
6 -  
*/
 IF OBJECT_ID('reports_bic.[dbo].[VitasRedelivery]', 'U') IS NOT NULL 
  DROP TABLE reports_bic.[dbo].[VitasRedelivery]; 


CREATE TABLE reports_bic.[dbo].[VitasRedelivery](
    smonth [varchar](12),
	[Provider] [varchar](130) NULL,
	[Client] [varchar](64) NULL,
		Regionname [varchar](64) Null,
	[Cnt Orders] [int] NULL,
	[Cnt Redelivery] [int] NULL,
	[Cnt Missed Pair] [int] NULL,
	[%!Paired] [numeric](9, 4) NULL,
	[% Redelivery] [numeric](9, 4) NULL,
	[% 24 hrs] [numeric](9, 4) NULL,
	[% 48 hrs] [numeric](9, 4) NULL,
	[% 72 hrs] [numeric](9, 4) NULL,
	[% 96 hrs] [numeric](9, 4) NULL,
	[% 120 hrs] [numeric](9, 4) NULL,
	[% 144 hrs] [numeric](9, 4) NULL,
	[% 168 hrs] [numeric](9, 4) NULL,
	[#  24 hrs] [int] NULL,
	[#  48 hrs] [int] NULL,
	[#  72 hrs] [int] NULL,
	[#  96 hrs] [int] NULL,
	[# 120 hrs] [int] NULL,
	[# 144 hrs] [int] NULL,
	[# 168 hrs] [int] NULL
) ON [PRIMARY]
if isnull(@iDebugStep_Bgn,0) = 0 begin set @iDebugStep_Bgn = isnull(@iDebugStep_End,0) end
if isnull(@iDebugStep_End,0) = 0 begin set @iDebugStep_End = @iDebugStep_Bgn end
if @iDebugStep_Bgn > @iDebugStep_End begin set @iDebugStep_End = @iDebugStep_Bgn end
if isnull(@iForceYM,0) <> 0 begin
	if isnull(@iForceYM,0) <> 0 begin --Forcing an offset
		set @dForced = cast(left(cast(@iForceYM as varchar(6)),4) + '-' + right(cast(@iForceYM as varchar(6)),2) + '-01 00:00:00.000' as datetime)
	end
	select 'Debug steps enabled' as info, @iDebugStep_Bgn as 'Bgn', @iDebugStep_End as 'End', @iForceYM as iForcedYM, @dForced as iF_Date
	if isnull(@iForceYM,0) <> 0 begin --Forcing an offset
		set @dForced = dateadd(m,1,@dForced) --We by default do not work on current month but last one, so the date will roll back 1
	end
end

declare @tOrderBuckets table (sStep varchar(32), iOID int, iCntDME int, iCntO2 int, iCntDisp int, iCntPickup int, iCntService int, iCntPaired int)

/*----------------------------------------*\
|  Bgn Paired Table Definition             |
\*----------------------------------------*/
	if not exists (select * from dbo.sysobjects where id = object_id(N'[ss].[tblItem_Pairs]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
		CREATE TABLE ss.tblItem_Pairs (
			iIID_Main int,	--Parent Item if this goes out, we want to see the paired Items with it.
			iIID_Sub int,	--Paired Item (should go out with the Main Item.)
			sDescription varchar(255) --Named Item paired with Item Reference
		)  ON [PRIMARY]

		--Over Bed Table [ 195 ] ( Paired with Beds )
		insert into ss.tblItem_Pairs values (838,195,'') --Bed: Bariatric [ 838 ]
		insert into ss.tblItem_Pairs values (795,195,'') --Bed: Full-Electric (Hospital Grade) [ 795 ]
		insert into ss.tblItem_Pairs values (25,195,'') --Bed: Full-Electric [ 25 ]
		insert into ss.tblItem_Pairs values (9,195,'') --Bed - Semi-Electric [ 9 ]

		--WC - Foot Rests (pair) [ 313 ] ( Paired with Wheelchairs )
		insert into ss.tblItem_Pairs values (322,313,'') --Wheelchair Heavy Duty 20 [ 322 ]
		insert into ss.tblItem_Pairs values (323,313,'') --Wheelchair Heavy Duty 22 [ 323 ]
		insert into ss.tblItem_Pairs values (324,313,'') --Wheelchair Heavy Duty 24 [ 324 ]
		insert into ss.tblItem_Pairs values (783,313,'') --Wheelchair Heavy Duty 28 [ 783 ]
		insert into ss.tblItem_Pairs values (893,313,'') --Wheelchair Hemi 16" [ 893 ]
		insert into ss.tblItem_Pairs values (894,313,'') --Wheelchair Hemi 18" [ 894 ]
		insert into ss.tblItem_Pairs values (895,313,'') --Wheelchair Hemi 20" [ 895 ]
		insert into ss.tblItem_Pairs values (329,313,'') --Wheelchair Lightweight 14" [ 329 ]
		insert into ss.tblItem_Pairs values (330,313,'') --Wheelchair Lightweight 16" [ 330 ]
		insert into ss.tblItem_Pairs values (331,313,'') --Wheelchair Lightweight 18" [ 331 ]
		insert into ss.tblItem_Pairs values (332,313,'') --Wheelchair Lightweight 20" [ 332 ]
		insert into ss.tblItem_Pairs values (333,313,'') --Wheelchair Lightweight 22" [ 333 ]
		insert into ss.tblItem_Pairs values (334,313,'') --Wheelchair Lightweight 24" [ 334 ]
		insert into ss.tblItem_Pairs values (697,313,'') --Solara Tilt in Space 16" [ 697 ]
		insert into ss.tblItem_Pairs values (698,313,'') --Solara Tilt in Space 18" [ 698 ]
		insert into ss.tblItem_Pairs values (699,313,'') --Solara Tilt in Space 20" [ 699 ]
		insert into ss.tblItem_Pairs values (700,313,'') --Solara Tilt in Space 22" [ 700 ]
		insert into ss.tblItem_Pairs values (790,313,'') --Tilt & Reclining WC 18" [ 790 ]
		insert into ss.tblItem_Pairs values (325,313,'') --Wheelchair High Back Recliner 16" [ 325 ]
		insert into ss.tblItem_Pairs values (326,313,'') --Wheelchair High Back Recliner 18" [ 326 ]
		insert into ss.tblItem_Pairs values (327,313,'') --Wheelchair High Back Recliner 20" [ 327 ]
		insert into ss.tblItem_Pairs values (328,313,'') --Wheelchair High Back Recliner 22" [ 328 ]
		insert into ss.tblItem_Pairs values (896,313,'') --Wheelchair High Back Recliner 24" [ 896 ]
		insert into ss.tblItem_Pairs values (775,313,'') --Wheelchair Lightweight Recliner 18" [ 775 ]
		insert into ss.tblItem_Pairs values (793,313,'') --Wheelchair Companion 14" [ 793 ]
		insert into ss.tblItem_Pairs values (335,313,'') --Wheelchair Pediatric 18" [ 335 ]
		insert into ss.tblItem_Pairs values (792,313,'') --Wheelchair Standard 14" [ 792 ]
		insert into ss.tblItem_Pairs values (336,313,'') --Wheelchair Standard 16" [ 336 ]
		insert into ss.tblItem_Pairs values (337,313,'') --Wheelchair Standard 18" [ 337 ]
		insert into ss.tblItem_Pairs values (338,313,'') --Wheelchair Standard 20" [ 338 ]
		insert into ss.tblItem_Pairs values (339,313,'') --Wheelchair Standard 22" [ 339 ]
		insert into ss.tblItem_Pairs values (340,313,'') --Wheelchair Standard 24" [ 340 ]
		insert into ss.tblItem_Pairs values (746,313,'') --Wheelchair Standard 26" [ 746 ]
		insert into ss.tblItem_Pairs values (847,313,'') --Wheelchair Standard 28" [ 847 ]
		insert into ss.tblItem_Pairs values (848,313,'') --Wheelchair Standard 30" [ 848 ]
		insert into ss.tblItem_Pairs values (320,313,'') --Wheelchair Companion 16" [ 320 ]
		insert into ss.tblItem_Pairs values (321,313,'') --Wheelchair Companion 18" [ 321 ]
		insert into ss.tblItem_Pairs values (791,313,'') --Wheelchair companion 19" [ 791 ]
		insert into ss.tblItem_Pairs values (695,313,'') --Wheelchair companion 20" [ 695 ]
		insert into ss.tblItem_Pairs values (696,313,'') --Wheelchair companion 22" [ 696 ]
		
		--WC - Elevated Leg Rest (pair) [ 312 ] ( Paired with Wheelchairs )
		insert into ss.tblItem_Pairs values (322,312,'') --Wheelchair Heavy Duty 20 [ 322 ]
		insert into ss.tblItem_Pairs values (323,312,'') --Wheelchair Heavy Duty 22 [ 323 ]
		insert into ss.tblItem_Pairs values (324,312,'') --Wheelchair Heavy Duty 24 [ 324 ]
		insert into ss.tblItem_Pairs values (783,312,'') --Wheelchair Heavy Duty 28 [ 783 ]
		insert into ss.tblItem_Pairs values (893,312,'') --Wheelchair Hemi 16" [ 893 ]
		insert into ss.tblItem_Pairs values (894,312,'') --Wheelchair Hemi 18" [ 894 ]
		insert into ss.tblItem_Pairs values (895,312,'') --Wheelchair Hemi 20" [ 895 ]
		insert into ss.tblItem_Pairs values (329,312,'') --Wheelchair Lightweight 14" [ 329 ]
		insert into ss.tblItem_Pairs values (330,312,'') --Wheelchair Lightweight 16" [ 330 ]
		insert into ss.tblItem_Pairs values (331,312,'') --Wheelchair Lightweight 18" [ 331 ]
		insert into ss.tblItem_Pairs values (332,312,'') --Wheelchair Lightweight 20" [ 332 ]
		insert into ss.tblItem_Pairs values (333,312,'') --Wheelchair Lightweight 22" [ 333 ]
		insert into ss.tblItem_Pairs values (334,312,'') --Wheelchair Lightweight 24" [ 334 ]
		insert into ss.tblItem_Pairs values (697,312,'') --Solara Tilt in Space 16" [ 697 ]
		insert into ss.tblItem_Pairs values (698,312,'') --Solara Tilt in Space 18" [ 698 ]
		insert into ss.tblItem_Pairs values (699,312,'') --Solara Tilt in Space 20" [ 699 ]
		insert into ss.tblItem_Pairs values (700,312,'') --Solara Tilt in Space 22" [ 700 ]
		insert into ss.tblItem_Pairs values (790,312,'') --Tilt & Reclining WC 18" [ 790 ]
		insert into ss.tblItem_Pairs values (325,312,'') --Wheelchair High Back Recliner 16" [ 325 ]
		insert into ss.tblItem_Pairs values (326,312,'') --Wheelchair High Back Recliner 18" [ 326 ]
		insert into ss.tblItem_Pairs values (327,312,'') --Wheelchair High Back Recliner 20" [ 327 ]
		insert into ss.tblItem_Pairs values (328,312,'') --Wheelchair High Back Recliner 22" [ 328 ]
		insert into ss.tblItem_Pairs values (896,312,'') --Wheelchair High Back Recliner 24" [ 896 ]
		insert into ss.tblItem_Pairs values (775,312,'') --Wheelchair Lightweight Recliner 18" [ 775 ]
		insert into ss.tblItem_Pairs values (793,312,'') --Wheelchair Companion 14" [ 793 ]
		insert into ss.tblItem_Pairs values (335,312,'') --Wheelchair Pediatric 18" [ 335 ]
		insert into ss.tblItem_Pairs values (792,312,'') --Wheelchair Standard 14" [ 792 ]
		insert into ss.tblItem_Pairs values (336,312,'') --Wheelchair Standard 16" [ 336 ]
		insert into ss.tblItem_Pairs values (337,312,'') --Wheelchair Standard 18" [ 337 ]
		insert into ss.tblItem_Pairs values (338,312,'') --Wheelchair Standard 20" [ 338 ]
		insert into ss.tblItem_Pairs values (339,312,'') --Wheelchair Standard 22" [ 339 ]
		insert into ss.tblItem_Pairs values (340,312,'') --Wheelchair Standard 24" [ 340 ]
		insert into ss.tblItem_Pairs values (746,312,'') --Wheelchair Standard 26" [ 746 ]
		insert into ss.tblItem_Pairs values (847,312,'') --Wheelchair Standard 28" [ 847 ]
		insert into ss.tblItem_Pairs values (848,312,'') --Wheelchair Standard 30" [ 848 ]
		insert into ss.tblItem_Pairs values (320,312,'') --Wheelchair Companion 16" [ 320 ]
		insert into ss.tblItem_Pairs values (321,312,'') --Wheelchair Companion 18" [ 321 ]
		insert into ss.tblItem_Pairs values (791,312,'') --Wheelchair companion 19" [ 791 ]
		insert into ss.tblItem_Pairs values (695,312,'') --Wheelchair companion 20" [ 695 ]
		insert into ss.tblItem_Pairs values (696,312,'') --Wheelchair companion 22" [ 696 ]

		--Sling: Canvas (Hole) [ 236 ] ( Paired with Lifts )
		insert into ss.tblItem_Pairs values (342,236,'') --Electric Patient Lift [ 342 ]
		insert into ss.tblItem_Pairs values (128,236,'') --Hoyer Lift [ 128 ]

		--Sling: Canvas [ 235 ] ( Paired with Lifts )
		insert into ss.tblItem_Pairs values (342,235,'') --Electric Patient Lift [ 342 ]
		insert into ss.tblItem_Pairs values (128,235,'') --Hoyer Lift [ 128 ]

		--Sling: Divided Leg [ 237 ] ( Paired with Lifts )
		insert into ss.tblItem_Pairs values (342,237,'') --Electric Patient Lift [ 342 ]
		insert into ss.tblItem_Pairs values (128,237,'') --Hoyer Lift [ 128 ]

		--Sling: Mesh (Hole) [ 239 ] ( Paired with Lifts )
		insert into ss.tblItem_Pairs values (342,239,'') --Electric Patient Lift [ 342 ]
		insert into ss.tblItem_Pairs values (128,239,'') --Hoyer Lift [ 128 ]

		--Sling: Mesh [ 238 ] ( Paired with Lifts )
		insert into ss.tblItem_Pairs values (342,238,'') --Electric Patient Lift [ 342 ]
		insert into ss.tblItem_Pairs values (128,238,'') --Hoyer Lift [ 128 ]

		--Sling: Nylon [ 240 ] ( Paired with Lifts )
		insert into ss.tblItem_Pairs values (342,240,'') --Electric Patient Lift [ 342 ]
		insert into ss.tblItem_Pairs values (128,240,'') --Hoyer Lift [ 128 ]

		--Mask: Full Face [ 150 ] ( Paired with BiPAP / CPAP )
		insert into ss.tblItem_Pairs values (28,150,'') --BiPAP ST Unit (Humidifier) [ 28 ]
		insert into ss.tblItem_Pairs values (27,150,'') --BiPAP ST Unit [ 27 ]
		insert into ss.tblItem_Pairs values (30,150,'') --BiPAP Unit (Humidifier) [ 30 ]
		insert into ss.tblItem_Pairs values (29,150,'') --BiPAP Unit [ 29 ]
		insert into ss.tblItem_Pairs values (55,150,'') --CPAP Unit [ 55 ]

		--O2 Backup Cart [ 175 ] ( Paired with Cylinders )
		insert into ss.tblItem_Pairs values (187,175,'') --O2: E Cylinder [ 187 ]

		--O2 Rack (12 bay) [ 183 ] ( Paired with Cylinders )
		insert into ss.tblItem_Pairs values (187,183,'') --O2: E Cylinder [ 187 ]
		insert into ss.tblItem_Pairs values (189,183,'') --O2: M-6 Cylinder [ 189 ]

		--O2 Rack (6 bay) [ 184 ] ( Paired with Cylinders )
		insert into ss.tblItem_Pairs values (187,184,'') --O2: E Cylinder [ 187 ]
		insert into ss.tblItem_Pairs values (189,184,'') --O2: M-6 Cylinder [ 189 ]

		--Commode: Bariatric [ 825 ] ( Paired with Beds )
		insert into ss.tblItem_Pairs values (838,825,'') --Bed: Bariatric [ 838 ]
		insert into ss.tblItem_Pairs values (795,825,'') --Bed: Full-Electric (Hospital Grade) [ 795 ]
		insert into ss.tblItem_Pairs values (25,825,'') --Bed: Full-Electric [ 25 ]
		insert into ss.tblItem_Pairs values (9,825,'') --Bed - Semi-Electric [ 9 ]
		
		--Commode: Bedside [ 47 ] ( Paired with Beds )
		insert into ss.tblItem_Pairs values (838,47,'') --Bed: Bariatric [ 838 ]
		insert into ss.tblItem_Pairs values (795,47,'') --Bed: Full-Electric (Hospital Grade) [ 795 ]
		insert into ss.tblItem_Pairs values (25,47,'') --Bed: Full-Electric [ 25 ]
		insert into ss.tblItem_Pairs values (9,47,'') --Bed - Semi-Electric [ 9 ]
		
		--Commode: Extra Wide [ 49 ] ( Paired with Beds )
		insert into ss.tblItem_Pairs values (838,49,'') --Bed: Bariatric [ 838 ]
		insert into ss.tblItem_Pairs values (795,49,'') --Bed: Full-Electric (Hospital Grade) [ 795 ]
		insert into ss.tblItem_Pairs values (25,49,'') --Bed: Full-Electric [ 25 ]
		insert into ss.tblItem_Pairs values (9,49,'') --Bed - Semi-Electric [ 9 ]

		--Small Volume Nebulizer [ 241 ] ( Paired with Concentrator )
		insert into ss.tblItem_Pairs values (50,241,'') --Concentrator 05 L [ 50 ]

		--Suction Machine (Continuous) [ 250 ] ( Paired with Concentrator )
		insert into ss.tblItem_Pairs values (50,250,'') --Concentrator 05 L [ 50 ]

		--Suction Machine (Intermittent) [ 251 ] ( Paired with Concentrator )
		insert into ss.tblItem_Pairs values (50,251,'') --Concentrator 05 L [ 50 ]

		update ss.tblItem_Pairs
		set sDescription = '[ ' + ltrim(rtrim(si.sName)) + ' ] paired with [ ' + ltrim(rtrim(mi.sName)) + ' ]'
		from ss.tblItem_Pairs as pair
		left join ss.tblItem as mi on mi.iItemID = pair.iIID_Main
		left join ss.tblItem as si on si.iItemID = pair.iIID_Sub

		--select * from ss.tblItem_Pairs
	End
/*----------------------------------------*\
|  End Paired Table Definition             |
\*----------------------------------------*/

declare @loop_step int
set @loop_step=1

while (@loop_step <= 3) --Loop for 3 months
begin --3 Month Loop begins

/*----------------------------------------*\
|  Bgn NON-Standard Reporting Window Call  |
\*----------------------------------------*/
begin
	--Time Window Vars to Get Standard Reporting Windows Date Ranges
	declare @cWindow as char(1), @iOffset as int, @iSummaryFlag as int
	set @cWindow = 'M' --'Y'early, 'Q'uarterly, 'M'onthly, 'W'eekly (Su-Sa), 'I'SO Week (Mo-Su), 'D'aily, 'B'i-Monthly
	set @iOffset = 1-@loop_step --0 for Last (day, week, etc) Negative for older reports, +1 is current time span
	set @iSummaryFlag = 0 --1 will force a 13 x window view for summary data lines.1 is current time span

	select 'Get what is Needed'
	declare @dS as datetime, @dE as datetime, @dOldest as datetime, @sTitle as varchar(32), @sLabel as char(10), @sInfo as varchar(64), @sVer varchar(8)

	select @dS = dS, @dE = dE, @sTitle = sTitle, @sLabel = sLblEnd, @dOldest = dOldest, @sInfo = sInfo, @sVer = sVer
	from reports_dev.dbo.fn_Report_DateRange(@cWindow,@iOffset,@iSummaryFlag,default,@dForced) --Window, Offset, Summary, Size, Date
	print @dS
	print @dE

	declare @smonth varchar(12)
	set @smonth=DATENAME(month ,@dS)
	print @smonth
	
	--set @loop_step=@loop_step+1
	--end
--	select @sTitle as Title, @dS as dStart, @dE as dEnd, @dOldest as dOldest, @sLabel as dLabel,
--	    @sInfo as info, @sVer as Ver
end
/*----------------------------------------
|  End NON-Standard Reporting Window Call  |
----------------------------------------*/

	--drop table ss.tblUSState --< in case we need to kill it...
	if not exists (select * from dbo.sysobjects where id = object_id(N'[ss].[tblUSState]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
		--Create New Temp Table
		CREATE TABLE ss.tblUSState (
			iRGN int,
			sState char(2),
			sRegion char(10)
		)  ON [PRIMARY]

		insert into ss.tblUSState  values (-1,'DE','DE: Region')
		insert into ss.tblUSState  values (-2,'NJ','NJ: Region')
		insert into ss.tblUSState  values (-3,'PA','PA: Region')
		insert into ss.tblUSState  values (-4,'GA','GA: Region')
		insert into ss.tblUSState  values (-5,'CT','CT: Region')
		insert into ss.tblUSState  values (-6,'MA','MA: Region')
		insert into ss.tblUSState  values (-7,'MD','MD: Region')
		insert into ss.tblUSState  values (-8,'SC','SC: Region')
		insert into ss.tblUSState  values (-9,'NH','NH: Region')
		insert into ss.tblUSState  values (-10,'VA','VA: Region')
		insert into ss.tblUSState  values (-11,'NY','NY: Region')
		insert into ss.tblUSState  values (-12,'NC','NC: Region')
		insert into ss.tblUSState  values (-13,'RI','RI: Region')
		insert into ss.tblUSState  values (-14,'VT','VT: Region')
		insert into ss.tblUSState  values (-15,'KY','KY: Region')
		insert into ss.tblUSState  values (-16,'TN','TN: Region')
		insert into ss.tblUSState  values (-17,'OH','OH: Region')
		insert into ss.tblUSState  values (-18,'LA','LA: Region')
		insert into ss.tblUSState  values (-19,'IN','IN: Region')
		insert into ss.tblUSState  values (-20,'MS','MS: Region')
		insert into ss.tblUSState  values (-21,'IL','IL: Region')
		insert into ss.tblUSState  values (-22,'AL','AL: Region')
		insert into ss.tblUSState  values (-23,'ME','ME: Region')
		insert into ss.tblUSState  values (-24,'MO','MO: Region')
		insert into ss.tblUSState  values (-25,'AR','AR: Region')
		insert into ss.tblUSState  values (-26,'MI','MI: Region')
		insert into ss.tblUSState  values (-27,'FL','FL: Region')
		insert into ss.tblUSState  values (-28,'TX','TX: Region')
		insert into ss.tblUSState  values (-29,'IA','IA: Region')
		insert into ss.tblUSState  values (-30,'WI','WI: Region')
		insert into ss.tblUSState  values (-31,'CA','CA: Region')
		insert into ss.tblUSState  values (-32,'MN','MN: Region')
		insert into ss.tblUSState  values (-33,'OR','OR: Region')
		insert into ss.tblUSState  values (-34,'KS','KS: Region')
		insert into ss.tblUSState  values (-35,'WV','WV: Region')
		insert into ss.tblUSState  values (-36,'NV','NV: Region')
		insert into ss.tblUSState  values (-37,'NE','NE: Region')
		insert into ss.tblUSState  values (-38,'CO','CO: Region')
		insert into ss.tblUSState  values (-39,'ND','ND: Region')
		insert into ss.tblUSState  values (-40,'SD','SD: Region')
		insert into ss.tblUSState  values (-41,'MT','MT: Region')
		insert into ss.tblUSState  values (-42,'WA','WA: Region')
		insert into ss.tblUSState  values (-43,'ID','ID: Region')
		insert into ss.tblUSState  values (-44,'WY','WY: Region')
		insert into ss.tblUSState  values (-45,'UT','UT: Region')
		insert into ss.tblUSState  values (-46,'OK','OK: Region')
		insert into ss.tblUSState  values (-47,'NM','NM: Region')
		insert into ss.tblUSState  values (-48,'AZ','AZ: Region')
		insert into ss.tblUSState  values (-49,'AK','AK: Region')
		insert into ss.tblUSState  values (-50,'HI','HI: Region')
		insert into ss.tblUSState  values (-51,'DC','DC: Region')
	End

	declare @iYYYYMM as int = year(@dS) * 100 + month(@dS)

	declare @tDyad as table (iBUID int, iCID int, iSID int, iBgn int, iEnd int)
	insert into @tDyad
	select iBudgetID, iClientRef, iSiteRef, iBgnYYYYMM, iEndYYYYMM
	from ss.tblBudget as bu
	join (
		select iLocationID as iSID from ss.tblLocation where iCompanyRef = isnull(@iDME,iCompanyRef) and cType = 'S'
	) as s on s.iSID = bu.iSiteRef
	join (
		select iLocationID as iCID from ss.tblLocation where iCompanyRef = isnull(@iHOS,iCompanyRef) and cType = 'C'
	) as c on c.iCID = bu.iClientRef
	where bu.iBgnYYYYMM <= @iYYYYMM
	and isnull(bu.iEndYYYYMM, 299913) >= @iYYYYMM
	and isnull(bu.iIPURef,0) = 0
	and bu.iClientRef = isnull(@iCID, bu.iClientRef)
	and bu.iSiteRef = isnull(@iSID, bu.iSiteRef)

	declare @dReDeliveryStart as datetime
	set @dReDeliveryStart = DATEADD(d,-1*@iDays,@dS)

	if @iDebug = 1 begin
		select @dReDeliveryStart as [Prior Date], @dS as [Start Date], @dE as [End Date], @sTitle as [Title]
	end

	Declare @tmpRpt_Redelivery_Raw TABLE (
		iOID int NOT NULL,
		iPID int NOT NULL,
		iDriverID int NOT NULL,
		iRouteNumber int NOT NULL,
		dComplete datetime NOT NULL,
		cReason char(1) NULL
	)

	insert into @tmpRpt_Redelivery_Raw
	select iOrderID, iPatientID, isnull(iDriverID,0), isnull(iRouteNumber,0), dtCompleted, cReason
	from ss.tblOrder as o 
	where iPatientID in (
		select iPatientID from ss.tblPatient as p
		join @tDyad as dy on dy.iSID = p.iSiteRef and dy.iCID = p.iClientRef
		where cType <> 'M'
	) 
	and dtCompleted >= @dReDeliveryStart and dtCompleted <= @dE --Time Window = Date of ReDeliveryStart to end of Window

/*-------------------------------------------------*\
| DEBUG BLOCK - Used to test logic
| Month = 2015/08, DME = 2, HOS = 120
| 1) Confirm Completed Date is used on Pre Order
\*-------------------------------------------------*/
--==[ 1 ]==--
if @iDebugStep_Bgn >= 1 begin
	if @iDebugStep_End <= 1 begin
		select 'Step 1' as info, 'Check for Network Order on dtCompleted' as note
		select 'Step 1' as info, 'DATA CHANGE IN PROGRESS' as note
		select top 10 'Pre Edit' as info, * from @tmpRpt_Redelivery_Raw as p where p.iPID = 231996 and p.dComplete <= '2015-08-17 16:42:00.000' order by dComplete desc, iOID
		update @tmpRpt_Redelivery_Raw set dComplete = '2015-08-17 16:42:00.000' where iOID = 1925016
		update @tmpRpt_Redelivery_Raw set dComplete = '2015-08-17 16:42:00.000' where iOID = 1948290
		update @tmpRpt_Redelivery_Raw set dComplete = '2015-08-17 16:42:00.000' where iOID = 1953380
		select top 10 'Post Edit' as info, * from @tmpRpt_Redelivery_Raw as p where p.iPID = 231996 and p.dComplete <= '2015-08-17 16:42:00.000' order by dComplete desc, iOID
	end
end

	Declare @tmpRpt_Redelivery_Pre TABLE (
		iSID int null,
		iCID int null,
		iOID int NOT NULL,
		iPID int NOT NULL,
		iDriverID int NOT NULL,
		iRouteNumber int NOT NULL,
		dComplete datetime NOT NULL,
		cReason char(1) NULL,
		iPreOID int NULL,
		iPreDriverID int NULL,
		iPreRouteNumber int NULL,
		dPreComplete datetime NULL,
		cPreReason char(1) NULL,
		iRedelivery int NOT NULL,
		iRedeliveryProductCnt int NULL,
		iHours int NULL,
		sNote varchar(10) NULL,
		iCntDME int null,
		iCntO2 int null,
		iCntDisp int null,
		iCntPickup int null,
		iCntService int null,
		iCntPaired int null,
		sBadPreOID varchar(255) null,
		sBadNote varchar(255) null,
		iBadPreCnt int null
	)

	Insert into @tmpRpt_Redelivery_Pre (iOID, iPID, iDriverID, iRouteNumber, dComplete, cReason, iPreOID, iRedelivery)
	select x.iOID, x.iPID, x.iDriverID, x.iRouteNumber, x.dComplete, x.cReason,
		(	
			select top 1 iOID 
			from @tmpRpt_Redelivery_Raw as p 
			where p.iPID = x.iPID and p.dComplete <= x.dComplete and p.iOID <> x.iOID
			order by dComplete desc, iOID
		) as iPreOID, 1
	from @tmpRpt_Redelivery_Raw as x
	order by dComplete 

	if @iDebugStep_Bgn >= 1 begin
		if @iDebugStep_End <= 1 begin
			select 'Step 1' as info, 'Orders Made it from Raw to Pre' as note
			select 's:01:InsertPre' as info, * from @tmpRpt_Redelivery_Pre as r
		end
	end
	if @iDebug = 1 begin
		if @iOID_Debug is not null begin
			select 'OID:01:InsertPre' as label, * from @tmpRpt_Redelivery_Pre where iOID = @iOID_Debug
		end
		if isnull(@iPID_Debug,0) <> 0 begin
			select 'PID:01:InsertRaw' as info, * from @tmpRpt_Redelivery_Pre as p where iPID = @iPID_Debug order by dComplete 
		End	
	end 

	update @tmpRpt_Redelivery_Pre
	set iPreDriverID = r.iDriverID,
		iPreRouteNumber = r.iRouteNumber,
		dPreComplete = r.dComplete,
		cPreReason = r.cReason
	from @tmpRpt_Redelivery_Pre as p
	join @tmpRpt_Redelivery_Raw as r on p.iPreOID = r.iOID 

	if @iDebugStep_Bgn >= 2 begin
		if @iDebugStep_End <= 2 begin
			select 's:02:UpdatePreOrder' as info, * from @tmpRpt_Redelivery_Pre as p
		end
	end
	if @iDebug = 1 begin
		if @iOID_Debug is not null begin
			select 'OID:02:UpdatePreOrder' as label, * from @tmpRpt_Redelivery_Pre where iOID = @iOID_Debug
		end
		if isnull(@iPID_Debug,0) <> 0 begin
			select 'PID:02:UpdatePreOrder' as info, * from @tmpRpt_Redelivery_Pre as p where iPID = @iPID_Debug order by dComplete 
		End	
	end 
	
	update @tmpRpt_Redelivery_Pre set
		iSID = p.iSiteRef,
		iCID = p.iClientRef
	from @tmpRpt_Redelivery_Pre as rd
	join ss.tblPatient as p on p.iPatientID = rd.iPID 

	if @iDebugStep_Bgn >= 3 begin
		if @iDebugStep_End <= 3 begin
			select 'Step 3' as info, 'Cross link with patient data to get CID and SID Data' as note
			select 's:03:UpdateSID_CID' as info, * from @tmpRpt_Redelivery_Pre as r
		end
	end
	if @iDebug = 1 begin
		if @iOID_Debug is not null begin
			select 'OID:03:UpdateSID_CID' as label, * from @tmpRpt_Redelivery_Pre where iOID = @iOID_Debug
		end
		if isnull(@iPID_Debug,0) <> 0 begin
			select 'PID:03:UpdateSID_CID' as info, * from @tmpRpt_Redelivery_Pre as p where iPID = @iPID_Debug order by dComplete 
		End	
	end 

	if @iDebugStep_Bgn >= 4 begin
		if @iDebugStep_End <= 4 begin
			if isnull(@iOID_Debug,0) <> 0 begin
				select 'Step 4' as info, 'Get Item Count Data for Orders' as note
			end
		end
	end
	update @tmpRpt_Redelivery_Pre set
		iCntPickup = (isnull((
			select SUM(1) as iCnt from ss.tblOrderDetail where iReferenceOrderID = iOID
		),0))

	if @iDebugStep_Bgn >= 4 begin
		if @iDebugStep_End <= 4 begin
			if isnull(@iOID_Debug,0) <> 0 begin
				insert into @tOrderBuckets
				select 'PID:04:Pickup' as info, iOID, iCntDME, iCntO2, iCntDisp, iCntPickup, iCntService, iCntPaired from @tmpRpt_Redelivery_Pre as p where iOID = @iOID_Debug
			end
		end
	end

	update @tmpRpt_Redelivery_Pre set
		iCntDisp = (isnull((
			select SUM(1) as iCnt from ss.tblOrderDetail as od
			join ss.tblProductEquip as pe on pe.iProductRef = od.iProductID
			join ss.tblEquipment as e on e.iEquipmentID = pe.iEquipmentRef
			left join ss.setClientEquipList as ce on ce.iEquipmentRef = pe.iEquipmentRef and ce.iClientRef = iCID and ce.iSiteRef = iSID
			where iOrderID = iOID
			and isnull(ce.bDisposable, e.bDisposable) = 1
			and isnull(ce.iItemRef, e.iItemRef) not in (147,794,  227,796,797, 89,308,764, 295,296)
		),0))

	if @iDebugStep_Bgn >= 4 begin
		if @iDebugStep_End <= 4 begin
			if isnull(@iOID_Debug,0) <> 0 begin
				insert into @tOrderBuckets
				select 'PID:04:Disp' as info, iOID, iCntDME, iCntO2, iCntDisp, iCntPickup, iCntService, iCntPaired from @tmpRpt_Redelivery_Pre as p where iOID = @iOID_Debug
			end
		end
	end

	update @tmpRpt_Redelivery_Pre set
		iCntService = (isnull((
			select SUM(1) as iCnt from ss.tblOrderDetail as od
			join ss.tblProductEquip as pe on pe.iProductRef = od.iProductID
			join ss.tblEquipment as e on e.iEquipmentID = pe.iEquipmentRef
			left join ss.setClientEquipList as ce on ce.iEquipmentRef = pe.iEquipmentRef and ce.iClientRef = iCID and ce.iSiteRef = iSID
			where iOrderID = iOID
			and isnull(ce.bDisposable, e.bDisposable) = 1
			and isnull(ce.iItemRef, e.iItemRef) in (227)
		),0))

	if @iDebugStep_Bgn >= 4 begin
		if @iDebugStep_End <= 4 begin
			if isnull(@iOID_Debug,0) <> 0 begin
				insert into @tOrderBuckets
				select 'PID:04:Service' as info, iOID, iCntDME, iCntO2, iCntDisp, iCntPickup, iCntService, iCntPaired from @tmpRpt_Redelivery_Pre as p where iOID = @iOID_Debug
			end
		end
	end

	update @tmpRpt_Redelivery_Pre set
		iCntO2 = (isnull((
			select SUM(1) as iCnt from ss.tblOrderDetail as od
			join ss.tblProductEquip as pe on pe.iProductRef = od.iProductID
			join ss.tblEquipment as e on e.iEquipmentID = pe.iEquipmentRef
			left join ss.setClientEquipList as ce on ce.iEquipmentRef = pe.iEquipmentRef and ce.iClientRef = iCID and ce.iSiteRef = iSID
			where iOrderID = iOID
			and isnull(ce.bOxygen, e.bOxygen) = 1
		),0))
	if @iDebugStep_Bgn >= 4 begin
		if @iDebugStep_End <= 4 begin
			if isnull(@iOID_Debug,0) <> 0 begin
				insert into @tOrderBuckets
				select 'PID:04:O2{main}' as info, iOID, iCntDME, iCntO2, iCntDisp, iCntPickup, iCntService, iCntPaired from @tmpRpt_Redelivery_Pre as p where iOID = @iOID_Debug
			end
		end
	end

	update @tmpRpt_Redelivery_Pre set
		iCntO2 = iCntO2 + (isnull((
			select SUM(1) as iCnt from ss.tblOrderDetail as od
			join ss.tblProductEquip as pe on pe.iProductRef = od.iProductID
			join ss.tblEquipment as e on e.iEquipmentID = pe.iEquipmentRef
			left join ss.setClientEquipList as ce on ce.iEquipmentRef = pe.iEquipmentRef and ce.iClientRef = iCID and ce.iSiteRef = iSID
			where iOrderID = iOID
			and isnull(ce.bDisposable, e.bDisposable) = 1
			and isnull(ce.iItemRef, e.iItemRef) in (147,794)
		),0))

	if @iDebugStep_Bgn >= 4 begin
		if @iDebugStep_End <= 4 begin
			if isnull(@iOID_Debug,0) <> 0 begin
				insert into @tOrderBuckets
				select 'PID:04:O2{+disp}' as info, iOID, iCntDME, iCntO2, iCntDisp, iCntPickup, iCntService, iCntPaired from @tmpRpt_Redelivery_Pre as p where iOID = @iOID_Debug
			end
		end
	end

	update @tmpRpt_Redelivery_Pre set 
		iCntO2 = iCntO2 + (isnull((
			select SUM(1) as iCnt from ss.tblOrderDetail as od
			join ss.tblProductEquip as pe on pe.iProductRef = od.iProductID
			where iOrderID = iOID
			and pe.iEquipmentRef = 8734
		),0))

	if @iDebugStep_Bgn >= 4 begin
		if @iDebugStep_End <= 4 begin
			if isnull(@iOID_Debug,0) <> 0 begin
				insert into @tOrderBuckets
				select 'PID:04:O2{+eq}' as info, iOID, iCntDME, iCntO2, iCntDisp, iCntPickup, iCntService, iCntPaired from @tmpRpt_Redelivery_Pre as p where iOID = @iOID_Debug
			end
		end
	end

	update @tmpRpt_Redelivery_Pre set
		iCntDME = (isnull((
			select SUM(1) as iCnt from ss.tblOrderDetail as od
			join ss.tblProductEquip as pe on pe.iProductRef = od.iProductID
			join ss.tblEquipment as e on e.iEquipmentID = pe.iEquipmentRef
			left join ss.setClientEquipList as ce on ce.iEquipmentRef = pe.iEquipmentRef and ce.iClientRef = iCID and ce.iSiteRef = iSID
			where iOrderID = iOID
			and cast(isnull(ce.bOxygen, e.bOxygen) as int) + cast(isnull(ce.bDisposable, e.bDisposable) as int) = 0
			and isnull(ce.iEquipmentRef, e.iEquipmentID) not in (8734)
		),0))
	if @iDebugStep_Bgn >= 4 begin
		if @iDebugStep_End <= 4 begin
			if isnull(@iOID_Debug,0) <> 0 begin
				insert into @tOrderBuckets
				select 'PID:04:DME' as info, iOID, iCntDME, iCntO2, iCntDisp, iCntPickup, iCntService, iCntPaired from @tmpRpt_Redelivery_Pre as p where iOID = @iOID_Debug
				select * from @tOrderBuckets
				select od.iOrderID as iOID, iOrderDetailID as iODID, iProductID as iPrID, e.iEquipmentID as iEID, e.sName as sEquipment, 
					i.iItemID as iIID, i.sName as sItem, i.iCategoryRef as iCat, case when isnull(ce.iEquipmentRef, e.iEquipmentID) is null then 'Equ' else 'CEL' end as sSorce,
					isnull(ce.bDisposable, e.bDisposable) as bDisposable, isnull(ce.bOxygen, e.bOxygen) as bOxygen,
					case when od.iOrderID = @iOID_Debug then 'Del' else 'PU' end as DP,
					
					case when od.iReferenceOrderID = @iOID_Debug then 'Pickup' else ( --Is a Pickup
						case when isnull(ce.bDisposable, e.bDisposable) = 1 then ( 
							case i.iItemID
								when 147 then 'O2+'
								when 794 then 'O2+'
								when 227 then 'Service'
								when 796 then 'NA'
								when 797 then 'NA'
								when  89 then 'NA'
								when 308 then 'NA'
								when 764 then 'NA'
								when 295 then 'NA'
								when 296 then 'NA'
								else (
									case 
										when e.iEquipmentID = 8734 then 'O2'
										else 'Disp' 
									end
								)
							end
						) else (
							case when isnull(ce.bOxygen, e.bOxygen) = 1 then  
								'O2'
							else
								'DME'
							end
						) end
					) end as 'sType'
				from ss.tblOrderDetail as od
				join ss.tblOrder as o on o.iOrderID = od.iOrderID
				join ss.tblPatient as p on p.iPatientID = o.iPatientID
				join ss.tblProductEquip as pe on pe.iProductRef = od.iProductID
				join ss.tblEquipment as e on e.iEquipmentID = pe.iEquipmentRef
				join ss.tblItem as i on i.IItemID = e.iItemRef
				left join ss.setClientEquipList as ce on ce.iEquipmentRef = pe.iEquipmentRef and ce.iClientRef = p.iClientRef and ce.iSiteRef = p.iSiteRef
				where od.iOrderID = @iOID_Debug
				or od.iReferenceOrderID = @iOID_Debug
			end
			select iOrderID, iItemRef, sum(1) as xCnt from ss.tblOrderDetail as od 
			join ss.tblProductEquip as pe on pe.iProductRef = od.iProductID
			join ss.tblEquipment as e on e.iEquipmentID = pe.iEquipmentRef
			where od.iOrderID in (select distinct iOID from @tmpRpt_Redelivery_Raw)
			and iItemRef in (147, 794, 227, 796, 797, 89, 308, 764, 295, 296)
			group by iOrderID, iItemRef
		end
	end

	update @tmpRpt_Redelivery_Pre set
		iCntPaired = (isnull((
			select SUM(1) as iCnt from ss.tblOrderDetail 
			where iProductID in (
				select iProductRef from ss.tblProductEquip where iEquipmentRef in (
					select iEquipmentID from ss.tblEquipment 
					where iItemRef in (
						select distinct iIID_Sub from ss.tblItem_Pairs
					)
					and iCompanyRef in (
						select distinct iCompanyRef from ss.tblLocation where iLocationID in (
							select iSID from @tDyad
						)
					)
				)
			)
			and iOrderID = iOID
		),0))

	
	if @iDebugStep_Bgn >= 4 begin
		if @iDebugStep_End <= 4 begin
			if isnull(@iOID_Debug,0) <> 0 begin
				insert into @tOrderBuckets
				select 'PID:04:Paired' as info, iOID, iCntDME, iCntO2, iCntDisp, iCntPickup, iCntService, iCntPaired from @tmpRpt_Redelivery_Pre as p where iOID = @iOID_Debug
			end
		end
	end

	--Now have counts of items:
	--    DME = Rental DME Items, not grouped into the below groups.
	--     O2 = ce.bOxygen = 1 or {ce.bDisposable = 1 and item in (Liquid O2 Refill [147], O2 Kits [794])}
	--   Disp = ce.bDisposable = 1 and item not (Liquid O2 Refill [147], O2 Kits [794], Service Call [227], Service Charge [796], Setup Fee [797], Non-Billable Items [89,308,764], Trip Charges [295,296])
	-- Pickup = Count of ANY Product with a iReferenceOrderID link to this order.
	--Service = ce.bDisposable = 1 and item in (Service Call [227])
	-- Paired = number of paired items from ss.tblItem_Paired that are in this order
	--Not be default there is a Hidden non counted group of items that fall into this selection...
	-- Hidden = ce.bDisposable = 1 and item in (Service Charge [796], Setup Fee [797], Non-Billable Items [89,308,764], Trip Charges [295,296])
	-- These are non-items and not counted as O2 only, Pickup Only or Service Call

	if @iDebugStep_Bgn >= 4 begin
		if @iDebugStep_End <= 4 begin
			if isnull(@iPID_Debug,0) <> 0 begin
				select 'PID:04' as info, sNote, * from @tmpRpt_Redelivery_Pre as p where iPID = @iPID_Debug order by dComplete 
			end
		end
	end

	update @tmpRpt_Redelivery_Pre
	set sNote = 'PickupOnly', 
		iRedelivery = 0
	where iRedelivery = 1
	and iCntDME + iCntO2 + iCntDisp + iCntService = 0 
	and iCntPickup > 0

	if @iDebugStep_Bgn >= 5 begin
		if @iDebugStep_End <= 5 begin
			select 's:05:PickupOnly' as info, * from @tmpRpt_Redelivery_Pre as p where sNote = 'PickupOnly'
		end
	end
	if @iDebug = 1 begin
		if @iOID_Debug is not null begin
			select 'OID:05:PickupOnly' as label, sNote, * from @tmpRpt_Redelivery_Pre where iOID = @iOID_Debug
		end
		if isnull(@iPID_Debug,0) <> 0 begin
			select 'PID:05:PickupOnly' as info, sNote, * from @tmpRpt_Redelivery_Pre as p where iPID = @iPID_Debug order by dComplete 
		End	
	end 

	update @tmpRpt_Redelivery_Pre
	set sNote = 'NoDetails', 
		iRedelivery = 0
	where iRedelivery = 1
	and iCntDME + iCntO2 + iCntDisp + iCntPickup + iCntService = 0

	if @iDebugStep_Bgn >= 6 begin
		if @iDebugStep_End <= 6 begin
			select 's:06:NoDetails' as info, * from @tmpRpt_Redelivery_Pre as p where sNote = 'NoDetails'
		end
	end
	if @iDebug = 1 begin
		if @iOID_Debug is not null begin
			select 'OID:06:NoDetails' as label, sNote, * from @tmpRpt_Redelivery_Pre where iOID = @iOID_Debug
		end
		if isnull(@iPID_Debug,0) <> 0 begin
			select 'PID:06:NoDetails' as info, sNote, * from @tmpRpt_Redelivery_Pre as p where iPID = @iPID_Debug order by dComplete 
		End	
	end 
	
	update @tmpRpt_Redelivery_Pre
	set sNote = 'StandingO2', 
		iRedelivery = 0
	where iRedelivery = 1
	and iCntO2 > 0 
	and iCntDME = 0

	if @iDebugStep_Bgn >= 7 begin
		if @iDebugStep_End <= 7 begin
			select 's:07:StandingO2' as info, * from @tmpRpt_Redelivery_Pre as p where sNote = 'StandingO2'
		end
	end
	if @iDebug = 1 begin
		if @iOID_Debug is not null begin
			select 'OID:07:StandingO2' as label, sNote, * from @tmpRpt_Redelivery_Pre where iOID = @iOID_Debug
		end
		if isnull(@iPID_Debug,0) <> 0 begin
			select 'PID:07:StandingO2' as info, sNote, * from @tmpRpt_Redelivery_Pre as p where iPID = @iPID_Debug order by dComplete 
		End	
	end 
	
	update @tmpRpt_Redelivery_Pre
	set sNote = 'Service', 
		iRedelivery = 0
	where iRedelivery = 1
	and iCntService > 0 

	if @iDebugStep_Bgn >= 8 begin
		if @iDebugStep_End <= 8 begin
			select 's:08:Service' as info, * from @tmpRpt_Redelivery_Pre as p where sNote = 'Service'
		end
	end
	if @iDebug = 1 begin
		if @iOID_Debug is not null begin
			select 'OID:08:Service' as label, sNote, * from @tmpRpt_Redelivery_Pre where iOID = @iOID_Debug
		end
		if isnull(@iPID_Debug,0) <> 0 begin
			select 'PID:08:Service' as info, sNote, * from @tmpRpt_Redelivery_Pre as p where iPID = @iPID_Debug order by dComplete 
		End
	end 


	declare @iCntShiftRecords as int
	select @iCntShiftRecords = SUM(1)
	from @tmpRpt_Redelivery_Pre as p
	join (select * from @tmpRpt_Redelivery_Pre) as x on p.iPreOID = x.iOID 
	where x.iRedelivery = 0
	select @iCntShiftRecords = ISNULL(@iCntShiftRecords,0)
	declare @iLoopCnt int = 1
	while @iCntShiftRecords <> 0 begin
	
		update @tmpRpt_Redelivery_Pre set 
			sBadPreOID = left(isnull(p.sBadPreOID,'') + case when len(isnull(p.sBadPreOID,'')) <> 0 then ', ' else '' end + CAST(p.iPreOID as varchar(16)),255),
			sBadNote = LEFT(isnull(p.sBadNote,'') + case when len(isnull(p.sBadNote,'')) <> 0 then ', ' else '' end + p.sNote,255)
		from @tmpRpt_Redelivery_Pre as p
		join (select * from @tmpRpt_Redelivery_Pre) as x on p.iPreOID = x.iOID 
		where x.iRedelivery = 0

		update @tmpRpt_Redelivery_Pre set 
			iPreOID = x.iPreOID,
			iPreDriverID = x.iPreDriverID,
			iPreRouteNumber = x.iPreRouteNumber,
			dPreComplete = x.dPreComplete,
			cPreReason = x.cPreReason,
			iBadPreCnt = isnull(p.iBadPreCnt,0) + 1
		from @tmpRpt_Redelivery_Pre as p
		join (select * from @tmpRpt_Redelivery_Pre) as x on p.iPreOID = x.iOID 
		where x.iRedelivery = 0

		update @tmpRpt_Redelivery_Pre set 
			iRedelivery = -1
		from @tmpRpt_Redelivery_Pre as p
		join (select * from @tmpRpt_Redelivery_Pre) as x on p.iPreOID = x.iOID 
		where p.iPreOID = x.iPreOID 
		
		if @iDebugStep_Bgn >= 9 begin
			if @iDebugStep_End <= 9 begin
				select 's:09:D:' + cast(iBadPreCnt as varchar(4)) as i, iOID, iPID, iPreOID, sBadPreOID, sBadNote, iReDelivery, * 
				from @tmpRpt_Redelivery_Pre as p 
				where iOID = @iOID_Debug
				and iBadPreCnt = @iLoopCnt
			end
		end

		select @iCntShiftRecords = SUM(1), @iLoopCnt = @iLoopCnt + 1
		from @tmpRpt_Redelivery_Pre as p
		join (select * from @tmpRpt_Redelivery_Pre) as x on p.iPreOID = x.iOID 
		where x.iRedelivery = 0 and p.iOID <> p.iPreOID 
		select @iCntShiftRecords = ISNULL(@iCntShiftRecords,0) --Drop nulls
	end

	if @iDebugStep_Bgn >= 9 begin
		if @iDebugStep_End <= 9 begin
			select 's:09:AfterSHIFTING' as info, * from @tmpRpt_Redelivery_Pre as p where sBadPreOID is not null
		end
	end
	if @iDebug = 1 begin
		if @iOID_Debug is not null begin
			select 'OID:09:AfterSHIFTING' as label, sNote, * from @tmpRpt_Redelivery_Pre where iOID = @iOID_Debug
		end
		if isnull(@iPID_Debug,0) <> 0 begin
			select 'PID:09:AfterSHIFTING' as info, sNote, * from @tmpRpt_Redelivery_Pre as p where iPID = @iPID_Debug order by dComplete 
		End
	end 

	update @tmpRpt_Redelivery_Pre
	set sNote = 'NoValidPre', 
		iRedelivery = 0
	where iRedelivery = -1
	update @tmpRpt_Redelivery_Pre
	set sNote = 'NoValidPre', 
		iRedelivery = 0
	where iOID = iPreOID 
	if @iDebugStep_Bgn >= 10 begin
		if @iDebugStep_End <= 10 begin
			select 's:10:NoValidPre' as info, * from @tmpRpt_Redelivery_Pre as p where sNote = 'NoValidPre'
		end
	end
	if @iDebug = 1 begin
		if @iOID_Debug is not null begin
			select 'OID:10:NoValidPre' as label, sNote, * from @tmpRpt_Redelivery_Pre where iOID = @iOID_Debug
		end
		if isnull(@iPID_Debug,0) <> 0 begin
			select 'PID:10:NoValidPre' as info, sNote, * from @tmpRpt_Redelivery_Pre as p where iPID = @iPID_Debug order by dComplete 
		End
	end 

	update @tmpRpt_Redelivery_Pre
	set iHours = DATEDIFF(MINUTE,isnull(dPreComplete,dComplete),dComplete),
		iRedeliveryProductCnt = 0

	if @iDebugStep_Bgn >= 11 begin
		if @iDebugStep_End <= 11 begin
			select 's:11:PriorHrs' as info, * from @tmpRpt_Redelivery_Pre as p where isnull(iHours,-69) <> -69
		end
	end
	if @iDebug = 1 begin
		if @iOID_Debug is not null begin
			select 'OID:11:PriorHrs' as label, sNote, * from @tmpRpt_Redelivery_Pre where iOID = @iOID_Debug
		end
		if isnull(@iPID_Debug,0) <> 0 begin
			select 'PID:11:PriorHrs' as info, sNote, * from @tmpRpt_Redelivery_Pre as p where iPID = @iPID_Debug order by dComplete 
		End
	end 

	update @tmpRpt_Redelivery_Pre
	set sNote = 'NoPreOrd', 
		iRedelivery = 0
	where iPreRouteNumber is null
		and iRedelivery = 1

	if @iDebugStep_Bgn >= 12 begin
		if @iDebugStep_End <= 12 begin
			select 's:12:NoPreOrd' as info, * from @tmpRpt_Redelivery_Pre as p where sNote = 'NoPreOrd'
		end
	end
	if @iDebug = 1 begin
		if @iOID_Debug is not null begin
			select 'OID:12:NoPreOrd' as label, sNote, * from @tmpRpt_Redelivery_Pre where iOID = @iOID_Debug
		end
		if isnull(@iPID_Debug,0) <> 0 begin
			select 'PID:12:NoPreOrd' as info, sNote, * from @tmpRpt_Redelivery_Pre as p where iPID = @iPID_Debug order by dComplete 
		End
	end 

	update @tmpRpt_Redelivery_Pre
	set sNote = 'GT>Days', 
		iRedelivery = 0
	where iHours > @iDays * 24 * 60
		and iRedelivery = 1

	if @iDebugStep_Bgn >= 13 begin
		if @iDebugStep_End <= 13 begin
			select 's:13:GT>Days' as info, * from @tmpRpt_Redelivery_Pre as p where sNote = 'GT>Days'
		end
	end
	if @iDebug = 1 begin
		if @iOID_Debug is not null begin
			select 'OID:13:GT>Days' as label, sNote, * from @tmpRpt_Redelivery_Pre where iOID = @iOID_Debug
		end
		if isnull(@iPID_Debug,0) <> 0 begin
			select 'PID:13:GT>Days' as info, sNote, * from @tmpRpt_Redelivery_Pre as p where iPID = @iPID_Debug order by dComplete 
		End
	end 

	update @tmpRpt_Redelivery_Pre
	set sNote = 'SameStop', 
		iRedelivery = 0
	where iHours = 0 and iDriverID = iPreDriverID and iRouteNumber = iPreRouteNumber 
		and iRedelivery = 1

	if @iDebugStep_Bgn >= 14 begin
		if @iDebugStep_End <= 14 begin
			select 's:14:SameStop' as info, * from @tmpRpt_Redelivery_Pre as p where sNote = 'SameStop'
		end
	end
	if @iDebug = 1 begin
		if @iOID_Debug is not null begin
			select 'OID:14:SameStop' as label, sNote, * from @tmpRpt_Redelivery_Pre where iOID = @iOID_Debug
		end
		if isnull(@iPID_Debug,0) <> 0 begin
			select 'PID:14:SameStop' as info, sNote, * from @tmpRpt_Redelivery_Pre as p where iPID = @iPID_Debug order by dComplete 
		End
	end 
	
	update @tmpRpt_Redelivery_Pre
	set sNote = 'SameRoute', 
		iRedelivery = 0
	where iHours < 1440 and iDriverID = iPreDriverID and iRouteNumber = iPreRouteNumber 
		and YEAR(dComplete) * 10000 + MONTH(dComplete) * 100 + DAY(dComplete) = 
		YEAR(dpreComplete) * 10000 + MONTH(dpreComplete) * 100 + DAY(dPreComplete)
		and iRedelivery = 1
	
	if @iDebugStep_Bgn >= 15 begin
		if @iDebugStep_End <= 15 begin
			select 's:15:SameRoute' as info, * from @tmpRpt_Redelivery_Pre as p where sNote = 'SameRoute'
		end
	end
	if @iDebug = 1 begin
		if @iOID_Debug is not null begin
			select 'OID:15:SameRoute' as label, sNote, * from @tmpRpt_Redelivery_Pre where iOID = @iOID_Debug
		end
		if isnull(@iPID_Debug,0) <> 0 begin
			select 'PID:15:SameRoute' as info, sNote, * from @tmpRpt_Redelivery_Pre as p where iPID = @iPID_Debug order by dComplete 
		End
	end 

	update @tmpRpt_Redelivery_Pre
	set iRedelivery = 2
	where iPreOID in (
		select iPreOID from (
			select iPreOID, SUM(1) as  xCnt
			from @tmpRpt_Redelivery_Pre
			where iRedelivery = 1
			group by iPreOID
		) as x
		where x.iPreOID is not null
		and x.xCnt > 1
	)

	Declare @tmpRpt_FirstDupOrder TABLE (
		iMinOID int NOT NULL
	)
	insert into @tmpRpt_FirstDupOrder
	select min(iOID) from @tmpRpt_Redelivery_Pre
	where iPreOID in (
		select iPreOID from (
			select iPreOID, SUM(1) as  xCnt
			from @tmpRpt_Redelivery_Pre
			where iRedelivery = 1
			group by iPreOID
		) as x
		where x.iPreOID is not null
		and x.xCnt > 1
	) 
	group by iPreOID

	update @tmpRpt_Redelivery_Pre
	set iRedelivery = 1
	where iOID in (
		select iMinOID from @tmpRpt_FirstDupOrder
	) and iRedelivery = 2
	
	update @tmpRpt_Redelivery_Pre
	set sNote = '2xPost', 
		iRedelivery = 0
	where iRedelivery = 2
	if @iDebugStep_Bgn >= 16 begin
		if @iDebugStep_End <= 16 begin
			select 's:16:2xPost' as info, * from @tmpRpt_Redelivery_Pre as p where sNote = '2xPost'
		end
	end
	if @iDebug = 1 begin
		if @iOID_Debug is not null begin
			select 'OID:16:2xPost' as label, sNote, * from @tmpRpt_Redelivery_Pre where iOID = @iOID_Debug
		end
		if isnull(@iPID_Debug,0) <> 0 begin
			select 'PID:16:2xPost' as info, sNote, * from @tmpRpt_Redelivery_Pre as p where iPID = @iPID_Debug order by dComplete 
		End
	end 

	update @tmpRpt_Redelivery_Pre
	set sNote = 'NoPrior', 
		iRedelivery = 0
	where iPreOID is null
		and iRedelivery = 1
	if @iDebugStep_Bgn >= 17 begin
		if @iDebugStep_End <= 17 begin
			select 's:17:NoPrior' as info, * from @tmpRpt_Redelivery_Pre as p where sNote = 'NoPrior'
		end
	end
	if @iDebug = 1 begin
		if @iOID_Debug is not null begin
			select 'OID:17:NoPrior' as label, sNote, * from @tmpRpt_Redelivery_Pre where iOID = @iOID_Debug
		end
		if isnull(@iPID_Debug,0) <> 0 begin
			select 'PID:17:NoPrior' as info, sNote, * from @tmpRpt_Redelivery_Pre as p where iPID = @iPID_Debug order by dComplete 
		End
	end 

	update @tmpRpt_Redelivery_Pre
	set sNote = '[Re-Del]' 
	where iRedelivery = 1

	if @iDebugStep_Bgn >= 18 begin
		if @iDebugStep_End <= 18 begin
			select 's:18:[Re-Del]' as info, * from @tmpRpt_Redelivery_Pre as p where sNote = '[Re-Del]'
		end
	end
	if @iDebug = 1 begin
		if @iOID_Debug is not null begin
			select 'OID:18:[Re-Del]' as label, sNote, * from @tmpRpt_Redelivery_Pre where iOID = @iOID_Debug
			select szProductName, od.* from ss.tblOrderDetail as od join ss.tblProduct as pr on pr.iProductID = od.iProductID where iOrderID = @iOID_Debug
		end
		if isnull(@iPID_Debug,0) <> 0 begin
			select 'PID:18:[Re-Del]' as info, sNote, * from @tmpRpt_Redelivery_Pre as p where iPID = @iPID_Debug order by dComplete 
		End
	end 

	update @tmpRpt_Redelivery_Pre
	set iRedeliveryProductCnt = (
		select isnull(SUM(1),0) as xCnt from ss.tblOrderDetail where iOrderID = p.iOID and iProductID = 25400
	)
	from @tmpRpt_Redelivery_Pre as p

	IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[tmp_Redelivery]') AND type in (N'U'))
	DROP TABLE dbo.tmp_Redelivery 
	
	Create TABLE dbo.tmp_Redelivery (
		iSID int null,
		iCID int null,
		iOID int NOT NULL,
		iPID int NOT NULL,
		iDriverID int NOT NULL,
		iRouteNumber int NOT NULL,
		dComplete datetime NOT NULL,
		cReason char(1) NULL,
		iPreOID int NULL,
		iPreDriverID int NULL,
		iPreRouteNumber int NULL,
		dPreComplete datetime NULL,
		cPreReason char(1) NULL,
		iRedelivery int NOT NULL,
		iRedeliveryProductCnt int NULL,
		iHours int NULL,
		sNote varchar(10) NULL,
		iCntDME int null,
		iCntO2 int null,
		iCntDisp int null,
		iCntPickup int null,
		iCntService int null,
		iCntPaired int null,
		iCntCSMissPair int null,
		sFlagPaired varchar(255) null,
		sBadPreOID varchar(255) null,
		sBadNote varchar(255) null,
		iBadPreCnt int null, 
	) ON [PRIMARY]

	insert into dbo.tmp_Redelivery ( iSID, iCID, iOID, iPID, iDriverID,
		iRouteNumber, dComplete, cReason, iPreOID, iPreDriverID,
		iPreRouteNumber, dPreComplete, cPreReason, iRedelivery, iRedeliveryProductCnt,
		iHours, sNote, iCntDME, iCntO2, iCntDisp,
		iCntPickup, iCntService, iCntPaired, sBadPreOID, sBadNote, iBadPreCnt)
	select * from @tmpRpt_Redelivery_Pre

	declare @Orders as table (
		iOID int,
		sFullNote varchar(8000),
		sItemList varchar(2000)
	)
	insert into @Orders (iOID)
	select iOID from dbo.tmp_Redelivery as pd
	where ( pd.iRedelivery = 1 or pd.iRedeliveryProductCnt > 0 )
	union 	
	select iPreOID from dbo.tmp_Redelivery as pd
	where ( pd.iRedelivery = 1 or pd.iRedeliveryProductCnt > 0 )
	
	update @Orders set sFullNote = onp.sFullNote
	from @Orders as o 
	join ss.tblOrderNotepad as onp on onp.iOrderRef = o.iOID
	
	DECLARE @z_iOID int, @x_iCnt int, @x_Equip varchar(32), @x_Status varchar(16), @x_ItemList varchar(2000)
	DECLARE order_cursor CURSOR FOR
	SELECT iOID from @Orders
	OPEN order_cursor
	FETCH NEXT FROM order_cursor INTO @z_iOID
	WHILE @@FETCH_STATUS = 0
	BEGIN
		set @x_ItemList = ''
		DECLARE loop_cursor CURSOR FOR
		select sum(1) as xCnt, e.sName, s.szStatus
		from ss.tblOrderDetail as od
		join ss.tblProductEquip as pe on od.iProductID = pe.iProductRef
		join ss.tblEquipment as e on e.iEquipmentID = pe.iEquipmentRef
		join ss.tblStatus as s on s.cStatusID = od.cStatusID
		where iOrderID = @z_iOID
		group by e.sName, s.szStatus
		order by e.sName
		OPEN loop_cursor
		FETCH NEXT FROM loop_cursor INTO @x_iCnt, @x_Equip, @x_Status
		WHILE @@FETCH_STATUS = 0
		BEGIN
			if @x_ItemList <> '' begin select @x_ItemList = @x_ItemList + ', ' end
			select @x_ItemList = @x_ItemList + '{' + cast(@x_iCnt as varchar(16)) + 'x} ' + @x_Equip + '[' + @x_Status + ']'
	   		FETCH NEXT FROM loop_cursor INTO @x_iCnt, @x_Equip, @x_Status
		END
		CLOSE loop_cursor
		DEALLOCATE loop_cursor
		update @Orders set sItemList = @x_ItemList where iOID = @z_iOID

   		FETCH NEXT FROM order_cursor INTO @z_iOID
	END
	CLOSE order_cursor
	DEALLOCATE order_cursor

	IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[tmp_Orders]') AND type in (N'U'))
	DROP TABLE dbo.tmp_Orders 

	Create TABLE dbo.tmp_Orders (
		iOID int,
		sFullNote varchar(8000),
		sItemList varchar(2000)
	) ON [PRIMARY]

	insert into dbo.tmp_Orders Select * from @Orders 


	if @iDebugStep_Bgn <> 0 begin
		if @iOID_Debug is not null begin
			select 'OID:XX:Summary' as label, sNote, * from @tmpRpt_Redelivery_Pre where iOID = @iOID_Debug
		end
		if isnull(@iPID_Debug,0) <> 0 begin
			select 'PID:XX:Summary' as info, sNote, * from @tmpRpt_Redelivery_Pre as p where iPID = @iPID_Debug order by dComplete 
		End
	end 


/*-----------------------------------*\
|  BGN - Paired Item Logic            |
\*-----------------------------------*/
/*
Assuptions. All logic as it stands now is good. If the order is a Redelivery, and has not fallen out yet we will begin.
Any order that is a redelivery and has a paired item on it. will be reviewed for a qualifing item with it.

We added in the count section above, a count of paired items on any given order. If that number is 0 we do nothing.
If it is positive we need to do the following.

Flag it as paired item
For each order, and each paired item on this order we need to:
	check for paired main item in same "Stop" (if paired item with its partner then drop it.)
	check for paired main item in anything Delivered on the day this Stop was completed.

Notes:
Stop = Same Day, Driver and Route = Same order for the purpose of finding 
If an item was picked up on the day an item was delivered, it will count as a pair.

*/

update dbo.tmp_Redelivery set sFlagPaired = ''
update dbo.tmp_Redelivery set sFlagPaired = '!' where iCntPaired <> 0 and sNote = '[Re-Del]'

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[tmp_Paired]') AND type in (N'U'))
DROP TABLE dbo.tmp_Paired
Create TABLE dbo.tmp_Paired (
	iPID int, --Target patient
	iOID int, --Target Order Item
	dCompleted date, --Day Sub Items order was completed
	iDriverID int, --Driver that completed Sub Item Order
	iRoute int, --Route that this item was completed on.
	iODID int, --Order Detail ID of the target Sub Paired Item
	dChkOut datetime, --Date and time the Sub Paired Item was checked out
	iIID int, --Sup Paired Item ID
	iCntStop int, --Count of Main Paired Items for Target Sub Item on Orders in this Stop
	iCntPrior int, --Count of Main Paired Items for Target Sub Item on Orders Prior to this Stop
	iValidInStop int, --0 = no, 1 if this item was valid in the Stop
	iFoundInPrior int,	--0 = no, 1 if this item was found in Prior Orders + Others on Stop
	iFlagInvalid int	--0 is Good, 1 is Bad
)

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[tmp_PairedOrders]') AND type in (N'U'))
DROP TABLE dbo.tmp_PairedOrders
Create TABLE dbo.tmp_PairedOrders (
	cType char(1), --Type of List, Stop = S, Prior = P
	iOID int --Order IDs on this list
)

insert into dbo.tmp_Paired (iPID, iOID, dCompleted, iDriverID, iRoute, iODID, dChkOut, iIID)
select r.iPID, r.iOID, o.dtCompleted, o.iDriverID, o.iRouteNumber, 
	od.iOrderDetailID, od.dtCheckOut, e.iItemRef
from dbo.tmp_Redelivery as r
left join ss.tblOrderDetail as od on od.iOrderID = r.iOID
left join ss.tblProductEquip as pe on pe.iProductRef = od.iProductID
left join ss.tblEquipment as e on e.iEquipmentID = pe.iEquipmentRef
left join ss.tblOrder as o on o.iOrderID = r.iOID
where r.sFlagPaired = '!'
and e.iItemRef in (
	select distinct iIID_Sub from ss.tblItem_Pairs
)
/*
For each item in the table, we will check for:
1.) a paired item in the same order (Not a failure)
2.) a paired item delivered in another order (failure)
select * from dbo.tmp_Paired
*/


declare @z_iPID int, @z_dComplete date, @z_iDriver int, @z_iRoute int, @z_iODID int
declare @z_dChkOut date, @z_iIIDs int
declare @x_iCntStop int, @x_iCntPrior int
declare cu_Paired CURSOR FOR
select iPID, dCompleted, iDriverID, iRoute, iODID, dChkOut, iIID
from dbo.tmp_Paired
OPEN cu_Paired
	FETCH NEXT FROM cu_Paired INTO @z_iPID, @z_dComplete, @z_iDriver, @z_iRoute, @z_iODID, @z_dChkOut, @z_iIIDs
	WHILE @@FETCH_STATUS = 0
	BEGIN
		delete from dbo.tmp_PairedOrders
		set @x_iCntStop = 0
		set @x_iCntPrior = 0

		insert into dbo.tmp_PairedOrders 
		select 'S' as cType, iOrderID as iOID 
		from ss.tblOrder 
		where iPatientID = @z_iPID
		and cast(dtCompleted as date) = @z_dComplete
		and iDriverID = @z_iDriver
		and iRouteNumber = @z_iRoute

		insert into dbo.tmp_PairedOrders 
		select 'P' as cType, iOrderID as iOID 
		from ss.tblOrder 
		where iPatientID = @z_iPID
		and cast(dtCompleted as date) <= @z_dComplete
		and iOrderID not in (
			select iOID from dbo.tmp_PairedOrders
		)

		select @x_iCntStop = isnull(sum(1),0)
		from ss.tblOrderDetail as od
		left join ss.tblProductEquip as pe on pe.iProductRef = od.iProductID
		left join ss.tblEquipment as e on e.iEquipmentID = pe.iEquipmentRef
		left join ss.tblOrder as o on o.iOrderID = od.iOrderID
		where od.iOrderID in (select iOID from dbo.tmp_PairedOrders where cType = 'S')					--On an Order for this Stop
		and e.iItemRef in (select distinct iIID_Main from ss.tblItem_Pairs where iIID_Sub = @z_iIIDs)	--A Main Item for this Sub Item
		and cast(dtCheckOut as date) <= @z_dComplete													--Checked out Prior to this Stops Completed Date
		and coalesce(dtCheckIn,dtOtherStatus,'2999-12-31 12:00:00.000') >= @z_dChkOut					--Not Checked In or Lost before this Item

		select @x_iCntPrior = isnull(sum(1),0)
		from ss.tblOrderDetail as od
		left join ss.tblProductEquip as pe on pe.iProductRef = od.iProductID
		left join ss.tblEquipment as e on e.iEquipmentID = pe.iEquipmentRef
		left join ss.tblOrder as o on o.iOrderID = od.iOrderID
		where od.iOrderID in (select iOID from dbo.tmp_PairedOrders where cType = 'P')					--On a Prior Order
		and e.iItemRef in (select distinct iIID_Main from ss.tblItem_Pairs where iIID_Sub = @z_iIIDs)	--A Main Item for this Sub Item
		and dtCheckOut <= @z_dChkOut																	--Checked out Prior to this Item
		and coalesce(dtCheckIn,dtOtherStatus,'2999-12-31 12:00:00.000') >= @z_dChkOut					--Not Checked In or Lost before this Item

		update dbo.tmp_Paired
		set iCntStop = @x_iCntStop,
			iCntPrior = @x_iCntPrior
		where iODID = @z_iODID

   		FETCH NEXT FROM cu_Paired INTO @z_iPID, @z_dComplete, @z_iDriver, @z_iRoute, @z_iODID, @z_dChkOut, @z_iIIDs
	END
CLOSE cu_Paired
DEALLOCATE cu_Paired

update dbo.tmp_Paired set iValidInStop = 0
update dbo.tmp_Paired 
set iValidInStop = 1
from dbo.tmp_Paired as pair
right join (
	select dCompleted, iDriverID, iRoute, iIID, iSubItemCnt, iCntStop, iCntPrior
	from (
		select dCompleted, iDriverID, iRoute, iIID, Sum(1) as iSubItemCnt, iCntStop, iCntPrior
		from dbo.tmp_Paired
		group by dCompleted, iDriverID, iRoute, iIID, iCntStop, iCntPrior
	) as x
	where x.iSubItemCnt <= x.iCntStop
) as c on pair.dCompleted = c.dCompleted and pair.iDriverID = c.iDriverID and pair.iRoute = c.iRoute and pair.iIID = c.iIID

update dbo.tmp_Paired set iFoundInPrior = 0
update dbo.tmp_Paired 
set iFoundInPrior = 1
from dbo.tmp_Paired as pair
right join (
	select dCompleted, iDriverID, iRoute, iIID, iSubItemCnt, iCntStop, iCntPrior, iCntStop + iCntPrior as iCntBoth
	from (
		select dCompleted, iDriverID, iRoute, iIID, Sum(1) as iSubItemCnt, iCntStop, iCntPrior
		from dbo.tmp_Paired
		group by dCompleted, iDriverID, iRoute, iIID, iCntStop, iCntPrior
	) as x
	where x.iSubItemCnt <= x.iCntStop + iCntPrior
) as c on pair.dCompleted = c.dCompleted and pair.iDriverID = c.iDriverID and pair.iRoute = c.iRoute and pair.iIID = c.iIID

update dbo.tmp_Paired set iFlagInvalid = 0
update dbo.tmp_Paired set iFlagInvalid = 1 where iFoundInPrior = 1
update dbo.tmp_Paired set iFlagInvalid = 0 where iValidInStop = 1

update dbo.tmp_Redelivery set iCntCSMissPair = 0
update dbo.tmp_Redelivery 
set iCntCSMissPair = pair.iFlagInvalid
from dbo.tmp_Redelivery as r
right join dbo.tmp_Paired as pair on r.iOID = pair.iOID 

/*-----------------------------------*\
--|  END - Paired Item Logic            |
\*-----------------------------------*/
	insert into reports_bic.dbo.VitasRedelivery
	select @smonth,rtrim(d.sName + ', ' + (s.sName)) as Provider, rtrim(c.sName) as Client, rtrim(re.sname) as RegionName, --DATENAME(month ,pd.dComplete) as imonth
		SUM(1) as [Cnt Orders], SUM(pd.iRedelivery) as [Cnt Redelivery], SUM(pd.iCntCSMissPair) as [Cnt Missed Pair],
		cast(case when SUM(1.00) = 0 then 0 else SUM(pd.iCntCSMissPair) / SUM(.01) end as numeric(9,4)) as [%!Paired],
		cast(case when SUM(1.00) = 0 then 0 else SUM(iRedelivery) / SUM(.01) end as numeric(9,4)) as [% Redelivery],
		cast(case when SUM(1.00) = 0 then 0 else sum(case when iHours <= 1440 then iRedelivery else 0 end) / SUM(.01) end as numeric(9,4)) as [% 24 hrs],
		cast(case when SUM(1.00) = 0 then 0 else sum(case when iHours > 1440 then (case when iHours <= 2880 then iRedelivery else 0 end) else 0 end) / SUM(.01) end as numeric(9,4)) as [% 48 hrs],
		cast(case when SUM(1.00) = 0 then 0 else sum(case when iHours > 2880 then (case when iHours <= 4320 then iRedelivery else 0 end) else 0 end) / SUM(.01) end as numeric(9,4)) as [% 72 hrs],
		cast(case when SUM(1.00) = 0 then 0 else sum(case when iHours > 4320 then (case when iHours <= 5760 then iRedelivery else 0 end) else 0 end) / SUM(.01) end as numeric(9,4)) as [% 96 hrs],
		cast(case when SUM(1.00) = 0 then 0 else sum(case when iHours > 5760 then (case when iHours <= 7200 then iRedelivery else 0 end) else 0 end) / SUM(.01) end as numeric(9,4)) as [% 120 hrs],
		cast(case when SUM(1.00) = 0 then 0 else sum(case when iHours > 7200 then (case when iHours <= 8640 then iRedelivery else 0 end) else 0 end) / SUM(.01) end as numeric(9,4)) as [% 144 hrs],
		cast(case when SUM(1.00) = 0 then 0 else sum(case when iHours > 8640 then (case when iHours <= 10080 then iRedelivery else 0 end) else 0 end) / SUM(.01) end as numeric(9,4)) as [% 168 hrs],

		case when SUM(1) = 0 then 0 else sum(case when iHours <= 1440 then iRedelivery                                             else 0 end) end as [#  24 hrs],
		case when SUM(1) = 0 then 0 else sum(case when iHours >  1440 then (case when iHours <=  2880 then iRedelivery else 0 end) else 0 end) end as [#  48 hrs],
		case when SUM(1) = 0 then 0 else sum(case when iHours >  2880 then (case when iHours <=  4320 then iRedelivery else 0 end) else 0 end) end as [#  72 hrs],
		case when SUM(1) = 0 then 0 else sum(case when iHours >  4320 then (case when iHours <=  5760 then iRedelivery else 0 end) else 0 end) end as [#  96 hrs],
		case when SUM(1) = 0 then 0 else sum(case when iHours >  5760 then (case when iHours <=  7200 then iRedelivery else 0 end) else 0 end) end as [# 120 hrs],
		case when SUM(1) = 0 then 0 else sum(case when iHours >  7200 then (case when iHours <=  8640 then iRedelivery else 0 end) else 0 end) end as [# 144 hrs],
		case when SUM(1) = 0 then 0 else sum(case when iHours >  8640 then (case when iHours <= 10080 then iRedelivery else 0 end) else 0 end) end as [# 168 hrs]
	from dbo.tmp_Redelivery as pd
	join ss.tblPatient as p on p.iPatientID = pd.iPID 
	join ss.tblLocation as s on s.iLocationID = p.iSiteRef 
	join ss.tblCompany as d on s.iCompanyRef = d.iCompanyID 
	join ss.tblLocation as c on c.iLocationID = p.iClientRef 
	left join ss.tblSet as re on re.iSetId = c.iSetRef
	where dComplete >= @dS and dComplete <= @dE
	group by c.sName, d.sName + ', ' + s.sName,re.sname


delete from @tOrderBuckets
delete from @tDyad
delete from @tmpRpt_Redelivery_Raw
delete from @tmpRpt_Redelivery_Pre
delete from @Orders

	
set @loop_step=@loop_step+1
end	---3 month loop ends