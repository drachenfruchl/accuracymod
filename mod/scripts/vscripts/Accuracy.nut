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
	RuiSetFloat( 	rui, "msgAlpha", 	1.0 			)
	RuiSetFloat3( 	rui, "msgColor", 	COLORS.WHITE 	)
	RuiSetFloat( 	rui, "thicken", 	0.0		 		)
	RuiSetString( 	rui, "msgText", 	msg 			)

	return rui
}

void function CreateAccuracyRUI(){
// Simple
	// Header
	SIMPLE.allElements[eSSections.header][eSHeader.weaponName] 		= MakeRUI( "" )
	SIMPLE.allElements[eSSections.header][eSHeader.rank] 			= MakeRUI( "" )
	SIMPLE.allElements[eSSections.header][eSHeader.score] 			= MakeRUI( "" )

	// Active
	SIMPLE.allElements[eSSections.active][eSMatch.overallAccuracy] 	= MakeRUI( "" )
	SIMPLE.allElements[eSSections.active][eSMatch.totalShots] 		= MakeRUI( "" )
	SIMPLE.allElements[eSSections.active][eSMatch.totalHits] 		= MakeRUI( "" )
	SIMPLE.allElements[eSSections.active][eSMatch.combo] 			= MakeRUI( "" )
	SIMPLE.allElements[eSSections.active][eSMatch.comboMax] 		= MakeRUI( "" )

	// Subs
		// Recent10
		for (int i = 0; i < 10; i++ )
			SIMPLE.allElements[eSSections.sub][i] = MakeRUI( "" )

		// Match
		SIMPLE.allElements[eSSections.sub][eSMatch.overallAccuracy]		= MakeRUI( "" )
		SIMPLE.allElements[eSSections.sub][eSMatch.totalShots] 			= MakeRUI( "" )
		SIMPLE.allElements[eSSections.sub][eSMatch.totalHits] 			= MakeRUI( "" )
		SIMPLE.allElements[eSSections.sub][eSMatch.combo] 				= MakeRUI( "" )
		SIMPLE.allElements[eSSections.sub][eSMatch.comboMax] 			= MakeRUI( "" )

		// Lifetime
		SIMPLE.allElements[eSSections.sub][eSLifetime.overallAccuracy] 	= MakeRUI( "" )
		SIMPLE.allElements[eSSections.sub][eSLifetime.totalShots] 		= MakeRUI( "" )
		SIMPLE.allElements[eSSections.sub][eSLifetime.totalHits] 		= MakeRUI( "" )
		SIMPLE.allElements[eSSections.sub][eSLifetime.comboMax] 		= MakeRUI( "" )

// Advanced
	// . . .
}

void function SetInitialRUIpos(){
	float size = GetConVarFloat( "acc_font_size" )
	float lineGap = size * 0.0013

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
	vector a = SIMPLE.anchor
	RuiSetFloat2( SIMPLE.allElements[eSSections.header][eSHeader.weaponName], 		"msgPos",	< a.x, a.y, a.z > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.header][eSHeader.rank], 			"msgPos",	< a.x, a.y, a.z > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.header][eSHeader.score], 			"msgPos",	< a.x, a.y, a.z > )

	RuiSetFloat2( SIMPLE.allElements[eSSections.active][eSMatch.overallAccuracy], 	"msgPos",	< a.x, a.y, a.z > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.active][eSMatch.totalShots], 		"msgPos",	< a.x, a.y, a.z > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.active][eSMatch.totalHits], 		"msgPos",	< a.x, a.y, a.z > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.active][eSMatch.combo], 			"msgPos",	< a.x, a.y, a.z > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.active][eSMatch.comboMax], 			"msgPos",	< a.x, a.y, a.z > )

	for (int i = 0; i < 10; i++ )
		RuiSetFloat2( SIMPLE.allElements[eSSections.sub][i], 						"msgPos",	< a.x, a.y, a.z > )

	RuiSetFloat2( SIMPLE.allElements[eSSections.sub][eSMatch.overallAccuracy], 		"msgPos",	< a.x, a.y, a.z > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.sub][eSMatch.totalShots], 			"msgPos",	< a.x, a.y, a.z > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.sub][eSMatch.totalHits], 			"msgPos",	< a.x, a.y, a.z > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.sub][eSMatch.combo], 				"msgPos",	< a.x, a.y, a.z > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.sub][eSMatch.comboMax], 			"msgPos",	< a.x, a.y, a.z > )

	RuiSetFloat2( SIMPLE.allElements[eSSections.sub][eSLifetime.overallAccuracy], 	"msgPos",	< a.x, a.y, a.z > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.sub][eSLifetime.totalShots], 		"msgPos",	< a.x, a.y, a.z > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.sub][eSLifetime.totalHits], 		"msgPos",	< a.x, a.y, a.z > )
	RuiSetFloat2( SIMPLE.allElements[eSSections.sub][eSLifetime.comboMax], 			"msgPos",	< a.x, a.y, a.z > )

	// Advanced
	a = ADVANCED.anchor
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

	return weapon.GetAmmoPerShot()
}

void function Accuracy_OnWeaponBulletHit( entity weapon, WeaponBulletHitParams hitParams )
{
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