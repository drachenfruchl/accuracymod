untyped

global function Accuracy_Init
global function Accuracy_OnWeaponPrimaryAttack
global function Accuracy_OnWeaponBulletHit
global function Accuracy_OnProjectileCollision

struct {
	int totalHits = 0
	int totalShots = 0
	int totalShotsIgnored = 0
	float accuracy = 0.0
	int combo = 0
	int comboMax = 0

	string currentWeapon = ""
	var ruiHeader = null
	var ruiSession = null
	var ruiLifetime = null
} ACCURACY

table<string, int> lifetimeHits
table<string, int> lifetimeShots
table<string, int> sessionHits
table<string, int> sessionShots
table<string, int> sessionCombo
table<string, int> sessionComboMax
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

const float  ALPHA        = 0.95

const vector COL_WHITE  = Vector( 0.88, 0.88, 0.88 )
const vector COL_GREY   = Vector( 0.45, 0.45, 0.45 )
const vector COL_GOLD   = Vector( 1.0,  0.82, 0.25 )
const vector COL_GREEN  = Vector( 0.3,  0.95, 0.45 )
const vector COL_YELLOW = Vector( 1.0,  0.82, 0.15 )
const vector COL_RED    = Vector( 1.0,  0.28, 0.28 )

void function Accuracy_Init()
{
	LoadLifetimeStats()
	thread createAccuracyRUI()
	thread WatchWeaponSwitch()
	AddLocalPlayerDidDamageCallback( Accuracy_OnDamage )
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
					lifetimeHits[k] = int( v )
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
					lifetimeShots[k] = int( v )
			}
			updateAccuracyRUI()
		}
	)
}

void function SaveLifetimeStats()
{
	NSSaveJSONFile( "hits.json", lifetimeHits )
	NSSaveJSONFile( "shots.json", lifetimeShots )
}

var function MakeRUI( vector pos, float fontSize, vector color, float thicken = 0.0 )
{
	var rui = RuiCreate( $"ui/cockpit_console_text_top_left.rpak", clGlobal.topoCockpitHudPermanent, RUI_DRAW_COCKPIT, 0 )
	RuiSetInt( rui, "maxLines", 1 )
	RuiSetInt( rui, "lineNum", 1 )
	RuiSetFloat2( rui, "msgPos", pos )
	RuiSetFloat( rui, "msgFontSize", fontSize )
	RuiSetFloat( rui, "msgAlpha", 0.0 )
	RuiSetFloat3( rui, "msgColor", color )
	RuiSetFloat( rui, "thicken", thicken )
	RuiSetString( rui, "msgText", "" )
	return rui
}

void function createAccuracyRUI()
{
	while ( !IsValid( clGlobal.topoCockpitHudPermanent ) )
		WaitFrame()

	ACCURACY.ruiHeader   = MakeRUI( Vector( 0.0, 0.0, 0.0 ), 16.0, COL_GOLD,  0.15 )
	ACCURACY.ruiSession  = MakeRUI( Vector( 0.0, 0.0, 0.0 ), 16.0, COL_WHITE, 0.0  )
	ACCURACY.ruiLifetime = MakeRUI( Vector( 0.0, 0.0, 0.0 ), 14.0, COL_GREY,  0.0  )

	updateAccuracyRUI()
	thread WatchScoreboard()
	thread WatchSettings()
}

void function WatchSettings()
{
	float lastX     = -1.0
	float lastY     = -1.0
	float lastSize  = -1.0

	while ( true )
	{
		wait 0.2

		float x    = GetConVarFloat( "acc_pos_x" )
		float y    = GetConVarFloat( "acc_pos_y" )
		float size = GetConVarFloat( "acc_font_size" )

		if ( x == lastX && y == lastY && size == lastSize )
			continue

		lastX    = x
		lastY    = y
		lastSize = size

		float lineGap = size * 0.0013
		RuiSetFloat2( ACCURACY.ruiHeader,   "msgPos", Vector( x, y,              0.0 ) )
		RuiSetFloat2( ACCURACY.ruiSession,  "msgPos", Vector( x, y + lineGap,    0.0 ) )
		RuiSetFloat2( ACCURACY.ruiLifetime, "msgPos", Vector( x, y + lineGap*2,  0.0 ) )

		RuiSetFloat( ACCURACY.ruiHeader,   "msgFontSize", size + 1.5 )
		RuiSetFloat( ACCURACY.ruiSession,  "msgFontSize", size )
		RuiSetFloat( ACCURACY.ruiLifetime, "msgFontSize", size - 1.5 )

		updateAccuracyRUI()
	}
}

void function WatchScoreboard()
{
	while ( true )
	{
		WaitFrame()
		bool alwaysShow = GetConVarInt( "acc_always_show" ) == 1
		float targetAlpha = ( alwaysShow || clGlobal.showingScoreboard ) ? ALPHA : 0.0
		RuiSetFloat( ACCURACY.ruiHeader,   "msgAlpha", targetAlpha )
		RuiSetFloat( ACCURACY.ruiSession,  "msgAlpha", targetAlpha )
		float ltAlpha = GetConVarInt( "acc_show_lifetime" ) == 1 ? targetAlpha : 0.0
		RuiSetFloat( ACCURACY.ruiLifetime, "msgAlpha", ltAlpha )
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
			ACCURACY.totalShots  = wepName in sessionShots    ? sessionShots[wepName]    : 0
			ACCURACY.totalHits   = wepName in sessionHits     ? sessionHits[wepName]     : 0
			ACCURACY.combo       = wepName in sessionCombo    ? sessionCombo[wepName]    : 0
			ACCURACY.comboMax    = wepName in sessionComboMax ? sessionComboMax[wepName] : 0
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
	return LerpColor( COL_RED, COL_GREEN, t )
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
	if ( ACCURACY.ruiHeader == null )
		return

	string wepDisplay = GetWeaponDisplay( ACCURACY.currentWeapon )
	RuiSetString( ACCURACY.ruiHeader, "msgText", "[ ACC ]  " + wepDisplay )

	float acc = ACCURACY.accuracy
	RuiSetFloat3( ACCURACY.ruiSession, "msgColor", AccuracyColor( acc ) )

	bool showShots = GetConVarInt( "acc_show_shots" ) == 1
	bool showHits  = GetConVarInt( "acc_show_hits" ) == 1

	string sessionText = format( "%.1f%%", acc )
	if ( showShots )
		sessionText += format( "  |  %i shots", ACCURACY.totalShots )
	if ( showHits )
		sessionText += format( "  %i hits", ACCURACY.totalHits )
	sessionText += format( "  |  x%i combo  ( pb %i )", ACCURACY.combo, ACCURACY.comboMax )

	RuiSetString( ACCURACY.ruiSession, "msgText", sessionText )

	string wep = ACCURACY.currentWeapon
	int ltHits  = wep in lifetimeHits  ? lifetimeHits[wep]  : 0
	int ltShots = wep in lifetimeShots ? lifetimeShots[wep] : 0
	float ltAcc = ltShots > 0 ? ( ltHits.tofloat() / ltShots.tofloat() ) * 100.0 : 0.0

	RuiSetFloat3( ACCURACY.ruiLifetime, "msgColor", AccuracyColor( ltAcc ) )

	string ltText = format( "all time  %.1f%%", ltAcc )
	if ( showShots )
		ltText += format( "  |  %i shots", ltShots )
	if ( showHits )
		ltText += format( "  %i hits", ltHits )

	RuiSetString( ACCURACY.ruiLifetime, "msgText", ltText )
}

void function RegisterShot( string wepName )
{
	if ( !( wepName in sessionShots ) )   sessionShots[wepName] <- 0
	if ( !( wepName in sessionHits ) )    sessionHits[wepName] <- 0
	if ( !( wepName in sessionCombo ) )   sessionCombo[wepName] <- 0
	if ( !( wepName in sessionComboMax ) ) sessionComboMax[wepName] <- 0
	sessionShots[wepName]++

	if ( !( wepName in lifetimeShots ) )
		lifetimeShots[wepName] <- 0
	lifetimeShots[wepName]++

	ACCURACY.totalShots = sessionShots[wepName]
	ACCURACY.totalHits  = sessionHits[wepName]
	ACCURACY.combo      = sessionCombo[wepName]
	ACCURACY.comboMax   = sessionComboMax[wepName]

	recalculateAccuracy()
	SaveLifetimeStats()
	updateAccuracyRUI()
}

void function RegisterHit( string wepName )
{
	if ( !( wepName in sessionShots ) )    sessionShots[wepName] <- 0
	if ( !( wepName in sessionHits ) )     sessionHits[wepName] <- 0
	if ( !( wepName in sessionCombo ) )    sessionCombo[wepName] <- 0
	if ( !( wepName in sessionComboMax ) ) sessionComboMax[wepName] <- 0

	sessionHits[wepName]++
	sessionCombo[wepName]++
	if ( sessionCombo[wepName] > sessionComboMax[wepName] )
		sessionComboMax[wepName] = sessionCombo[wepName]

	if ( !( wepName in lifetimeHits ) )
		lifetimeHits[wepName] <- 0
	lifetimeHits[wepName]++

	ACCURACY.totalShots = sessionShots[wepName]
	ACCURACY.totalHits  = sessionHits[wepName]
	ACCURACY.combo      = sessionCombo[wepName]
	ACCURACY.comboMax   = sessionComboMax[wepName]

	recalculateAccuracy()
	SaveLifetimeStats()
	updateAccuracyRUI()
}

void function RegisterMissImpact( string wepName )
{
	if ( !( wepName in sessionCombo ) ) sessionCombo[wepName] <- 0
	sessionCombo[wepName] = 0
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
