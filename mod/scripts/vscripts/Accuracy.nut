untyped

/* important stuff
RuiTrackImage( rui, "hudIcon", weapon, RUI_TRACK_WEAPON_HUD_ICON )
weapon.GetWeaponInfoFileKeyField( "projectilemodel" )
*/

global function Accuracy_Init
global function Accuracy_OnWeaponPrimaryAttack
global function Accuracy_OnWeaponBulletHit
global function Accuracy_OnProjectileCollision

const float  ALPHA        = 0.95

struct {
	vector WHITE 	= < 0.88, 0.88, 0.88 >
	vector GREY		= < 0.45, 0.45, 0.45 >
	vector GOLD		= < 1.0,  0.82, 0.25 >
	vector GREEN	= < 0.3,  0.95, 0.45 >
	vector YELLOW	= < 1.0,  0.82, 0.15 >
	vector RED		= < 1.0,  0.28, 0.28 >
} COLORS

struct RUI {
	int 	maxLines 	= 1
	int 	lineNum		= 1
	vector 	msgPos 		= < 0, 0, 0 > //
	float 	msgFontSize = 0 //
	float 	msgAlpha 	= 0.0
	vector 	msgColor 	= < 0, 0, 0 > //
	float 	thicken 	= 0.0 //
	string 	msgText 	= ""
	var 	element		= null
} 

enum eRuiParts {
	header   = 0,
	session  = 1,
	lifetime = 2,

	_count_
}

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
	table<string, int> lifetimeHits
	table<string, int> lifetimeShots
	table<string, int> sessionHits
	table<string, int> sessionShots
	table<string, int> sessionCombo
	table<string, int> sessionComboMax

	array<RUI>[ eRuiParts._count_ ] ruiElements
} file

const string SAVE_DIR = ""

const array<string> IGNORED_SIGNIFIERS = []
const array<string> PROJECTILE_WEAPONS = [
	"mp_weapon_smr",
	"mp_weapon_epg",
	"mp_weapon_softball",
	"mp_weapon_mgl",
	"mp_weapon_rocket_launcher",
	"mp_weapon_arc_launcher"
]

void function Accuracy_Init()
{
	// LoadLifetimeStats()
	createAccuracyRUI()
	// thread WatchWeaponSwitch()
	AddLocalPlayerDidDamageCallback( Accuracy_OnDamage )

	AddCallback_OnSelectedWeaponChanged( OnSelectedWeaponChanged )
	// RegisterButtonPressedCallback( KEY_TAB, OpenAdvancedAccMenu )
	thread WatchSettings()
}

void function LoadLifetimeStats()
{
	NSLoadFile( "hits.json",
		void function( string content )
		{
			if ( content != "" )
			{
				table data = DecodeJSON( content )
				foreach ( string k, var v in data )
					file.lifetimeHits[k] = int( v )
			}
			updateAccuracyRUI()
		}
	)
	NSLoadFile( "shots.json",
		void function( string content )
		{
			if ( content != "" )
			{
				table data = DecodeJSON( content )
				foreach ( string k, var v in data )
					file.lifetimeShots[k] = int( v )
			}
			updateAccuracyRUI()
		}
	)
}

void function SaveLifetimeStats()
{
	NSSaveJSONFile( "hits.json", file.lifetimeHits )
	NSSaveJSONFile( "shots.json", file.lifetimeShots )
}

RUI function MakeRUI( vector pos, float fontSize, vector color, float thicken )
{
	RUI newRui
	newRui.element = RuiCreate( $"ui/cockpit_console_text_top_left.rpak", clGlobal.topoCockpitHudPermanent, RUI_DRAW_COCKPIT, 0 )

	newRui.maxLines 	= 1 
	newRui.lineNum 		= 1 
	newRui.msgPos 		= pos 
	newRui.msgFontSize 	= fontSize 
	newRui.msgAlpha 	= 1.0 
	newRui.msgColor 	= color 
	newRui.thicken 		= thicken 
	newRui.msgText 		= "" 

	RuiSetInt( 		newRui.element, "maxLines", 	newRui.maxLines 	)
	RuiSetInt( 		newRui.element, "lineNum", 		newRui.lineNum 		)
	RuiSetFloat2( 	newRui.element, "msgPos", 		newRui.msgPos 		)
	RuiSetFloat( 	newRui.element, "msgFontSize", 	newRui.msgFontSize 	)
	RuiSetFloat( 	newRui.element, "msgAlpha", 	newRui.msgAlpha 	)
	RuiSetFloat3( 	newRui.element, "msgColor", 	newRui.msgColor 	)
	RuiSetFloat( 	newRui.element, "thicken", 		newRui.thicken 		)
	RuiSetString( 	newRui.element, "msgText", 		newRui.msgText 		)

	return newRui
}

void function createAccuracyRUI()
{

	file.ruiElements[ eRuiParts.header   ].append( MakeRUI( Vector( 0.0, 0.0, 0.0 ), 16.0, COLORS.GOLD, 0.15 ) )
	file.ruiElements[ eRuiParts.session  ].append( MakeRUI( Vector( 0.0, 0.0, 0.0 ), 16.0, COLORS.WHITE, 0.0 ) )
	file.ruiElements[ eRuiParts.lifetime ].append( MakeRUI( Vector( 0.0, 0.0, 0.0 ), 14.0, COLORS.GREY, 0.0 ) )
	
	//
	file.ruiElements[ eRuiParts.header   ].append( MakeRUI( Vector( 0.0, 0.0, 0.0 ), 30.0, COLORS.RED, 0.0 ) )
	//

	updateAccuracyRUI()
	// thread WatchScoreboard()
	// thread WatchSettings()
}

void function OnSelectedWeaponChanged( entity weapon ){
	RuiSetString( file.ruiElements[ eRuiParts.header ][1].element, "msgText", getWeaponImage( weapon ) )
}

string function getWeaponImage( entity weapon ){
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

void function WatchSettings()
{
	float lastX     = -1.0
	float lastY     = -1.0
	float lastSize  = -1.0

	while ( true )
	{
		wait 0.2

		float x    = GetConVarFloat( "cv_acc_pos_x" )
		float y    = GetConVarFloat( "cv_acc_pos_y" )
		float size = GetConVarFloat( "cv_acc_font_size" )

		if ( x == lastX && y == lastY && size == lastSize )
			continue

		lastX    = x
		lastY    = y
		lastSize = size

		float lineGap = size * 0.0013
		RuiSetFloat2( file.ruiElements[ eRuiParts.header ][0].element,   "msgPos", Vector( x, y,              0.0 ) )
		RuiSetFloat2( file.ruiElements[ eRuiParts.session ][0].element,  "msgPos", Vector( x, y + lineGap,    0.0 ) )
		RuiSetFloat2( file.ruiElements[ eRuiParts.lifetime ][0].element, "msgPos", Vector( x, y + lineGap*2,  0.0 ) )

		RuiSetFloat( file.ruiElements[ eRuiParts.header ][0].element,   "msgFontSize", size + 1.5 )
		RuiSetFloat( file.ruiElements[ eRuiParts.session ][0].element,  "msgFontSize", size )
		RuiSetFloat( file.ruiElements[ eRuiParts.lifetime ][0].element, "msgFontSize", size - 1.5 )

		updateAccuracyRUI()
	}
}

void function WatchScoreboard()
{
	while ( true )
	{
		WaitFrame()
		bool alwaysShow = GetConVarInt( "cv_acc_always_show" ) == 1
		float targetAlpha = ( alwaysShow || clGlobal.showingScoreboard ) ? ALPHA : 0.0
		RuiSetFloat( file.ruiElements[ eRuiParts.header ][0].element,   "msgAlpha", targetAlpha )
		RuiSetFloat( file.ruiElements[ eRuiParts.session ][0].element,  "msgAlpha", targetAlpha )
		float ltAlpha = GetConVarInt( "cv_acc_show_lifetime" ) == 1 ? targetAlpha : 0.0
		RuiSetFloat( file.ruiElements[ eRuiParts.lifetime ][0].element, "msgAlpha", ltAlpha )
	}
}

void function WatchWeaponSwitch()
{
	while ( true )
	{
		wait 0.1
		entity player = GetLocalViewPlayer()
		if ( !IsValid( player ) || !IsAlive( player ) )
			continue
		entity weapon = player.GetActiveWeapon()
		if ( !IsValid( weapon ) )
			continue
		string wepName = weapon.GetWeaponClassName()
		if ( wepName != ACCURACY.currentWeapon )
		{
			ACCURACY.currentWeapon = wepName
			// Load this weapon's session stats
			ACCURACY.totalShots  = wepName in file.sessionShots    ? file.sessionShots[wepName]    : 0
			ACCURACY.totalHits   = wepName in file.sessionHits     ? file.sessionHits[wepName]     : 0
			ACCURACY.combo       = wepName in file.sessionCombo    ? file.sessionCombo[wepName]    : 0
			ACCURACY.comboMax    = wepName in file.sessionComboMax ? file.sessionComboMax[wepName] : 0
			ACCURACY.totalShotsIgnored = 0
			recalculateAccuracy()
			updateAccuracyRUI()
		}
	}
}

vector function LerpColor( vector a, vector b, float t )
{
	t = clamp( t, 0.0, 1.0 )
	return Vector(
		a.x + ( b.x - a.x ) * t,
		a.y + ( b.y - a.y ) * t,
		a.z + ( b.z - a.z ) * t
	)
}

vector function AccuracyColor( float acc )
{
	float t = clamp( acc / 100.0, 0.0, 1.0 )
	return LerpColor( COLORS.RED, COLORS.GREEN, t )
}

string function GetWeaponDisplay( string wep )
{
	table<string, string> names = {
		mp_weapon_alternator_smg = "Alternator",
		mp_weapon_arc_launcher   = "Arc Launcher",
		mp_weapon_autopistol     = "RE-45",
		mp_weapon_car            = "CAR SMG",
		mp_weapon_chargerifle    = "Charge Rifle",
		mp_weapon_defender       = "Thunderbolt",
		mp_weapon_dmr            = "DMR",
		mp_weapon_doubletake     = "Double Take",
		mp_weapon_epg            = "EPG-1",
		mp_weapon_g2             = "G2A5",
		mp_weapon_hemlok         = "Hemlok",
		mp_weapon_hemlok_bf_r    = "Devotion",
		mp_weapon_hemlok_smg     = "Volt",
		mp_weapon_lmg            = "Spitfire",
		mp_weapon_lstar          = "L-STAR",
		mp_weapon_mastiff        = "Mastiff",
		mp_weapon_mgl            = "MGL",
		mp_weapon_pulse_lmg      = "Cold War",
		mp_weapon_r97            = "R-97",
		mp_weapon_rocket_launcher= "Rocket Launcher",
		mp_weapon_rspn101        = "R-201",
		mp_weapon_rspn101_og     = "R-101",
		mp_weapon_semipistol     = "P2016",
		mp_weapon_shotgun        = "EVA-8",
		mp_weapon_shotgun_pistol = "Mozambique",
		mp_weapon_smr            = "SMR",
		mp_weapon_sniper         = "Kraber",
		mp_weapon_softball       = "Softball",
		mp_weapon_vinson         = "Flatline",
		mp_weapon_wingman        = "Wingman",
		mp_weapon_wingman_n      = "Wingman Elite"
	}

	if ( wep in names )
		return names[wep]
	if ( wep == "" )
		return "None"
	if ( wep.len() > 10 && wep.slice( 0, 10 ) == "mp_weapon_" )
		return wep.slice( 10 ).toupper()
	return wep.toupper()
}

void function updateAccuracyRUI()
{
	if ( file.ruiElements[ eRuiParts.header ][0].element == null )
		return

	string wepDisplay = GetWeaponDisplay( ACCURACY.currentWeapon )
	RuiSetString( file.ruiElements[ eRuiParts.header ][0].element, "msgText", "[ ACC ]  " + wepDisplay )

	float acc = ACCURACY.accuracy
	RuiSetFloat3( file.ruiElements[ eRuiParts.session ][0].element, "msgColor", AccuracyColor( acc ) )

	bool showShots = GetConVarInt( "cv_acc_show_shots" ) == 1
	bool showHits  = GetConVarInt( "cv_acc_show_hits" ) == 1

	string sessionText = format( "%.1f%%", acc )
	if ( showShots )
		sessionText += format( "  |  %i shots", ACCURACY.totalShots )
	if ( showHits )
		sessionText += format( "  %i hits", ACCURACY.totalHits )
	sessionText += format( "  |  x%i combo  ( pb %i )", ACCURACY.combo, ACCURACY.comboMax )

	RuiSetString( file.ruiElements[ eRuiParts.session ][0].element, "msgText", sessionText )

	string wep = ACCURACY.currentWeapon
	int ltHits  = wep in file.lifetimeHits  ? file.lifetimeHits[wep]  : 0
	int ltShots = wep in file.lifetimeShots ? file.lifetimeShots[wep] : 0
	float ltAcc = ltShots > 0 ? ( ltHits.tofloat() / ltShots.tofloat() ) * 100.0 : 0.0

	RuiSetFloat3( file.ruiElements[ eRuiParts.lifetime ][0].element, "msgColor", AccuracyColor( ltAcc ) )

	string ltText = format( "all time  %.1f%%", ltAcc )
	if ( showShots )
		ltText += format( "  |  %i shots", ltShots )
	if ( showHits )
		ltText += format( "  %i hits", ltHits )

	RuiSetString( file.ruiElements[ eRuiParts.lifetime ][0].element, "msgText", ltText )
}

void function RegisterShot( string wepName )
{
	if ( !( wepName in file.sessionShots ) )   file.sessionShots[wepName] <- 0
	if ( !( wepName in file.sessionHits ) )    file.sessionHits[wepName] <- 0
	if ( !( wepName in file.sessionCombo ) )   file.sessionCombo[wepName] <- 0
	if ( !( wepName in file.sessionComboMax ) ) file.sessionComboMax[wepName] <- 0
	file.sessionShots[wepName]++

	if ( !( wepName in file.lifetimeShots ) )
		file.lifetimeShots[wepName] <- 0
	file.lifetimeShots[wepName]++

	ACCURACY.totalShots = file.sessionShots[wepName]
	ACCURACY.totalHits  = file.sessionHits[wepName]
	ACCURACY.combo      = file.sessionCombo[wepName]
	ACCURACY.comboMax   = file.sessionComboMax[wepName]

	recalculateAccuracy()
	SaveLifetimeStats()
	updateAccuracyRUI()
}

void function RegisterHit( string wepName )
{
	if ( !( wepName in file.sessionShots ) )    file.sessionShots[wepName] <- 0
	if ( !( wepName in file.sessionHits ) )     file.sessionHits[wepName] <- 0
	if ( !( wepName in file.sessionCombo ) )    file.sessionCombo[wepName] <- 0
	if ( !( wepName in file.sessionComboMax ) ) file.sessionComboMax[wepName] <- 0

	file.sessionHits[wepName]++
	file.sessionCombo[wepName]++
	if ( file.sessionCombo[wepName] > file.sessionComboMax[wepName] )
		file.sessionComboMax[wepName] = file.sessionCombo[wepName]

	if ( !( wepName in file.lifetimeHits ) )
		file.lifetimeHits[wepName] <- 0
	file.lifetimeHits[wepName]++

	ACCURACY.totalShots = file.sessionShots[wepName]
	ACCURACY.totalHits  = file.sessionHits[wepName]
	ACCURACY.combo      = file.sessionCombo[wepName]
	ACCURACY.comboMax   = file.sessionComboMax[wepName]

	recalculateAccuracy()
	SaveLifetimeStats()
	updateAccuracyRUI()
}

void function RegisterMissImpact( string wepName )
{
	if ( !( wepName in file.sessionCombo ) ) file.sessionCombo[wepName] <- 0
	file.sessionCombo[wepName] = 0
	ACCURACY.combo = 0
	recalculateAccuracy()
	updateAccuracyRUI()
}

var function Accuracy_OnWeaponPrimaryAttack( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity owner = weapon.GetWeaponOwner()
	if ( IsValid( owner ) && owner == GetLocalViewPlayer() )
	{
		string wepName = weapon.GetWeaponClassName()
		if ( ACCURACY.currentWeapon == "" )
			ACCURACY.currentWeapon = wepName
		RegisterShot( wepName )
	}
	return weapon.GetAmmoPerShot()
}

void function Accuracy_OnWeaponBulletHit( entity weapon, WeaponBulletHitParams hitParams )
{
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
}

void function Accuracy_OnProjectileCollision( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	// hits handled by AddLocalPlayerDidDamageCallback
}

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

	RegisterHit( wepName )
}

void function recalculateAccuracy()
{
	float totalHits = ACCURACY.totalHits.tofloat()
	float totalShots = ACCURACY.totalShots.tofloat()
	ACCURACY.accuracy = totalShots > 0.0 ? ( totalHits / totalShots ) * 100.0 : 0.0
}
