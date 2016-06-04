// This is an Unreal Script

class X2Effect_SquadEnterConcealment extends X2Effect_Persistent;

simulated protected function OnEffectAdded(const out EffectAppliedData ApplyEffectParameters, XComGameState_BaseObject kNewTargetState, XComGameState NewGameState, XComGameState_Effect NewEffectState)
{
	 `log("Added X2Effect_SquadEnterConcealment"); 
	super.OnEffectAdded(ApplyEffectParameters,kNewEffectState,NewGameState,NewEffectState);
}


simulated function OnEffectRemoved(const out EffectAppliedData ApplyEffectParameters, XComGameState NewGameState, bool bCleansed, XComGameState_Effect RemovedEffectState)
{
	local bool HasE_Enemies,bToPass;
	local XComGameState_Unit	OwningUnit,Unit;

	OwningUnit=XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ApplyEffectParameters.SourceStateObjectRef.ObjectID));
	foreach `XCOMHistory.IterateByClassType(class'XComGameState_Unit', Unit)
	{
		if(Unit.GetTeam() == eTeam_XCom && HasE_Enemies==false)
		{
			HasE_Enemies=HasEngagedEnemies(OwningUnit);
		}
	}
	if(HasE_Enemies==false) 
	{
		`log("Redoing Concealment"); 
		bToPass=true;
	}
	else 
	{
		`log("Failed doing Concealment");
		bToPass=false; 
		`XEVENTMGR.TriggerEvent('ActivateMapAlert_Dragonpunk',OwningUnit,OwningUnit,NewGameState);
	}

	ApplySquadConceal(NewGameState, bToPass);
	super.OnEffectRemoved(ApplyEffectParameters,NewGameState,bCleansed,RemovedEffectState);
}
function ApplySquadConceal(XComGameState NewGameState,optional bool ReConceale=false)
{
	local XComGameStateHistory History;
	local XComGameState_Player PlayerState;

	History = `XCOMHISTORY;

	// enable individual concealment on all XCom units
	foreach History.IterateByClassType(class'XComGameState_Player', PlayerState)
	{
		if( PlayerState.GetTeam() == eTeam_XCom && !PlayerState.bSquadIsConcealed )
		{
			PlayerState.SetSquadConcealmentNewGameState(ReConceale, NewGameState);
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

