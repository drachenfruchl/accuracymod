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

struct {
	int displayType = 0

	vector simpleAnchor = < 0.42, 0.935, 0.0 >
	array<var> simpleElements

	vector advancedAnchor = < 0.1, 0.2, 0.0 >
	array<var> advancedElements
} RUI

enum eRuiParts {
	// simple
	header,
	displayTypeArrowR,
	displayTypeArrowL,
	totalShots,
	totalHits,
	overallAccuracy,
	combo,
	comboMax,
	rank

	// advanced...
}

enum eDisplayTypes {
	match,
	recent10,
	session,
	lifetime
}

struct {
	table<string, int> lifetimeHits
	table<string, int> lifetimeShots
	table<string, int> sessionHits
	table<string, int> sessionShots
	table<string, int> sessionCombo
	table<string, int> sessionComboMax
} file

// Utility =========================================================================================================

string function GetWeaponImage( entity weapon ){
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
	// RuiSetString( RUI.simpleElements[ eRuiParts.], "msgText", getWeaponImage( weapon ) )
}

// Init ============================================================================================================

void function Accuracy_Init(){
	RUI.simpleAnchor = < 
		GetConVarFloat( "cv_acc_simple_posX" ), 
		GetConVarFloat( "cv_acc_simple_posY" ), 
		0.0 
	>

	RUI.advancedAnchor = < 
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
}

// Rui creation ====================================================================================================

var function MakeRUI( string msg )
{
	var rui = RuiCreate( $"ui/cockpit_console_text_top_left.rpak", clGlobal.topoCockpitHudPermanent, RUI_DRAW_COCKPIT, 0 )

	RuiSetInt( 		rui, "maxLines", 	1 			)
	RuiSetInt( 		rui, "lineNum", 	1 			)
	RuiSetFloat2( 	rui, "msgPos", 		< 0,0,0 > 		)
	RuiSetFloat( 	rui, "msgFontSize", 15.0 	)
	RuiSetFloat( 	rui, "msgAlpha", 	1.0 		)
	RuiSetFloat3( 	rui, "msgColor", 	COLORS.WHITE 		)
	RuiSetFloat( 	rui, "thicken", 	0.0		 	)
	RuiSetString( 	rui, "msgText", 	msg 		)

	return rui
}

void function CreateAccuracyRUI(){
	RUI.simpleElements[ eRuiParts.header ] 				= MakeRUI( "Header" )
	RUI.simpleElements[ eRuiParts.displayTypeArrowR ] 	= MakeRUI( ">" )
	RUI.simpleElements[ eRuiParts.displayTypeArrowL ] 	= MakeRUI( "<" )
	RUI.simpleElements[ eRuiParts.totalShots ]			= MakeRUI( "Total shots" )
	RUI.simpleElements[ eRuiParts.totalHits ]			= MakeRUI( "Total hits" )
	RUI.simpleElements[ eRuiParts.overallAccuracy ]		= MakeRUI( "Overall accuracy" )
	RUI.simpleElements[ eRuiParts.combo ]				= MakeRUI( "Combo" )
	RUI.simpleElements[ eRuiParts.comboMax ]			= MakeRUI( "Combo max" )
	RUI.simpleElements[ eRuiParts.rank ]				= MakeRUI( "Rank" )
	// ...

	SetInitialRUIPos()
}

void function SetInitialRUIPos(){
	
	float size = GetConVarFloat( "acc_font_size" )
	float lineGap = size * 0.0013

	// Simple
	vector anchor = RUI.simpleAnchor

	RuiSetFloat2( 	RUI.simpleElements[ eRuiParts.header ], 			"msgPos",	anchor	)
	RuiSetFloat2( 	RUI.simpleElements[ eRuiParts.displayTypeArrowR ], 	"msgPos",	anchor	)
	RuiSetFloat2( 	RUI.simpleElements[ eRuiParts.displayTypeArrowL ], 	"msgPos",	anchor	)
	RuiSetFloat2( 	RUI.simpleElements[ eRuiParts.totalShots ], 		"msgPos",	anchor	)
	RuiSetFloat2( 	RUI.simpleElements[ eRuiParts.totalHits ], 			"msgPos",	anchor	)
	RuiSetFloat2( 	RUI.simpleElements[ eRuiParts.overallAccuracy ], 	"msgPos",	anchor	)
	RuiSetFloat2( 	RUI.simpleElements[ eRuiParts.combo ], 				"msgPos",	anchor	)
	RuiSetFloat2( 	RUI.simpleElements[ eRuiParts.comboMax ], 			"msgPos",	anchor	)
	RuiSetFloat2( 	RUI.simpleElements[ eRuiParts.rank ], 				"msgPos",	anchor	)

	// Advanced
	anchor = RUI.advancedAnchor
}



void function UpdateAccuracyRUI(){
	// Simple


	switch( RUI.displayType ){
		case eDisplayTypes.match:
			
			break
		case eDisplayTypes.last10:
			
			break
		case eDisplayTypes.session:
			
			break
		case eDisplayTypes.lifetime:
			
			break
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