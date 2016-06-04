// Useless Class so far
                           
class UI_Listener_UITacHUD_MoreCivis extends UIScreenListener config(Ghosts); // NOT WORKING!

struct CivCountRandomiser
{
	var int	MinCivCount;
	var int	MaxCivCount;
};

var class<UIScreen> ScreenClass;				//causes warning but needed to trigger OnReceiveFocus()
var config bool					UseMoreCivis;
var config CivCountRandomiser	CiviliansCounts;
var array<TTile> SavedTiles;
var int TotalCivAddedNum;
//var	UITacticalHUD MyScreen;	
event OnInit(UIScreen Screen)
{
	local Object ThisObj;
	
	ThisObj=self;
	
	//`XEVENTMGR.RegisterForEvent(ThisObj, 'OnTacticalBeginPlay', OnTacticalStarted, ELD_OnStateSubmitted);
	
}

function EventListenerReturn OnTacticalStarted(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	local int i,RandomNum;
	local XComGameState_InteractiveObject InterObj;
	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_InteractiveObject', InterObj) //Going over all Interactive objects 
	{
		break;
	}
	`log("----------------------------------------------------------------------",true,'DragonPunk Stealth Mod');	
	`log("Inserting Civis To Missions Listener",true,'DragonPunk Stealth Mod');	
	`log("----------------------------------------------------------------------",true,'DragonPunk Stealth Mod');	
		
	`XWORLD.GetUnoccupiedNonCoverTiles(InterObj.TileLocation,75,SavedTiles);

	RandomNum=Rand(21)+40;
	for(i=0;i<RandomNum;i++)
	{
		CreateCivilian();
		//CreateNewCivilian();
		TotalCivAddedNum++;
	}
	`log("TotalCivAddedNum:"@TotalCivAddedNum,true,'DragonPunk Stealth Mod');		
	SavedTiles.Length=0;
	return ELR_NoInterrupt;
}

function bool GetCiviSpawnLocation(out vector SpawnLoc)
{
	local int randomTileNum,i;
	local TTile MyTile;
	randomTileNum=Rand(SavedTiles.Length);
	MyTile=SavedTiles[randomTileNum];
	SpawnLoc= `XWORLD.GetPositionFromTileCoordinates(MyTile);
	`log("SpawnLoc:"@SpawnLoc @"randomTileNum:"@randomTileNum,true,'Team Dragonpunk');
	return true;
}

function XComGameState_Unit CreateNewCivilian()
{

	local Vector SpawnLocation;
	local XComGameStateHistory History;
	local XComAISpawnManager SpawnManager;
	local StateObjectReference SpawnedUnitRef;
	local XComGameState_Unit SpawnedUnit;
	local Float RandomF;
	local XComGameState_Player PlayerState;
	local XComGameState NewGameState;

	GetCiviSpawnLocation(SpawnLocation);
	// spawn the unit
	History = `XCOMHISTORY;
	SpawnManager = `SPAWNMGR;
	SpawnedUnitRef = SpawnManager.CreateUnit( SpawnLocation, 'Civilian', eTeam_Neutral, false );
	SpawnedUnit = XComGameState_Unit(History.GetGameStateForObjectID(SpawnedUnitRef.ObjectID));
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("ChangedSoldier_"$SpawnedUnitRef.ObjectID);
	foreach History.IterateByClassType(class'XComGameState_Player', PlayerState)
	{
		if(PlayerState.GetTeam() == eTeam_Neutral)
		{
			`log("Added To A Neutral Team");
			SpawnedUnit.SetControllingPlayer(PlayerState.GetReference());
			break;
		}
	}
	RandomF= FRand() * GetRandomSign();
	SpawnedUnit.m_kPawn.RotateInPlace(RandomF);
	NewGameState.AddStateObject(SpawnedUnit);
	`TACTICALRULES.SubmitGameState(NewGameState);
	return SpawnedUnit;
}
	
function XComGameState_Unit CreateCivilian()
{
	local X2TacticalGameRuleset Rules;
	local Vector SpawnLocation;
	local XGCharacterGenerator CharacterGenerator;
	local X2CharacterTemplate CharTemplate;
	local XComGameStateContext_TacticalGameRule NewGameStateContext;
	local XComGameState NewGameState;
	local XComGameState_Unit Unit;
	local XComGameState_Player PlayerState;
	local TSoldier Soldier;
	local XComGameStateHistory History;

	History=`XCOMHISTORY;
	// pick a floor point at random to spawn the unit at
	if(!GetCiviSpawnLocation(SpawnLocation))
	{
		return none;
	}

	NewGameStateContext = class'XComGameStateContext_TacticalGameRule'.static.BuildContextFromGameRule(eGameRule_UnitAdded);
	NewGameState = History.CreateNewGameState(true, NewGameStateContext);

	// generate a debug unit
	CharTemplate = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager().FindCharacterTemplate('Civilian');
	`assert(CharTemplate != none);
	CharTemplate.bIsHostileCivilian = false;
	CharacterGenerator = `XCOMGRI.Spawn(CharTemplate.CharacterGeneratorClass);
	`assert(CharacterGenerator != none);

	Unit = CharTemplate.CreateInstanceFromTemplate(NewGameState);
	
	// assign the player to him
	foreach History.IterateByClassType(class'XComGameState_Player', PlayerState)
	{
		if(PlayerState.GetTeam() == eTeam_Neutral)
		{
			`log("Added To A Neutral Team");
			Unit.SetControllingPlayer(PlayerState.GetReference());
			break;
		}
	}

	// give him abilities
	Rules = `TACTICALRULES;
	Rules.InitializeUnitAbilities(NewGameState, Unit);

	// give him an appearance
	Soldier = CharacterGenerator.CreateTSoldier('Civilian');
	Unit.SetTAppearance(Soldier.kAppearance);
	Unit.SetCharacterName(Soldier.strFirstName, Soldier.strLastName, Soldier.strNickName);
	Unit.SetCountry(Soldier.nmCountry);

	// and cleanup the generator object
	CharacterGenerator.Destroy();
	
	return AddCivilianToBoard(Unit,NewGameState);
}

function XComGameState_Unit AddCivilianToBoard(XComGameState_Unit Unit,XComGameState NewGameState)
{
	local X2TacticalGameRuleset Rules;
	local Vector SpawnLocation;
	local XComGameStateContext_TacticalGameRule NewGameStateContext;
	local XComGameState_Player PlayerState;
	local StateObjectReference ItemReference;
	local XComGameState_Item ItemState;
	local X2EquipmentTemplate EquipmentTemplate;
	local XComWorldData WorldData;
	local XComAISpawnManager SpawnManager;
	local XComGameStateHistory History;
	local float RandomF;
	History=`XCOMHISTORY;
	if(Unit == none)
	{
		return none;
	}

	// pick a floor point at random to spawn the unit at
	if(!GetCiviSpawnLocation(SpawnLocation))
	{
		return none;
	}

	// create the history frame with the new tactical unit state
	if(NewGameState==none)
	{
		NewGameStateContext = class'XComGameStateContext_TacticalGameRule'.static.BuildContextFromGameRule(eGameRule_UnitAdded);
		NewGameState = History.CreateNewGameState(true, NewGameStateContext);
	}
	//Unit = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', Unit.ObjectID));
	Unit.SetVisibilityLocationFromVector(SpawnLocation);

	// assign the new unit to the human team
	foreach History.IterateByClassType(class'XComGameState_Player', PlayerState)
	{
		if(PlayerState.GetTeam() == eTeam_Neutral)
		{
			`log("Added To A Neutral Team");
			Unit.SetControllingPlayer(PlayerState.GetReference());
			break;
		}
	}

	WorldData = `XWORLD;
	SpawnManager = `SPAWNMGR;

	// add item states. This needs to be done so that the visualizer sync picks up the IDs and
	// creates their visualizers
/*	foreach Unit.InventoryItems(ItemReference)
	{
		ItemState = XComGameState_Item(NewGameState.CreateStateObject(class'XComGameState_Item', ItemReference.ObjectID));
		NewGameState.AddStateObject(ItemState);

		// add the gremlin to Specialists
		if( ItemState.OwnerStateObject.ObjectID == Unit.ObjectID )
		{
			EquipmentTemplate = X2EquipmentTemplate(ItemState.GetMyTemplate());
			if( EquipmentTemplate != none && EquipmentTemplate.CosmeticUnitTemplate != "" )
			{
				SpawnLocation = WorldData.GetPositionFromTileCoordinates(Unit.TileLocation);
				ItemState.CosmeticUnitRef = SpawnManager.CreateUnit(SpawnLocation, name(EquipmentTemplate.CosmeticUnitTemplate), Unit.GetTeam(), true);
			}
		}
	}*/
	RandomF= FRand() * GetRandomSign();
	(XGUnit(Unit.GetVisualizer())).GetPawn().RotateInPlace(RandomF);
	// add abilities
	// Must happen after items are added, to do ammo merging properly.
	Rules = `TACTICALRULES;
	Rules.InitializeUnitAbilities(NewGameState, Unit);


	// submit it
	NewGameState.AddStateObject(Unit);
	XComGameStateContext_TacticalGameRule(NewGameState.GetContext()).UnitRef = Unit.GetReference();
	Rules.SubmitGameState(NewGameState);

	return Unit;
}
function float GetRandomSign()
{
	local int i;
	i=Rand(2);
	if(i==1)
		return 1.0f;
	else
		return -1.0f;	
}
defaultproperties
{
	// Leaving this assigned to none will cause every screen to trigger its signals on this class
	ScreenClass=UITacticalHUD;
	TotalCivAddedNum=0;
}	