untyped

/* important stuff
RuiTrackImage( rui, "hudIcon", weapon, RUI_TRACK_WEAPON_HUD_ICON )
weapon.GetWeaponInfoFileKeyField( "projectilemodel" )
*/

global function Accuracy_Init
global function Accuracy_OnWeaponPrimaryAttack
global function Accuracy_OnWeaponBulletHit
global function Accuracy_OnProjectileCollision

struct {
	vector WHITE 	= < 0.88, 0.88, 0.88 >
	vector GREY		= < 0.45, 0.45, 0.45 >
	vector GOLD		= < 1.0,  0.82, 0.25 >
	vector GREEN	= < 0.3,  0.95, 0.45 >
	vector YELLOW	= < 1.0,  0.82, 0.15 >
	vector RED		= < 1.0,  0.28, 0.28 >
} COLORS

struct {
	int totalHits = 0
	int totalShots = 0
	int totalShotsIgnored = 0
	float accuracy = 0.0
	int combo = 0
	int comboMax = 0

	string currentWeapon = ""
} ACCURACY

enum eDisplayTypes {
	recent10,
	session,
	lifetime
}

enum eSSections {
	header,
	active,
	sub,
	nav
}
enum eSHeader {
	weaponName,
	rank,
	score
}
enum eSMatch {
	overallAccuracy,
	totalShots,
	totalHits,
	combo,
	comboMax
}
enum eSSession {
	overallAccuracy,
	totalShots,
	totalHits,
	comboMax
}
enum eSLifetime {
	overallAccuracy,
	totalShots,
	totalHits,
	comboMax
}
enum eSNav {
	displayTypeArrowL,
	displayType
	displayTypeArrowR
}

enum eDeductionTypes {
	miss,
	// blunderCombo,
	blunderCombo5,  // Break combo after 5 consecutive hits
	blunderCombo10, // Break combo after 10 consecutive hits
	onehitWonder,   // Left enemy on 1hp
	fall,           // Death by pit
	meleed,         // Killed enemy with melee
	gotMeleed,      // Died because of melee
	noscoped,       // Killed enemy using noscope kraber
	grenadiered     // Shot a grenadier bullet (4x penalty on coldwar by design)
}
enum eRewardTypes {
	hit,
	// combo,
	combo5,       // 5 consecutive hits
	combo10,      // 10 consecutive hits
	combo15,      // 15 fucking consecutive hits
	longrange50,  // Kill from 50m away
	longrange100, // Kill from 50m away
	longrange150, // Kill from 50m away
	longrange200, // Kill from 50m away
	directGrenadierHitNonCW // Direct hits using EPG, Softball etc except coldwar (kys)
}

struct {
	int displayType = 0
	vector anchor // Defined in Init

	// RuiSetString( SIMPLE.allElements[eSSections.nav][eSNav.displayTypeArrowR], "msgText", "gabagool" )

	array< array<var> > allElements
	// array<var> header
	// array<var> active
	// array<var> sub
	// array<var> nav

	// Subs to switch to
	array<var> recent10
	array<var> session
	array<var> lifetime
} SIMPLE

struct {
	int displayType = 0
	vector anchor // Defined in Init

	array< array<var> > allElements
	// array<var> header
	// array<var> active
	// array<var> sub
	// array<var> nav
} ADVANCED

// Simple New
// header // [WeaponName] [Rank]
// *varies depending on displaytype*
// active // match: [overallAccuracy] | [totalShots] [totalHits] | [combo] (max. [comboMax])
// sub // recent10: [ Acc | Combo ] [ Acc | Combo ] [ Acc | Combo ] [ Acc | Combo ] . . .
// sub // session: [overallAccuracy] | [totalShots] [totalHits] | [comboMax]
// sub // lifetime: [overallAccuracy] | [totalShots] [totalHits] | [comboMax]
// navigation // [displayTypeArrowL] [displayType] [displayTypeArrowR]

struct {
	int totalScore = 0

	// Speed mult as exponential graph starting at x kmh
	// float speedMult

	// Range mult as linear graph starting at x meters
	// float rangeMult

	// Flat score mult for NPCs
	// float npcMult = 0.2

	table<int> rewardTable = {
		[eRewardTypes.hit] 						= 10,   // Hit a shot
		// [eRewardTypes.combo] 				= ,
		[eRewardTypes.combo5] 					= 100,  // 5 consecutive hits
		[eRewardTypes.combo10] 					= 1000, // 10 consecutive hits
		[eRewardTypes.combo15] 					= 5000, // 15 fucking consecutive hits
		[eRewardTypes.longrange50] 				= 50,   // Kill from 50m away
		[eRewardTypes.longrange100] 			= 100,  // Kill from 50m away
		[eRewardTypes.longrange150] 			= 250,  // Kill from 50m away
		[eRewardTypes.longrange200] 			= 500,  // Kill from 50m away
		[eRewardTypes.directGrenadierHitNonCW]  = 500   // Direct hits using EPG, Softball etc except coldwar (kys)
	}

	table<int> deductionTable = {
		[eDeductionTypes.miss] 		   = 5,		  // Missed a shot
		// [eDeductionTypes.blunderCombo  = ,
		[eDeductionTypes.blunderCombo5]   = 20,   // Break combo after 5 consecutive hits
		[eDeductionTypes.blunderCombo10]  = 200,  // Break combo after 10 consecutive hits
		[eDeductionTypes.onehitWonder]    = 50,   // Left enemy on 1hp
		[eDeductionTypes.fall]            = 1000, // Death by pit
		[eDeductionTypes.meleed]          = 500,  // Killed enemy with melee
		[eDeductionTypes.gotMeleed]       = 100,  // Died because of melee
		[eDeductionTypes.noscoped]        = 300,  // Killed enemy using noscope kraber
		[eDeductionTypes.grenadiered]     = 25    // Shot a grenadier bullet (4x penalty on coldwar by design)
	}
} score

struct {
	table<string, int> lifetimeHits
	table<string, int> lifetimeShots
	table<string, int> sessionHits
	table<string, int> sessionShots
	table<string, int> sessionCombo
	table<string, int> sessionComboMax
} file

// Utility =========================================================================================================

string function GetWeaponImageString( entity weapon ){
	string weaponClassName = weapon.GetWeaponClassName()
	string itemImageString = ""
	try{
		itemImageString = GetItemImage( weaponClassName ).tostring()
		itemImageString = itemImageString.slice( 2, -1 )
	}catch(e){
		return ""
	}
	return "%$" + itemImageString + "%"
}

string function GetWeaponDisplayName( entity weapon ){
	return Localize( weapon.GetWeaponInfoFileKeyField( "printname" ) )
}

void function OnSelectedWeaponChanged( entity weapon ){
	string weaponDisplayName = weapon.GetWeaponDisplayName()
	RuiSetString( SIMPLE.allElements[eSSections.header][eSHeader.weaponName], "msgText", weaponDisplayName )
}

void function Simple_SetAlpha( float alpha ){
	foreach( array<var> section in SIMPLE.allElements ){
		foreach( var rui in section )
			RuiSetFloat( rui, "msgAlpha", alpha )
	}
}

void function Simple_SetRUISectionAlpha( int section, float alpha ){
	foreach( var rui in SIMPLE.allElements[section] )
		RuiSetFloat( rui, "msgAlpha", alpha )
}

void function Simple_SetRUIElementAlpha( int section, int element, float alpha ){
	RuiSetFloat( SIMPLE.allElements[section][element], "msgAlpha", alpha )
}

void function Advanced_SetAlpha( float alpha ){
	foreach( array<var> section in ADVANCED.allElements ){
		foreach( var rui in section )
			RuiSetFloat( rui, "msgAlpha", alpha )
	}
}

void function Advanced_SetRUISectionAlpha( int section, float alpha ){
	foreach( var rui in ADVANCED.allElements[section] )
		RuiSetFloat( rui, "msgAlpha", alpha )
}

void function Advanced_SetRUIElementAlpha( int section, int element, float alpha ){
	RuiSetFloat( ADVANCED.allElements[section][element], "msgAlpha", alpha )
}

// Init ============================================================================================================

void function Accuracy_Init(){
	SIMPLE.anchor = <
		GetConVarFloat( "cv_acc_simple_posX" ),
		GetConVarFloat( "cv_acc_simple_posY" ),
		0.0
	>

	ADVANCED.anchor = <
		GetConVarFloat( "cv_acc_advanced_posX" ),
		GetConVarFloat( "cv_acc_advanced_posY" ),
		0.0
	>

	// LoadLifetimeStats()
	// thread WatchWeaponSwitch()
	// AddLocalPlayerDidDamageCallback( Accuracy_OnDamage )

	// AddCallback_OnSelectedWeaponChanged( OnSelectedWeaponChanged )
	// RegisterButtonPressedCallback( KEY_TAB, OpenAdvancedAccMenu )

	CreateAccuracyRUI()
	SetInitialRUIpos()
}

// Rui creation ====================================================================================================

var function MakeRUI( string msg ){
	var rui = RuiCreate( $"ui/cockpit_console_text_top_left.rpak", clGlobal.topoCockpitHudPermanent, RUI_DRAW_COCKPIT, 0 )

	RuiSetInt( 		rui, "maxLines", 	1 				)
	RuiSetInt( 		rui, "lineNum", 	1 				)
	RuiSetFloat2( 	rui, "msgPos", 		< 0, 0, 0 > 	)
	RuiSetFloat( 	rui, "msgFontSize", 15.0 			)
	RuiSetFloat( 	rui, "msgAlpha", 	0.0 			)
	RuiSetFloat3( 	rui, "msgColor", 	COLORS.WHITE 	)
	RuiSetFloat( 	rui, "thicken", 	0.0		 		)
	RuiSetString( 	rui, "msgText", 	msg 			)

	return rui
}

void function CreateAccuracyRUI(){
// Simple
	// Header
	SIMPLE.allElements[eSSections.header][eSHeader.weaponName] 		= MakeRUI( "Volt" )
	SIMPLE.allElements[eSSections.header][eSHeader.rank] 			= MakeRUI( "SS" )
	SIMPLE.allElements[eSSections.header][eSHeader.score] 			= MakeRUI( "6547" )

	// Active
	SIMPLE.allElements[eSSections.active][eSMatch.overallAccuracy] 	= MakeRUI( "67.67%" )
	SIMPLE.allElements[eSSections.active][eSMatch.totalShots] 		= MakeRUI( "450" )
	SIMPLE.allElements[eSSections.active][eSMatch.totalHits] 		= MakeRUI( "362" )
	SIMPLE.allElements[eSSections.active][eSMatch.combo] 			= MakeRUI( "5" )
	SIMPLE.allElements[eSSections.active][eSMatch.comboMax] 		= MakeRUI( "9" )

	// Subs
		// Recent10
		for (int i = 0; i < 10; i++ )
			SIMPLE.allElements[eSSections.sub][i] = MakeRUI( format( "[%.2f|%i]", RandomFloat( 100.0 ), RandomInt( 15 ) ) )

		// Match
		SIMPLE.allElements[eSSections.sub][eSMatch.overallAccuracy]		= MakeRUI( "67.67%" )
		SIMPLE.allElements[eSSections.sub][eSMatch.totalShots] 			= MakeRUI( "450" )
		SIMPLE.allElements[eSSections.sub][eSMatch.totalHits] 			= MakeRUI( "362" )
		SIMPLE.allElements[eSSections.sub][eSMatch.combo] 				= MakeRUI( "5" )
		SIMPLE.allElements[eSSections.sub][eSMatch.comboMax] 			= MakeRUI( "9" )

		// Lifetime
		SIMPLE.allElements[eSSections.sub][eSLifetime.overallAccuracy] 	= MakeRUI( "69.69%"" )
		SIMPLE.allElements[eSSections.sub][eSLifetime.totalShots] 		= MakeRUI( "540" )
		SIMPLE.allElements[eSSections.sub][eSLifetime.totalHits] 		= MakeRUI( "622" )
		SIMPLE.allElements[eSSections.sub][eSLifetime.comboMax] 		= MakeRUI( "2" )

// Advanced
	// . . .
}

void function SetInitialRUIpos(){
	vector anchor
	float fontSize
	float gapHeight
	float offsetY
	float offsetX

	// Simple Old
	// [ ACC ] wepDisplay
	// 67.2% Accuracy | 321 Shots 174 Hits | x8 Combo ( pb 13 )
	// all time 23.4% | 7123 Shots 6523 Hits

	// Simple New
	// header // [WeaponName] [Rank]
	// *varies depending on displaytype*
	// active, sub // match: [overallAccuracy] | [totalShots] [totalHits] | [combo] (max. [comboMax])
	// sub // recent10: [ Acc | Combo ] [ Acc | Combo ] [ Acc | Combo ] [ Acc | Combo ] . . .
	// sub // session: [overallAccuracy] | [totalShots] [totalHits] | [comboMax]
	// sub // lifetime: [overallAccuracy] | [totalShots] [totalHits] | [comboMax]
	// navigation // [displayTypeArrowL] [displayType] [displayTypeArrowR]

	// Simple
	anchor = SIMPLE.anchor
	fontSize = GetConVarFloat( "cv_acc_simple_fontSize" )
	gapHeight = fontSize * 0.0013

	// First row
	offsetY = gapHeight * 1
	RuiSetFloat2( SIMPLE.allElements[eSSections.header][eSHeader.weaponName], 		"msgPos",	< anchor.x, anchor.y + offsetY, 0.0 > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.header][eSHeader.rank], 			"msgPos",	< anchor.x, anchor.y + offsetY, 0.0 > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.header][eSHeader.score], 			"msgPos",	< anchor.x, anchor.y + offsetY, 0.0 > )

	// Second row
	offsetY = gapHeight * 2
	RuiSetFloat2( SIMPLE.allElements[eSSections.active][eSMatch.overallAccuracy], 	"msgPos",	< anchor.x, anchor.y + offsetY, 0.0 > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.active][eSMatch.totalShots], 		"msgPos",	< anchor.x, anchor.y + offsetY, 0.0 > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.active][eSMatch.totalHits], 		"msgPos",	< anchor.x, anchor.y + offsetY, 0.0 > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.active][eSMatch.combo], 			"msgPos",	< anchor.x, anchor.y + offsetY, 0.0 > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.active][eSMatch.comboMax], 			"msgPos",	< anchor.x, anchor.y + offsetY, 0.0 > )

	// Third rows
	offsetY = gapHeight * 3
	offsetX = 0.0 // Get total element width
	for (int i = 0; i < 10; i++ )
		RuiSetFloat2( SIMPLE.allElements[eSSections.sub][i], 						"msgPos",	< anchor.x + (offsetX * i), anchor.y + offsetY, 0.0 > )

	RuiSetFloat2( SIMPLE.allElements[eSSections.sub][eSMatch.overallAccuracy], 		"msgPos",	< anchor.x, anchor.y + offsetY, 0.0 > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.sub][eSMatch.totalShots], 			"msgPos",	< anchor.x, anchor.y + offsetY, 0.0 > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.sub][eSMatch.totalHits], 			"msgPos",	< anchor.x, anchor.y + offsetY, 0.0 > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.sub][eSMatch.combo], 				"msgPos",	< anchor.x, anchor.y + offsetY, 0.0 > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.sub][eSMatch.comboMax], 			"msgPos",	< anchor.x, anchor.y + offsetY, 0.0 > )

	RuiSetFloat2( SIMPLE.allElements[eSSections.sub][eSLifetime.overallAccuracy], 	"msgPos",	< anchor.x, anchor.y + offsetY, 0.0 > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.sub][eSLifetime.totalShots], 		"msgPos",	< anchor.x, anchor.y + offsetY, 0.0 > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.sub][eSLifetime.totalHits], 		"msgPos",	< anchor.x, anchor.y + offsetY, 0.0 > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.sub][eSLifetime.comboMax], 			"msgPos",	< anchor.x, anchor.y + offsetY, 0.0 > )

	// Advanced
	anchor = SIMPLE.anchor
	fontSize = GetConVarFloat( "cv_acc_advanced_fontSize" )
	gapHeight = fontSize * 0.0013
}

bool function isAdvancedMenu(){
	return false
}

void function UpdateAccuracyRUI(){
	if( !isAdvancedMenu() ){
		switch( SIMPLE.displayType ){
				// case eDisplayTypes.match:
				//
				// 	break
			case eDisplayTypes.last10:

				break
			case eDisplayTypes.session:

				break
			case eDisplayTypes.lifetime:

				break
		}
	} else {
		switch( ADVANCED.displayType ){
				// case eDisplayTypes.match:
				//
				// 	break
			case eDisplayTypes.last10:

				break
			case eDisplayTypes.session:

				break
			case eDisplayTypes.lifetime:

				break
		}
	}

	// Advanced
}

// miss,
// 	// blunderCombo,
// 	blunderCombo5,  // Break combo after 5 consecutive hits
// 	blunderCombo10, // Break combo after 10 consecutive hits
// 	onehitWonder,   // Left enemy on 1hp
// 	fall,           // Death by pit
// 	meleed,         // Killed enemy with melee
// 	gotMeleed,      // Died because of melee
// 	noscoped,       // Killed enemy using noscope kraber
// 	grenadiered     // Shot a grenadier bullet (4x penalty on coldwar by design)
// }
// enum eRewardTypes {
// 	hit,
// 	// combo,
// 	combo5,       // 5 consecutive hits
// 	combo10,      // 10 consecutive hits
// 	combo15,      // 15 fucking consecutive hits
// 	longrange50,  // Kill from 50m away
// 	longrange100, // Kill from 50m away
// 	longrange150, // Kill from 50m away
// 	longrange200, // Kill from 50m away
// 	directGrenadierHitNonCW // Direct hits using EPG, Softball etc except coldwar (kys)
// }
void function updateScore_hitRegistered( WeaponBulletHitParams hitparams ){
	entity hitEnt = hitparams.hitEnt

	// Rewards
	// ...
	if( !hitEnt.IsWorld() ){
		if( hitEnt.IsNPC() )
			score.totalScore += score.rewardTable[eRewardTypes.hit] * score.npcMult
		else
			score.totalScore += score.rewardTable[eRewardTypes.hit]
		return
	}

	// Deductions
	// Missed shot
	if( hitEnt.IsWorld() ){
		score.totalScore -= score.deductionTable[eDeductionTypes.miss]
		return
	}

	if()
}

void function updateScore_killRegistered( WeaponBulletHitParams hitparams ){

}



































var function Accuracy_OnWeaponPrimaryAttack( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	/*
	entity owner = weapon.GetWeaponOwner()
	if ( IsValid( owner ) && owner == GetLocalViewPlayer() )
	{
		string wepName = weapon.GetWeaponClassName()
		if ( ACCURACY.currentWeapon == "" )
			ACCURACY.currentWeapon = wepName
		// RegisterShot( wepName )
	}
	*/

	// Does this work?
	weapon.acc.lastBarrelIndex <- attackParams.barrelIndex

	return weapon.GetAmmoPerShot()
}

void function Accuracy_OnWeaponBulletHit( entity weapon, WeaponBulletHitParams hitParams )
{
	// Does this even work?
	if( weapon.acc.lastBarrelIndex == weapon.GetWeaponPrimaryAmmoCount() + 1 )
		return

	/*
	entity owner = weapon.GetWeaponOwner()
	if ( !IsValid( owner ) || owner != GetLocalViewPlayer() )
		return

	string signifier = expect string( hitParams.hitEnt.GetSignifierName() )
	string wepName = weapon.GetWeaponClassName()
	if ( ACCURACY.currentWeapon == "" )
		ACCURACY.currentWeapon = wepName

	if ( IGNORED_SIGNIFIERS.contains( signifier ) )
	{
		ACCURACY.totalShotsIgnored++
		recalculateAccuracy()
		updateAccuracyRUI()
	}
	// hits and misses handled by AddLocalPlayerDidDamageCallback
	*/
}

void function Accuracy_OnProjectileCollision( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	// hits handled by AddLocalPlayerDidDamageCallback
}

/*
bool function shouldHit( entity attacker, entity hitEnt )
{
	if ( !IsValid( hitEnt ) )
		return false
	if ( !( hitEnt.IsNPC() || hitEnt.IsPlayer() ) )
		return false
	if ( !IsValid( attacker ) )
		return false
	return hitEnt.GetTeam() != attacker.GetTeam()
}

void function Accuracy_OnDamage( entity attacker, entity victim, vector damagePos, int damageType )
{
	if ( attacker != GetLocalClientPlayer() ) return
	if ( !IsValid( victim ) ) return
	if ( !( victim.IsNPC() || victim.IsPlayer() ) ) return
	if ( victim.GetTeam() == attacker.GetTeam() ) return

	entity weapon = attacker.GetActiveWeapon()
	string wepName = IsValid( weapon ) ? weapon.GetWeaponClassName() : ACCURACY.currentWeapon
	if ( wepName == "" ) return

	// RegisterHit( wepName )
}

void function recalculateAccuracy()
{
	float totalHits = ACCURACY.totalHits.tofloat()
	float totalShots = ACCURACY.totalShots.tofloat()
	ACCURACY.accuracy = totalShots > 0.0 ? ( totalHits / totalShots ) * 100.0 : 0.0
}
*/