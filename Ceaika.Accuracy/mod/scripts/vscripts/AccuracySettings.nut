global function AccuracySettings_Init

void function AccuracySettings_Init()
{
	ModSettings_AddModTitle( "cool accuracy tracker" )

	ModSettings_AddModCategory( "Position & Size" )
	ModSettings_AddSliderSetting( "acc_pos_x",     "Horizontal position", 0.0,  1.0,  0.01 )
	ModSettings_AddSliderSetting( "acc_pos_y",     "Vertical position",   0.0,  1.0,  0.01 )
	ModSettings_AddSliderSetting( "acc_font_size", "Font size",           8.0,  30.0, 0.5  )

	ModSettings_AddModCategory( "Visibility" )
	ModSettings_AddSetting( "acc_always_show",   "Always visible",     "bool" )
	ModSettings_AddSetting( "acc_show_shots",    "Show shots",         "bool" )
	ModSettings_AddSetting( "acc_show_hits",     "Show hits",          "bool" )
	ModSettings_AddSetting( "acc_show_lifetime", "Show lifetime stats","bool" )
}
