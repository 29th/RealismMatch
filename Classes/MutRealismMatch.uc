/*
	REALISM MATCH  v1.0
	Mutator for Darkest Hour: Normandy 1944
	www.darkesthourgame.com

	Created by Captain Wilson
	For the 29th ID Realism Unit
	www.29th.org

	Now available for public use

	DESCRIPTION
	Gives admin control over the amount of reinforcement waves and automates setting changes common to 'realism scrimmages'.
	This mutator brings 'realism mode' to Darkest Hour, where each player has one life per round, forcing teams to work together more cohesively to keep each other alive.
	This gameplay is not meant for public play, but scrimmages (though it can certainly be used publicly).
	
	Traditionally, a 'realism match' forced players to 'join spectators' after they died so they didn't respawn. This mutator can disable respawning, or give the admin control
	over how many reinforcement waves each team has, allowing for various realism scenarios. It also includes a 'ready/not ready' feature where the match is not 'live' until
	both teams have signalled their 'ready' status.

	In addition, this mutator can automatically change the round limit, win limit and max team difference during the match, and change them back to default after the match.
	If necessary, it can also change the round duration for the map to allow for longer briefings and so that time is not an issue in a scrimmage.
	Lastly, to prevent friendly	fire during briefings, this mutator offers the option of disabling FF until 'live' is announced, when it returns FF to your normal setting.

	INSTALLATION
	Add all 3 files (.uc, .ucl, .int) to your server's \DarkestHour\System\ directory and restart your server
	Either enable the mutator via WebAdmin or have it automatically enabled via the server command line.
	To do this via command line, add ?Mutator=MutRealismMatch.MutRealismMatch to the long string of ? variables in it.

	ENABLING
	Enabling 'Realism Match' mode will reset the round and put the game in a state where team leaders can brief their players.
	To enable 'Realism Match' mode, login as admin and type in console: mutate enablematch
	To disable: mutate disablematch
	To reset the round (not the whole map), login as admin and type in console: admin resetgame

	BEGINNING THE MATCH
	After a team leader is done briefing, he will type the 'ready' command to tell the game his team is ready. When both teams have done this, the game will announce 'LIVE',
	which will disable respawning and enable friendly fire.
	To signal that your team is ready, any player can type in chat: /ready
	To signal that your team is NOT ready, any player can type in chat: /notready
	Alternatively, an admin can force the game live without 'readies' by typing in console: mutate matchlive

	RESPAWNING
	If a player wishes to change team/role, suicide will prevent him from respawning (one life per round). As a work around, any player can type a command in console to
	to instantly respawn after changing team/role: mutate respawn
	'Realism Match' mode must be enabled for this command to work, but the player does not have to be an admin.

	REALISM GAMEPLAY
	Realism Scrimmages are generally conducted as follows:
	1. Team leaders are picked and team members are sorted to their teams
	2. 'Realism Match' mode is enabled by the admin
	3. Players line up on the wall at spawn and are briefed on the plan by their team leader
	4. After briefing is conducted on both teams, team leaders type 'Allies Ready' or 'Axis Ready' to each other. When both are ready, one calls 'LIVE!' and the match begins
	5. Players work together to eliminate the opposing force. Capture Areas/Objectives are usually overlooked except in scenario scrimmages.

	CHANGING SETTINGS
	This mutator, by default, makes the following changes to gameplay when enabled:
	- Allies & Axis Reinforcements set to 1 (0 would mean no initial spawning)
	- Win Limit & Round Limit set to 999 (so the map won't change after # rounds)
	- Max Team Difference set to 50 (so all players can be on the same team while choosing team members, etc.)
	- Disable FF During Briefing is enabled (to avoid friendly fire before match is 'live' during briefings)
	
	When 'Realism Match' mode is disabled, these settings are changed back to their default values.
	To change the values to which these settings are changed during 'Realism Match' mode, use the Web Admin.

	ROUND DURATION
	Changing the round duration works slightly differently as it can only be done at the beginning of the map, thus a map reset is required every time it is changed.
	To do this, change the setting in the WebAdmin to anything above 0 (such as 999 for 'no limit') and reset the map. Note that this change will apply even when
	'Realism Match' mode is disabled (until you change it and reset the map again).
*/

class MutRealismMatch extends Mutator;

// Global Variables
var	ROLevelInfo	MyROLevelInfo;			// Stores the ROLevelInfo so we can access its properties
var	GameInfo	MyGameInfo;
var ROTeamGame	MyROTeamGame;
var ReadyBroadcastHandler MyBroadcastHandler;
var config bool	MatchEnabled, MatchLive, AlliesReady, AxisReady, DisableFFBriefing;
var config int	AlliesReinforcements, AxisReinforcements, WinLimit, RoundLimit, MaxTeamDiff, RoundDuration;
var int DefaultAlliesReinforcements, DefaultAxisReinforcements, DefaultWinLimit, DefaultRoundLimit, DefaultMaxTeamDiff, DefaultRoundDuration, DefaultFF;

var localized string GUIDisplayText[7]; // Config property label names
var localized string GUIDescText[7];    // Config property long descriptions

// Locates and saves important actors
function PostBeginPlay()
{
	// ROLevelInfo
	foreach AllActors(class'ROLevelInfo', MyROLevelInfo)
		break;

	if(MyROLevelInfo == none)
		Log("ERROR: No ROLevelInfo Actor Found");

	// GameInfo
	foreach AllActors(class'GameInfo', MyGameInfo)
		break;

	if(MyGameInfo == none)
		Log("ERROR: No GameInfo Actor Found");

	// ROTeamGame
	foreach AllActors(class'ROTeamGame', MyROTeamGame)
		break;

	if(MyROTeamGame == none)
		Log("ERROR: No ROTeamGame Actor Found");

	// RoundDuration can only be altered at the beginning of the map,
	// so test if the variable is above 0, and if so, change the map setting to it
	if(RoundDuration > 0)
		ChangeRoundDuration();
	
	// add a broadcast handler to watch for ready chat messages
	MyBroadcastHandler = spawn( class'MutRealismMatch.ReadyBroadcastHandler' );
	MyBroadcastHandler.MatchMutator = self;
	Level.Game.BroadcastHandler.RegisterBroadcastHandler( MyBroadcastHandler );

	// add a broadcast handler to watch for attendance taking
	//AttendanceBroadcastHandler = spawn( class'MutRealismMatch.AttendanceBroadcastHandler' );
	//AttendanceBroadcastHandler.MatchMutator = self;
	//Level.Game.BroadcastHandler.RegisterBroadcastHandler( MyBroadcastHandler );
}

// Interprets commands and broadcasts their execution
function Mutate(string MutateString, PlayerController Sender)
{
	// Get player name for broadcasts
	local string MyPlayerName;
	MyPlayerName = Sender.PlayerReplicationInfo.PlayerName;

	// always call super class implementation!
	Super.Mutate(MutateString, Sender);

	if ( MutateString ~= "EnableMatch" && IsAdmin(Sender) )
	{
		MatchState( true );
		Level.Game.Broadcast( self, "[Realism Match] Enabled by "$MyPlayerName );
	}
	else if( MutateString ~= "DisableMatch" && IsAdmin(Sender) )
	{
		// Ensure match is already enabled and default attributes were saved
		if( MatchEnabled == true
			&& (DefaultAlliesReinforcements > 0 && DefaultAxisReinforcements > 0) )
		{
			MatchState( false );
			Level.Game.Broadcast( self, "[Realism Match] Disabled by "$MyPlayerName );
		}
	}
	else if( MutateString ~= "Respawn" )
	{
		if( MatchEnabled == true && MatchLive == false )
		{
			Respawn( Sender );
			Level.Game.Broadcast( self, "[Realism Match] "$MyPlayerName$" respawned" );
		}
	}
	else if( MutateString ~= "Attendance" )
	{
		Sender.CopyToClipboard( GetPlayerList() );
	}
	else if( MutateString ~= "MatchLive" && IsAdmin(Sender) )
	{
		if( MatchEnabled == true && MatchLive == false )
		{
			MatchStatus( true );
		}
	}
}

// Enable or Disable the Match and Reset Game
function MatchState( bool Status )
{
	// Disable Global Variable
	MatchEnabled = Status;

	// Change Settings
	ChangeSettings( Status );

	// Reset Game
	Level.Game.GotoState('ResetGameCountdown');
}

// Can be changed at any time during the map with a resetgame
function ChangeSettings( bool Status )
{
	// Allies Reinforcements
	if( DefaultAlliesReinforcements == 0 )	DefaultAlliesReinforcements = MyROLevelInfo.Allies.SpawnLimit;
	if( Status )							MyROLevelInfo.Allies.SpawnLimit = AlliesReinforcements;
	else									MyROLevelInfo.Allies.SpawnLimit = DefaultAlliesReinforcements;

	// Axis Reinforcements
	if( DefaultAxisReinforcements == 0 )	DefaultAxisReinforcements = MyROLevelInfo.Axis.SpawnLimit;
	if( Status )							MyROLevelInfo.Axis.SpawnLimit = AxisReinforcements;
	else									MyROLevelInfo.Axis.SpawnLimit = DefaultAxisReinforcements;	

	// Win Limit
	if( DefaultWinLimit == 0 )				DefaultWinLimit = MyROTeamGame.WinLimit;
	if( Status && WinLimit > 0 )			MyROTeamGame.WinLimit = WinLimit;
	else									MyROTeamGame.WinLimit = DefaultWinLimit;

	// Round Limit
	if( DefaultRoundLimit == 0 )			DefaultRoundLimit = MyROTeamGame.RoundLimit;
	if( Status && RoundLimit > 0 )			MyROTeamGame.RoundLimit = RoundLimit;
	else									MyROTeamGame.RoundLimit = DefaultRoundLimit;

	// Max Team Difference
	if( DefaultMaxTeamDiff == 0 )			DefaultMaxTeamDiff = MyROTeamGame.MaxTeamDifference;
	if( Status && MaxTeamDiff > 0 )			MyROTeamGame.MaxTeamDifference = MaxTeamDiff;
	else									MyROTeamGame.MaxTeamDifference = DefaultMaxTeamDiff;

	// Disable FF During Briefing
	if( DefaultFF == 0 )					DefaultFF = MyROTeamGame.FriendlyFireScale;
	if( Status && DisableFFBriefing )		MyROTeamGame.FriendlyFireScale = 0;
	else									MyROTeamGame.FriendlyFireScale = DefaultFF;
}

// Must be separate because this only works at the beginning of the map
function ChangeRoundDuration()
{
	MyROLevelInfo.RoundDuration = RoundDuration;
}

function Respawn( PlayerController Sender )
{
	// Save old pawn ID
	local Pawn P;
	P = Sender.Pawn;

	// Respawn Player
	Sender.Reset();
	MyGameInfo.RestartPlayer( Sender );

	// Destroy old pawn
	P.Destroy();
}

function MatchStatus( bool Status )
{
	if( Status == true )
	{
		MatchLive = true;
		if( DisableFFBriefing )
			MyROTeamGame.FriendlyFireScale = DefaultFF;
		Level.Game.Broadcast( self, "[Realism Match] LIVE LIVE LIVE LIVE LIVE" );
	}
	else
	{
		MatchLive = false;
		AlliesReady = false;
		AxisReady = false;
		if( DisableFFBriefing )
			MyROTeamGame.FriendlyFireScale = 0;
	}

}

// Receives intercepted 'ready' chat messages, sets game status, and announces status
function TeamReady( PlayerReplicationInfo Sender, bool Status )
{
	// Get player name for broadcasts
	local string MyPlayerName;
	local int MyPlayerTeam;
	MyPlayerName = Sender.PlayerName;
	MyPlayerTeam = Sender.Team.TeamIndex;

	if( MyPlayerTeam == 0 ) // axis
	{
		if( !AxisReady && Status )
		{
			AxisReady = true;
			Level.Game.Broadcast( self, "[Realism Match] "$MyPlayerName$" set Axis READY" );
		}
		else if( AxisReady && !Status )
		{
			AxisReady = false;
			Level.Game.Broadcast( self, "[Realism Match] "$MyPlayerName$" set Axis NOT READY" );
		}
	}
	else // allies
	{
		if( !AlliesReady && Status )
		{
			AlliesReady = true;
			Level.Game.Broadcast( self, "[Realism Match] "$MyPlayerName$" set Allies READY" );
		}
		else if( AlliesReady && !Status )
		{
			AlliesReady = false;
			Level.Game.Broadcast( self, "[Realism Match] "$MyPlayerName$" set Allies NOT READY" );
		}
	}

	// If both teams are ready now, make match live
	if( AxisReady && AlliesReady )
		MatchStatus( true );
}

// Catch when the round ends and turn off live, allies/axis ready, and ff
auto state StartUp
{
	function BeginState()
	{
		SetTimer( 5, true );
	}
	function timer()
	{
		if( Level.Game.IsInState('RoundOver') )
		{
			MatchStatus( false ); // turns off all 4 variables
		}
	}
}

// Returns true is the player is an admin
function bool IsAdmin( PlayerController Sender )
{
	return Sender.PlayerReplicationInfo.bAdmin || Sender.PlayerReplicationInfo.bSilentAdmin;
}

// Everything below here just adds user-friendly settings to the mutator
static function string GetDisplayText(string PropName) {
	switch (PropName) {
		case "AlliesReinforcements":	return default.GUIDisplayText[0];
		case "AxisReinforcements":		return default.GUIDisplayText[1];
		case "RoundDuration":			return default.GUIDisplayText[2];
		case "WinLimit":				return default.GUIDisplayText[3];
		case "RoundLimit":				return default.GUIDisplayText[4];
		case "MaxTeamDiff":				return default.GUIDisplayText[5];
		case "DisableFFBriefing":		return default.GUIDisplayText[6];
	}
}
 
static event string GetDescriptionText(string PropName) {
	switch (PropName) {
		case "AlliesReinforcements":	return default.GUIDescText[0];
		case "AxisReinforcements":		return default.GUIDescText[1];
		case "RoundDuration":			return default.GUIDescText[2];
		case "WinLimit":				return default.GUIDescText[3];
		case "RoundLimit":				return default.GUIDescText[4];
		case "MaxTeamDiff":				return default.GUIDescText[5];
		case "DisableFFBriefing":		return default.GUIDescText[6];
	}
	return Super.GetDescriptionText(PropName);
}
 
static function FillPlayInfo(PlayInfo PlayInfo) {
	Super.FillPlayInfo(PlayInfo);  // Always begin with calling parent
 
	PlayInfo.AddSetting("Realism Match", "AlliesReinforcements",GetDisplayText("AlliesReinforcements"),	0, 0, "Text", "3;0:999");
	PlayInfo.AddSetting("Realism Match", "AxisReinforcements",	GetDisplayText("AxisReinforcements"),	0, 1, "Text", "3;0:999");
	PlayInfo.AddSetting("Realism Match", "RoundDuration",		GetDisplayText("RoundDuration"),		0, 2, "Text", "3;0:999");
	PlayInfo.AddSetting("Realism Match", "WinLimit",			GetDisplayText("WinLimit"),				0, 3, "Text", "3;0:999");
	PlayInfo.AddSetting("Realism Match", "RoundLimit",			GetDisplayText("RoundLimit"),			0, 4, "Text", "3;0:999");
	PlayInfo.AddSetting("Realism Match", "MaxTeamDiff",			GetDisplayText("MaxTeamDiff"),			0, 5, "Text", "3;0:999");
	PlayInfo.AddSetting("Realism Match", "DisableFFBriefing",	GetDisplayText("DisableFFBriefing"),	0, 6, "Check");
}

function string GetPlayerList()
{
	local array<PlayerReplicationInfo> AllPRI;
	local int i;
	local string StringToReturn;

	// Get the list of players to kick by showing their PlayerID
	Level.Game.GameReplicationInfo.GetPRIArray(AllPRI);
	for (i = 0; i<AllPRI.Length; i++)
	{
		if( PlayerController(AllPRI[i].Owner) != none && AllPRI[i].PlayerName != "WebAdmin")
		{
			//log(Right("   "$AllPRI[i].PlayerID, 3)$")"@AllPRI[i].PlayerName@" "$PlayerController(AllPRI[i].Owner).GetPlayerIDHash());
			StringToReturn $= " "$AllPRI[i].PlayerName$" "$PlayerController(AllPRI[i].Owner).GetPlayerIDHash()$Chr(2028);
			/*
			"   "$AllPRI[i].PlayerID, 3)$")"@AllPRI[i].PlayerName@" "$PlayerController(AllPRI[i].Owner).GetPlayerIDHash()
			ClientMessage(Right("   "$AllPRI[i].PlayerID, 3)$")"@AllPRI[i].PlayerName@" "$PlayerController(AllPRI[i].Owner).GetPlayerIDHash());
			*/
		}
		else
		{
			//log(Right("   "$AllPRI[i].PlayerID, 3)$")"@AllPRI[i].PlayerName);
			//ClientMessage(Right("   "$AllPRI[i].PlayerID, 3)$")"@AllPRI[i].PlayerName);
		}
	}
	return StringToReturn;
}

defaultproperties
{
     DisableFFBriefing=True
     AlliesReinforcements=1
     AxisReinforcements=1
     WinLimit=999
     RoundLimit=999
     MaxTeamDiff=50
     GUIDisplayText(0)="Allies Reinforcements"
     GUIDisplayText(1)="Axis Reinforcements"
     GUIDisplayText(2)="Round Duration"
     GUIDisplayText(3)="Win Limit"
     GUIDisplayText(4)="Round Limit"
     GUIDisplayText(5)="Max Team Difference"
     GUIDisplayText(6)="Disable FF During Briefing"
     GUIDescText(0)="Number of reinforcement waves alotted to the team (Includes initial spawn, so a value of 0 means no one will spawn)"
     GUIDescText(1)="Number of reinforcement waves alotted to the team (Includes initial spawn, so a value of 0 means no one will spawn)"
     GUIDescText(2)="If set above 0, rounds will last this long. Must reset level to alter. Set at 0 to ignore."
     GUIDescText(3)="During the match, how many rounds must be won to win the match. Set at 0 to ignore."
     GUIDescText(4)="During the match, how many rounds may be played. Set at 0 to ignore."
     GUIDescText(5)="During the match, the max team difference."
     GUIDescText(6)="If checked, friendly fire will be disabled until match is 'LIVE'"
     GroupName="RealismMatch"
     FriendlyName="Realism Match"
     Description="Gives control over reinforcement amounts for each team v1.5"
}
