// This is an Unreal Script
                           
class X2Effect_MapAlert extends X2Effect_Persistent;

var bool CheckedAlert;
var int	TurnsPassedCounter;

simulated protected function OnEffectAdded(const out EffectAppliedData ApplyEffectParameters, XComGameState_BaseObject kNewTargetState, XComGameState NewGameState, XComGameState_Effect NewEffectState)
{
	local XComGameState_AIGroup		AIGroupState;	
	local XComGameState_Unit		Unit;
	local XComGameState_Unit_FoV		OwningUnit;
	local XComGameState_Unit_FoV	FoVUnit;
	
	OwningUnit=XComGameState_Unit_FoV(`XCOMHISTORY.GetGameStateForObjectID(ApplyEffectParameters.SourceStateObjectRef.ObjectID));


	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_AIGroup', AIGroupState)
	{
		AIGroupState.ApplyAlertAbilityToGroup(eAC_AlertedByCommLink);		
	}
	foreach `XCOMHistory.IterateByClassType(class'XComGameState_UnitFoV', FoVUnit)
	{
		if(FoVUnit.GetTeam() == eTeam_XCom)
		{
			if(FoVUnit.ActivatedMapAlert)
			{
				CheckedAlert=true;
				break;
			}
		}
	}		
	if(OwningUnit.ActivatedMapAlert==false &&CheckedAlert==false)
	{
		SummonReinforcements('ADVx2_Standard',OwningUnit,OwningUnit,NewGameState,1);
		OwningUnit.ActivatedMapAlert=true;
		OwningUnit.HasReinforcementsOnTheWay=true;
		NewGameState.AddStateObject(OwningUnit);
	}
	super.OnEffectAdded(ApplyEffectParameters,kNewEffectState,NewGameState,NewEffectState);

}

simulated function bool OnEffectTicked(const out EffectAppliedData ApplyEffectParameters, XComGameState_Effect kNewEffectState, XComGameState NewGameState, bool FirstApplication)
{
	local XComGameState_Unit_FoV		OwningUnit;
	local bool						HasE_Enemies,bToPass;
	local XComGameState_Unit_FoV	FoVUnit;

	OwningUnit=XComGameState_Unit_FoV(`XCOMHISTORY.GetGameStateForObjectID(ApplyEffectParameters.SourceStateObjectRef.ObjectID));
	if(HasEngagedEnemiesWithinSight(OwningUnit))
	{
		kNewEffectState.iTurnsRemaining=4;
	}
	TurnsPassedCounter++;
	if(TurnsPassedCounter%6==0)
	{
		HasE_Enemies=HasEngagedEnemiesWithinSight(OwningUnit);	

		if(HasE_Enemies) 
		{
			`log("Failed doing Individual Concealment"); 
			foreach `XCOMHistory.IterateByClassType(class'XComGameState_UnitFoV', FoVUnit)
			{
				if(FoVUnit.GetTeam() == eTeam_XCom)
				{
					if((FoVUnit.HasReinforcementsOnTheWay||FoVUnit.ActivatedMapAlert) &&FoVUnit!=OwningUnit)
					{
						CheckedAlert=true;
						break;
					}
				}
			}		
			if(!OwningUnit.HasReinforcementsOnTheWay&&OwningUnit.ActivatedMapAlert==true&&CheckedAlert==false)
			{
				SummonReinforcements('ADVx3_Standard',OwningUnit,OwningUnit,NewGameState,1);
				SummonReinforcements('ADVx4_Strong',OwningUnit,OwningUnit,NewGameState,3);
				OwningUnit.HasReinforcementsOnTheWay=true;	
					
			}
		
		}
	}
	if((TurnsPassedCounter%3==0 || FirstApplication)&& OwningUnit.HasReinforcementsOnTheWay)
	{
		OwningUnit.HasReinforcementsOnTheWay=false;
	}
	return super.OnEffectTicked(ApplyEffectParameters,kNewEffectState,NewGameState,FirstApplication);
}

simulated function OnEffectRemoved(const out EffectAppliedData ApplyEffectParameters, XComGameState NewGameState, bool bCleansed, XComGameState_Effect RemovedEffectState)
{
	local bool						HasE_Enemies,bToPass;
	local XComGameState_Unit_FoV	OwningUnit;
	local XComGameState_Unit_FoV	FoVUnit;

	OwningUnit=XComGameState_Unit_FoV(`XCOMHISTORY.GetGameStateForObjectID(ApplyEffectParameters.SourceStateObjectRef.ObjectID));
	HasE_Enemies=HasEngagedEnemies(OwningUnit);
	if(HasE_Enemies==false) 
	{
		`log("Redoing Individual Concealment"); 
		bToPass=true;
		
	} 
	else 
	{
		`log("Failed doing Individual Concealment"); 
		bToPass=false;		
	}
	OwningUnit.ActivatedMapAlert=false;
	NewGameState.AddStateObject(OwningUnit);
	ApplyIndConceal(OwningUnit, NewGameState, bToPass);
	super.OnEffectRemoved(ApplyEffectParameters,NewGameState,bCleansed,RemovedEffectState);
}

function ApplyIndConceal(XComGameState_Unit Unit,XComGameState NewGameState,optional bool ReConceale=false)
{
	local array<XComGameState_Unit>	AttachedUnits;
	local XComGameState_Unit		GremlinUnit;

	// enable individual concealment on the unit
	if(Unit!=none && ReConceale && Unit.GetTeam()==ETeam_XCom && !Unit.IsConcealed() && !Unit.IsSquadConcealed() )
	{
		`XEVENTMGR.TriggerEvent('EffectEnterUnitConcealment', Unit, Unit, NewGameState);
		Unit.GetAttachedUnits(AttachedUnits);
		foreach AttachedUnits(GremlinUnit)
		{
			`XEVENTMGR.TriggerEvent('EffectEnterUnitConcealment', GremlinUnit, GremlinUnit, NewGameState);
		}
	}
}

function bool HasEngagedEnemies(XComGameState_Unit ThisUnitState)
{
	local XComGameState_Unit				Unit;
	local X2GameRulesetVisibilityManager	VisibilityMgr;
	local GameRulesCache_VisibilityInfo		VisibilityInfoFromOtherUnit;
	
	VisibilityMgr = `TACTICALRULES.VisibilityMgr;

	foreach `XCOMHistory.IterateByClassType(class'XComGameState_Unit', Unit)
	{
		if(Unit.GetTeam() == eTeam_Alien)
		{
		//	`log("eStat_AlertLevel"@Unit.GetCurrentStat(eStat_AlertLevel)); 
		//	`log("HP"@Unit.GetCurrentStat(eStat_HP));
		//	`log("Red"@`ALERT_LEVEL_RED);
		//	`log("");
			
			VisibilityMgr.GetVisibilityInfo(ThisUnitState.ObjectID, Unit.ObjectID, VisibilityInfoFromOtherUnit);
			if((Unit.GetCurrentStat(eStat_AlertLevel) >= `ALERT_LEVEL_RED && Unit.GetCurrentStat(eStat_HP)>0 ) &&!VisibilityInfoFromOtherUnit.bBeyondSightRadius)	
				Return True;
		}
	}
	return false;
}

function bool HasEngagedEnemiesWithinSight(XComGameState_Unit ThisUnitState)
{
	local XComGameState_Unit				Unit;
	local X2GameRulesetVisibilityManager	VisibilityMgr;
	local GameRulesCache_VisibilityInfo		VisibilityInfoFromOtherUnit;
	
	VisibilityMgr = `TACTICALRULES.VisibilityMgr;

	foreach `XCOMHistory.IterateByClassType(class'XComGameState_Unit', Unit)
	{
		if(Unit.GetTeam() == eTeam_Alien)
		{
		//	`log("eStat_AlertLevel"@Unit.GetCurrentStat(eStat_AlertLevel)); 
		//	`log("HP"@Unit.GetCurrentStat(eStat_HP));
		//	`log("Red"@`ALERT_LEVEL_RED);
		//	`log("");
			
			VisibilityMgr.GetVisibilityInfo(ThisUnitState.ObjectID, Unit.ObjectID, VisibilityInfoFromOtherUnit);
			if((Unit.GetCurrentStat(eStat_AlertLevel) >= `ALERT_LEVEL_RED && Unit.GetCurrentStat(eStat_HP)>0 ) && VisibilityInfoFromOtherUnit.bVisibleGameplay)	
				Return True;
		}
	}
	return false;
}

function SummonReinforcements(name ReInforcements,XComGameState_Unit Shooter, XComGameState_Unit Target, XComGameState NewGameState, int turns)
{
	local XComGameState_Unit UnitState;
	local XComGameState_InteractiveObject ObjectState;
	local TTile TargetTile;
	local vector SummonPos;

	TargetTile = Target.TileLocation;
	SummonPos = `XWORLD.GetPositionFromTileCoordinates(TargetTile);
	class'XComGameState_AIReinforcementSpawner'.static.InitiateReinforcements(ReInforcements, turns /*OverrideCountdown*/, true, SummonPos, 5, NewGameState);
}