global function AccuracySettings_Init

void function AccuracySettings_Init()
{
	ModSettings_AddModTitle( dtool_rainbowModText( "cool(er) accuracy tracker" ) )

	ModSettings_AddModCategory( "> Position, Size" )
	ModSettings_AddSliderSetting( "cv_acc_posX",     "Horizontal position", 0.0,  1.0,  0.01 )
	ModSettings_AddSliderSetting( "cv_acc_posY",     "Vertical position",   0.0,  1.0,  0.01 )
	ModSettings_AddSliderSetting( "cv_acc_fontSize", "Font size",           8.0,  30.0, 0.5  )

	ModSettings_AddModCategory( "> Visibility" )
	ModSettings_AddSetting( "cv_acc_show_always",   "Always visible",     "bool" )
	ModSettings_AddSetting( "cv_acc_show_shots",    "Show shots",         "bool" )
	ModSettings_AddSetting( "cv_acc_show_hits",     "Show hits",          "bool" )
	ModSettings_AddSetting( "cv_acc_show_lifetime", "Show lifetime stats","bool" )
}
