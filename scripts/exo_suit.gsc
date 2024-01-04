/*
	Scuffed Exo Movment ported from AW
	By BradsTV
	Version: v1.0.0
*/

init()
{
    setDvars(); 
    loadCustomFX();
    level thread onPlayerConnect();
}

setDvars()
{
    setdvar("jump_slowdownEnable", 0);
    setdvar("jump_height", 39);
    setdvar("jump_enableFallDamage", 0);
}

loadCustomFX()
{
    level._effect["exo_slam_boots_impact"] = loadfx("vfx/code/exo_slam_boots_impact");  
    level._effect["exo_slam_impact"] = loadfx("vfx/code/exo_slam_impact");  
    level._effect["high_jump_exo_land_medium"] = loadfx("vfx/code/high_jump_exo_land_medium");  
    level._effect["high_jump_ground"] = loadfx("vfx/code/high_jump_ground"); 
    level._effect["high_jump_view_air"] = loadfx("vfx/code/high_jump_view_air"); 
}

onPlayerConnect()
{
    for(;;)
    {
        level waittill("connected", player);
        player thread onPlayerSpawned();
    }
}

onPlayerSpawned()
{
    self endon("disconnect");

    self thread onPlayerSpawnedOnce();
    for(;;) //on each player spawn
    {
        self waittill("spawned_player");
        self enable_exo_suit();
    } 
}

onPlayerSpawnedOnce()
{
    self endon("disconnect");

    self waittill("spawned_player");
    //self freezecontrols(0);
    self thread monitor_stance_button();
}

enable_exo_suit()
{
    if ( !isdefined( self.boost ) )
        self.boost = [];

    self.boost["in_dash"] = 0;
    self.boost["in_jump"] = 0;
    self.boost["in_slam"] = 0;
    self.boost["dash_count"] = 0;

    self thread track_player_movement();
    self thread track_player_velocity();
    self thread exo_dash();
    self thread exo_jump();
    self thread exo_slam();
}

disable_exo_suit()
{
    self notify("disable_exo");
    self.boost = undefined;
}

track_player_movement()
{
    self endon("disconnect");
    self endon("death");
    self endon("disable_exo");

    if(!isdefined( self.boost["stick_input"]) || !isdefined(self.boost["stick_normalized"]))
    {
        self.boost["stick_input"] = (0, 0, 0);
        self.boost["stick_normalized"] = (0, 0, 0);
    }
        
    for(;;)
    {
        normalized = self getnormalizedmovement();
        normalized = (normalized[0], normalized[1] * -1, 0);
        combined_angles = common_scripts\utility::flat_angle(combineangles(self.angles, vectortoangles(normalized)));
        stick_input = anglestoforward(combined_angles) * length(normalized);
        self.boost["stick_input"] = stick_input;
        self.boost["stick_normalized"] = normalized;
        wait 0.05;
    }
}

track_player_velocity()
{
    self endon("disconnect");
    self endon("death");
    self endon("disable_exo");

    if(!isdefined( self.boost["player_vel"]))
        self.boost["player_vel"] = (0, 0, 0);

    for(;;)
    {
        self.boost["player_vel"] = self getvelocity();
        wait 0.05;
    }
}

exo_dash()
{
    self endon("disconnect");
    self endon("death");
    self endon("disable_exo");

    for(;;)
    {
        waittill_dash_button_pressed();
        if(!self adsbuttonpressed() && self getstance() != "prone" && self ismovingstick() && !self.boost["in_slam"])
        {
            if(self.boost["stick_normalized"][0] < 0.6)
                self boost_dash();
            else if(!self isonground())
                self boost_dash();
        }
        waittill_dash_button_released();
    }
}

exo_jump()
{
    self endon("disconnect");
    self endon("death");
    self endon("disable_exo");

    for(;;)
    {
        waittill_not_on_ground();
        waittill_jump_button_released();
    
        if(!waittill_jump_button_pressed_or_onground())
            continue;

        if (!self isonground() && !self.boost["in_slam"])
            self boost_jump();

        waittill_jump_button_released();
    }
}

exo_slam()
{
    self endon("disconnect");
    self endon("death");
    self endon("disable_exo");

    for(;;)
    {
        waittill_not_on_ground();
        waittill_stance_button_released();
    
        if(!waittill_stance_button_pressed_or_onground())
            continue;

        if (!self isonground())
            self boost_slam();

        waittill_stance_button_released();
    }
}

boost_dash()
{
    self endon("disconnect");
    self endon("death");
    self endon("disable_exo");

    if(self.boost["in_slam"])
        return;

    if(self.boost["dash_count"] >= 2)
    {
        self playsound("mp_exo_bat_empty");
        return;
    }
        
    self notify("new_dash");
    self thread dash_cooldown();
    self.boost["in_dash"] = 1;
    
    self thread boost_dash_fx();

    multiplier = 250;
    z_offset = (0, 0, 200);
    x_y_multiplier = 400;
    stick_input = self.boost["stick_input"];
    half_velo = self.boost["player_vel"] * 0.5;

    modified_velo = half_velo + stick_input * multiplier + z_offset;
    velo_normalized = vectornormalize(modified_velo) * x_y_multiplier;
    final_velo = (velo_normalized[0], velo_normalized[1], modified_velo[2]);

    if (stick_input[2] == 0)
        final_velo = (final_velo[0], final_velo[1], final_velo[2] * 0.7);

    self setvelocity(final_velo);
    wait 0.2; //cooldown between dashes
    self.boost["in_dash"] = 0;
}

boost_dash_fx()
{
    earthquake( 0.2, 1, self.origin, 150 );
    self playlocalsound("pc_boost_dodge");
    self playrumbleonentity( "damage_heavy" );
}

dash_cooldown()
{
    self endon("disconnect");
    self endon("death");
    self endon("disable_exo");
    self endon("new_dash");

    self.boost["dash_count"]++;
    wait 2.5;
    self.boost["dash_count"] = 0;
}

boost_jump()
{
    self endon("disconnect");
    self endon("death");
    self endon("disable_exo");

    if(self.boost["in_slam"])
        return;

    self.boost["in_jump"] = 1;

    self thread boost_jump_fx();

    for(i = 0; i < 4; i++)
    {
        velo = self getvelocity();
        z = velo[2];

        if(i == 0)
            z = 0;

        z = z + 150;
        self setvelocity( (velo[0], velo[1], z) );
        wait 0.05;
    }

    waittill_on_ground();
    self thread boost_land_fx();
    wait 0.2; //cooldown after touching ground
    self.boost["in_jump"] = 0;
}

boost_jump_fx()
{
    earthquake( 0.2, 1, self.origin, 150 );

    ground = bullettrace(self.origin, self.origin - (0, 0, 5000), false, self)["position"];
    if(distance(self.origin, ground) < 120)
        playfx(common_scripts\utility::getfx("high_jump_ground"), ground);
    
    playfxontag(common_scripts\utility::getfx("high_jump_view_air"), self, "j_hip_ri");
    self playsound("pc_boost_jump");
    self playrumbleonentity("damage_heavy");
}

boost_land_fx()
{
    playfx(common_scripts\utility::getfx("high_jump_exo_land_medium"), self.origin);
    self playsound("pc_boost_land");
    self playrumbleonentity("damage_heavy");
}

boost_slam()
{
    self endon("disconnect");
    self endon("death");
    self endon("disable_exo");

    if(self getdistancetoground() < 120)
    {
        self playlocalsound("mp_exo_bat_empty");
        return;
    }

    self.boost["in_slam"] = 1;

    self common_scripts\utility::_disableweapon();
    self common_scripts\utility::_disableoffhandweapons();
    self setstance("stand");

    x = (1, 0, 0);
    flat_angle = common_scripts\utility::flat_angle(combineangles(self.angles, vectortoangles(x)));
    forward = anglestoforward(flat_angle) * length(x);

    while(!self isonground())
    {
        velo = self.boost["player_vel"];
        x_y = velo * 0.5 + forward * 150;
        z = velo[2] - 150; 
        final_velo = (x_y[0], x_y[1], z);
        self setvelocity(final_velo);
        wait 0.05;
    }

    
    self common_scripts\utility::_enableweapon();
    self common_scripts\utility::_enableoffhandweapons();
    self thread boost_slam_fx();
    self slam_radius_damage();
    
    self.boost["in_slam"] = 0;
}

boost_slam_fx()
{
    earthquake(0.3, 1, self.origin, 150);
    playfx(common_scripts\utility::getfx("exo_slam_impact"), self.origin);
    self setclientomnvar("ui_hud_shake", 1);
    self playsound("pc_boost_land");
    self playrumbleonentity("damage_heavy");
}

slam_radius_damage()
{
    //Values and offsets taken from s1 dump
    var_7 = 120;
    var_8 = 380;
    var_9 = 50;
    var_10 = 110;
    var_11 = 75;
    var_12 = 125;

    var_13 = 0.5;
    var_14 = (var_12 - var_11) * var_13 + var_11;
    var_15 = var_14 + 60;
    var_16 = var_15 * var_15;
    self radiusdamage(self.origin, var_14, var_10, var_9, self, "MOD_TRIGGER_HURT", "boost_slam_mp");
    physicsexplosionsphere(self.origin, var_14, 20, 0.9);
}

waittill_not_on_ground()
{
    self endon("disconnect");
    self endon("death");

    while(self isonground())
        wait 0.05;
    
    return 1;
}

waittill_on_ground()
{
    self endon("disconnect");
    self endon("death");

    while(!self isonground())
        wait 0.05;
    
    return 1;
}

waittill_dash_button_pressed()
{
    self endon("disconnect");
    self endon("death");
    self endon("disable_exo");

    while(!self sprintbuttonpressed())
        wait 0.05;

    return 1;
}

waittill_dash_button_released()
{
    self endon("disconnect");
    self endon("death");

    while(self sprintbuttonpressed())
        wait 0.05;

    return 1;
}

waittill_jump_button_pressed()
{
    self endon("disconnect");
    self endon("death");

    while(!self jumpbuttonpressed())
        wait 0.05;
        
    return 1;
}

waittill_jump_button_pressed_or_onground()
{
    self endon("disconnect");
    self endon("death");

    while(!self jumpbuttonpressed() && !self isonground())
        wait 0.05;
        
    if(self isonground())
        return 0;

    return 1;
}

waittill_jump_button_released()
{
    self endon("disconnect");
    self endon("death");

    while(self jumpbuttonpressed())
        wait 0.05;

    return 1;
}

waittill_stance_button_pressed()
{
    self endon("disconnect");
    self endon("death");

    while(!self stancebuttonpressed())
        wait 0.05;

    return 1;
}

waittill_stance_button_pressed_or_onground()
{
    self endon("disconnect");
    self endon("death");

    while(!self stancebuttonpressed() && !self isonground())
        wait 0.05;
        
    if(self isonground())
        return 0;

    return 1;
}

waittill_stance_button_released()
{
    self endon("disconnect");
    self endon("death");

    while(self stancebuttonpressed())
        wait 0.05;

    return 1;
}

monitor_stance_button()
{
    self endon("disconnect");

    self notifyonplayercommand("stance_down", "+stance");
    self notifyonplayercommand("stance_up", "-stance");
    self.stance_state = 0;

    for(;;)
    {
        notify_msg = self common_scripts\utility::waittill_any_return("stance_down", "stance_up");
        if(notify_msg == "stance_down")
        {
            self.stance_state = 1;
        }

        if(notify_msg == "stance_up")
        {
            self.stance_state = 0;
        }
    }
}

stancebuttonpressed()
{
    return self.stance_state;
}

getdistancetoground()
{
    return distance(self.origin, bullettrace(self.origin, self.origin - (0, 0, 5000), false, self)["position"]);
}

ismovingstick()
{
    stick = self.boost["stick_normalized"];
    if(stick[0] != 0 || stick[1] != 0 || stick[2] != 0)
        return true;

    return false;
}