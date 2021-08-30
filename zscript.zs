version "4.6.0"

Class EDW_Weapon : Weapon abstract
{
	class<Ammo> MagAmmotype1, MagAmmotype2; //magazine ammo (if used)
	property MagAmmotype1 : MagAmmotype1;
	property MagAmmotype2 : MagAmmotype2;
	
	protected Ammo primaryAmmo, secondaryAmmo;	//points either to ammo1/ammo2 or to magammo1/magammo2
	
	//protected bool isReloadable;
	
	//Pointers to states:
	protected state s_ready;
	protected state s_readyRight;
	protected state s_readyLeft;
	protected state s_fireRight;
	protected state s_fireLeft;
	protected state s_holdRight;
	protected state s_holdLeft;
	protected state s_flashRight;
	protected state s_flashLeft;
	protected state s_reloadRight;	
	protected state s_reloadLeft;
	
	Default
	{
		EDW_Weapon.MagAmmotype1			"";		
		EDW_Weapon.MagAmmotype2 			"";
	}
	
	// Aliases for gun overlays
	enum FireLayers
	{
		PSP_RIGHTGUN = 5,
		PSP_LEFTGUN = 6,
		PSP_RIGHTFLASH = 100,
		PSP_LEFTFLASH = 101
	}
	
	enum SoundChannels
	{
		CHAN_RIGHTGUN	= 12,
		CHAN_LEFTGUN = 13
	}
	
	// Set pointers to states here:
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		s_ready = FindState("Ready");
		s_readyRight = FindState("Ready.Right");
		s_readyLeft = FindState("Ready.Left");
		s_fireRight = FindState("Fire.Right");
		s_fireLeft = FindState("Fire.Left");
		s_holdRight = FindState("Hold.Right");
		s_holdLeft = FindState("Hold.Left");
		s_flashRight = FindState("Flash.Right");
		s_flashLeft = FindState("Flash.Left");
		if (MagAmmotype1)
			s_ReloadRight = FindState("Reload.Right");
		if (MagAmmotype2)
			s_ReloadLeft = FindState("Reload.Left");
	}
	
	action bool CheckInfiniteAmmo()
	{
		return (sv_infiniteammo || FindInventory("PowerInfiniteAmmo",true) );
	}
	
	/*	This is meant to be called instead of A_WeaponReady() in the main
		Ready state sequence (NOT in the left/right ready sequences).
		This doesn't actually make the weapon ready for firing directly, but 
		rather	makes sure everything is set up correctly and creates overlays
		if they haven't been created yet.		
	*/
	action void DualWeaponReady()
	{
		// Don't let the weapon function if you're missing require state sequences:
		if (!invoker.Ammotype1 || !invoker.Ammotype2 || !invoker.s_readyRight || !invoker.s_readyLeft || !invoker.s_fireRight || !invoker.s_fireLeft || (invoker.MagAmmotype1 && !invoker.s_reloadRight) || (invoker.MagAmmotype2 && !invoker.s_reloadLeft))
		{
			console.printf("Can't function: some of the primary state labels in this weapon are missing.");
			A_WeaponReady(WRF_NOFIRE);
			return;
		}
		// Get a pointer to primary ammo (which is either ammotype1 or MagAmmotype1):
		if (!invoker.primaryAmmo && invoker.AmmoType1)
			invoker.primaryAmmo = invoker.MagAmmotype1 ? Ammo(FindInventory(invoker.MagAmmotype1)) : Ammo(FindInventory(invoker.Ammotype1));
		// Same for secondary:
		if (!invoker.secondaryAmmo && invoker.AmmoType2)
			invoker.secondaryAmmo = invoker.MagAmmotype2 ?Ammo(FindInventory(invoker.MagAmmotype2)) : Ammo(FindInventory(invoker.Ammotype2));
		// Create gun overlays (once) if they're not drawn for some reason:
		A_overlay(PSP_RIGHTGUN, "Ready.Right", nooverride:true);
		A_Overlay(PSP_LEFTGUN, "Ready.Left", nooverride:true);		
		A_WeaponReady(WRF_NOFIRE); //let the gun bob and be deselected
	}
	
	/*action bool Sign(double num)
	{
		return num >= 0 ? 1 : -1;
	}*/
	
	/*	Returns true if you have enough ammo.
		The argument specifies whether to check for primary or secondary ammo.
	*/
	action bool EDW_CheckAmmo(bool secondary = false)
	{
		let ammo2check = secondary ? invoker.secondaryAmmo : invoker.primaryAmmo;
		// Return true if the weapon doesn't define ammo (= doesn't need it)
		if (!ammo2check)
			return true;
		// Otherwise get the required amount
		int reqAmt = secondary ? invoker.ammouse2 : invoker.ammouse1;
		// Return true if infinite ammo is active or we have enough
		return CheckInfiniteAmmo() || ammo2check.amount >= reqAmt;
	}
	
	/*	The actual raising is done via the regular A_Raise in the regular Select
		state sequence. All this function does is, it checks if the main layer
		is already in the Ready state, and if so, moves the calling layer from
		Select.Right/Select.Left to Ready.Right/Ready.Left.
	*/
	action void Right_Raise(bool left = false)
	{
		if (!player)
			return;
		let psp = player.FindPSprite(PSP_WEAPON);
		if (!psp)
			return;
		let targetState = left ? invoker.s_readyLeft : invoker.s_readyRight;
		if (InStateSequence(psp.curstate,invoker.s_ready))
		{
			player.SetPsprite(OverlayID(),targetState);
		}
	}
	//Left-gun alias function:
	action void Left_Raise()
	{
		Right_Raise(true);
	}
	
	/* 	Ready function for the right weapon.
		Will jump into the right Fire sequence or right Reload sequence
		based on buttons pressed and ammo available.
	*/
	action void Right_WeaponReady()
	{
		if (!player)
			return;
		A_OverlayFlags(OverlayID(),PSPF_ADDBOB,true);
		state targetState = null;
		bool pressingFire = player.cmd.buttons & BT_ATTACK;		
		if (pressingFire)
		{
			if (EDW_CheckAmmo(secondary:false))
			{
				targetState = invoker.s_fireRight;
			}
			else if (invoker.MagAmmotype1 && invoker.ammo1.amount > 0)
			{
				targetState = invoker.s_reloadRight;
			}			
		}
		if (targetState) 
		{
			A_OverlayFlags(OverlayID(),PSPF_ADDBOB,false);
			player.SetPsprite(OverlayID(),targetState);
		}
		else 
		{
			A_OverlayFlags(OverlayID(),PSPF_ADDBOB,true);
		}
	}
	
	/* 	Ready function for the left weapon.
		Will jump into the left Fire sequence or left Reload sequence
		based on buttons pressed and ammo available.
	*/
	action void Left_WeaponReady()
	{
		if (!player)
			return;			
		A_OverlayFlags(OverlayID(),PSPF_ADDBOB,true);
		/*A_OverlayFlags(OverlayID(),PSPF_ADDBOB,false);
		let psp = player.FindPSprite(PSP_RIGHTGUN);
		if (psp)
		{
			//console.printf("x: %f | y: %f",psp.coord1.x,psp.coord1.y);
			double wx = (abs(psp.x) - 0.5) * -Sign(psp.x); //mirror X offset
			double wy = (abs(psp.y) - 0.5) * Sign(psp.y);
			//A_OverlayOffset(OverlayID(),wx, wy, WOF_INTERPOLATE);
		}*/
		state targetState = null;
		bool pressingFire = player.cmd.buttons & BT_ALTATTACK;		
		if (pressingFire)
		{
			if (EDW_CheckAmmo(secondary:true))
			{
				targetState = invoker.s_fireLeft;
			}
			else if (invoker.MagAmmotype2 && invoker.ammo2.amount > 0)
			{
				targetState = invoker.s_reloadLeft;
			}			
		}		
		if (targetState) 
		{
			A_OverlayFlags(OverlayID(),PSPF_ADDBOB,false);
			player.SetPsprite(OverlayID(),targetState);
		}
		else 
		{
			A_OverlayFlags(OverlayID(),PSPF_ADDBOB,true);
		}
	}
	
	/*	Right-gun analong of A_GunFlash. Does two things:
		- Draws Flash.Right/Flash.Left on PSP_RIGHTFLASH/PSP_LEFTFLASH layers
		- Makes sure the flash doesn't follow weapon bob and gets aligned
		with the gun layer the moment it's called (If you want to move the 
		flash around after that, you'll have to do it manually.)
	*/
	action void Right_GunFlash(bool left = false)
	{
		if (!player)
			return;
		let psp = Player.FindPSprite(OverlayID());
		if (!psp)
			return;
		int layer = left ? PSP_LEFTFLASH : PSP_RIGHTFLASH;
		state flashstate = left ? invoker.s_flashLeft : invoker.s_flashRight;
		if (!flashstate)
			return;
		Player.SetPsprite(layer,flashstate);
		A_OverlayFlags(layer,PSPF_ADDBOB,false);
		A_OverlayOffset(layer,psp.x,psp.y);
		
	}	
	//Left-gun alias function:
	action void Left_GunFlash()
	{
		Right_GunFlash(true);
	}
	
	/*	A_ReFire analog for the right gun.	
		Increases player.refire just like A_Refire(), and resets it to 0
		as long as neither gun is refiring.
	*/
	action void Right_ReFire(bool left = false)
	{
		//double-check player and psp:
		if (!player)
			return;
		let psp = Player.FindPSprite(OverlayID());
		if (!psp)
			return;
		let s_fire = left ? invoker.s_fireLeft : invoker.s_fireRight; //pointer to Fire
		let s_hold = left ? invoker.s_holdLeft : invoker.s_holdright; //pointer to Hold
		int atkbutton = left ? BT_ALTATTACK : BT_ATTACK; //check attack button is being held
		state targetState = null;
		//check if this is being called from Fire or Hold:
		if (s_fire && (InStateSequence(psp.curstate,s_fire) || InStateSequence(psp.curstate,s_hold)))
		{
			//Check if we have enough ammo and the attack button is being held:
			if (EDW_CheckAmmo(left) && player.cmd.buttons & atkbutton && player.oldbuttons & atkbutton)
			{
				//if so, jump to Hold (if it exists) or to Fire
				targetState = s_hold ? s_hold : s_fire;
			}
		}
		//If target state was set, increase player.refire and set the state:
		if (targetState) 
		{
			player.refire++;
			player.SetPsprite(OverlayID(),targetState);
		}
		//if we're not refiring...
		else
		{
			//find the state the OTHER gun is in:
			let psp_other = left ? Player.FindPSprite(PSP_RIGHTGUN) : Player.FindPSprite(PSP_LEFTGUN);
			let s_otherGunReady = left ? invoker.s_readyRight : invoker.s_readyLeft;
			//if the OTHER gun is in its Ready sequence, reset player.refire:
			if (psp_other && InStateSequence(psp_other.curstate,s_otherGunReady))
				player.refire = 0;
		}
	}
	action void Left_ReFire()
	{
		Right_ReFire(true);
	}
	
	// Attacks:
	/*	To make sure the correct ammo is consumed for each attack,
		we need to manually set invoker.bAltFire to false to consume
		primary ammo, and to true to consume secondary ammo.
		I made a bunch of simple wrappers for the generic attack
		functions.
		If you need to use a custom attack function, you'll have to set 
		bAltFire manually. A_SetFireMode below can be used	for that.
	*/
	
	// Call this before custom attack functions to define which gun is firing
	action void A_SetFireMode(bool secondary = false) 
	{
		invoker.bAltFire = secondary;
	}
	
	/*	These are very simple wrappers that set bAltFire to false for 
		right gun and true for left gun to make sure the correct ammo 
		is consumed.
	*/
	//A_FireBullets
	action void Right_FireBullets(double spread_xy, double spread_z, int numbullets, int damageperbullet, class<Actor> pufftype = "BulletPuff", int flags = 1, double range = 0, class<Actor> missile = null, double Spawnheight = 32, double Spawnofs_xy = 0)
	{
		invoker.bAltFire = false;
		A_FireBullets(spread_xy, spread_z, numbullets, damageperbullet, pufftype, flags, range ,missile, Spawnheight, Spawnofs_xy);
	}	
	action void Left_FireBullets(double spread_xy, double spread_z, int numbullets, int damageperbullet, class<Actor> pufftype = "BulletPuff", int flags = 1, double range = 0, class<Actor> missile = null, double Spawnheight = 32, double Spawnofs_xy = 0)
	{
		invoker.bAltFire = true;
		A_FireBullets(spread_xy, spread_z, numbullets, damageperbullet, pufftype, flags, range ,missile, Spawnheight, Spawnofs_xy);
	}	
	//A_FireProjectile
	action Actor Right_FireProjectile(class<Actor> missiletype, double angle = 0, bool useammo = true, double spawnofs_xy = 0, double spawnheight = 0, int flags = 0, double pitch = 0)
	{
		invoker.bAltFire = false;
		return A_FireProjectile(missiletype, angle, useammo, spawnofs_xy, spawnheight, flags, pitch);
	}
	action Actor Left_FireProjectile(class<Actor> missiletype, double angle = 0, bool useammo = true, double spawnofs_xy = 0, double spawnheight = 0, int flags = 0, double pitch = 0)
	{
		invoker.bAltFire = true;
		return A_FireProjectile(missiletype, angle, useammo, spawnofs_xy, spawnheight, flags, pitch);
	}
	//A_CustomPunch
	action void Right_CustomPunch(int damage, bool norandom = false, int flags = CPF_USEAMMO, class<Actor> pufftype = "BulletPuff", double range = 0, double lifesteal = 0, int lifestealmax = 0, class<BasicArmorBonus> armorbonustype = "ArmorBonus", sound MeleeSound = 0, sound MissSound = "")
	{
		invoker.bAltFire = false;
		A_CustomPunch(damage, norandom, flags, pufftype, range, lifesteal, lifestealmax, armorbonustype, MeleeSound, MissSound);
	}	
	action void Left_CustomPunch(int damage, bool norandom = false, int flags = CPF_USEAMMO, class<Actor> pufftype = "BulletPuff", double range = 0, double lifesteal = 0, int lifestealmax = 0, class<BasicArmorBonus> armorbonustype = "ArmorBonus", sound MeleeSound = 0, sound MissSound = "")
	{
		invoker.bAltFire = true;
		A_CustomPunch(damage, norandom, flags, pufftype, range, lifesteal, lifestealmax, armorbonustype, MeleeSound, MissSound);
	}
	//A_RailAttack
	action void Right_RailAttack(int damage, int spawnofs_xy = 0, bool useammo = true, color color1 = 0, color color2 = 0, int flags = 0, double maxdiff = 0, class<Actor> pufftype = "BulletPuff", double spread_xy = 0, double spread_z = 0, double range = 0, int duration = 0, double sparsity = 1.0, double driftspeed = 1.0, class<Actor> spawnclass = "none", double spawnofs_z = 0, int spiraloffset = 270, int limit = 0)
	{
		invoker.bAltFire = false;
		A_RailAttack(damage, spawnofs_xy, useammo, color1, color2, flags, maxdiff, pufftype, spread_xy, spread_z, range, duration, sparsity, driftspeed, spawnclass, spawnofs_z, spiraloffset, limit);
	}
	action void Left_RailAttack(int damage, int spawnofs_xy = 0, bool useammo = true, color color1 = 0, color color2 = 0, int flags = 0, double maxdiff = 0, class<Actor> pufftype = "BulletPuff", double spread_xy = 0, double spread_z = 0, double range = 0, int duration = 0, double sparsity = 1.0, double driftspeed = 1.0, class<Actor> spawnclass = "none", double spawnofs_z = 0, int spiraloffset = 270, int limit = 0)
	{
		invoker.bAltFire = true;
		A_RailAttack(damage, spawnofs_xy, useammo, color1, color2, flags, maxdiff, pufftype, spread_xy, spread_z, range, duration, sparsity, driftspeed, spawnclass, spawnofs_z, spiraloffset, limit);
	}
	
	/*	Ready, Fire, AltFire, Select and Desleect state sequences
		have to be defined in this base weapon, otherwise it won't
		compile.
		Left/right gun-specific states have to be defined in your 
		weapons by the modder.
	*/
	States
	{
	// Normally Ready can be left as is in weapons based on this one
	Ready:
		TNT1 A 1 DualWeaponReady();
		loop;
	// Fire state is required for the weapon to function but isn't used directly.
	// Do not redefine.
	Fire:
		TNT1 A 1
		{
			return ResolveState("Ready");
		}
	// AltFire state is required for the weapon to function but isn't used directly.
	// Do not redefine.
	AltFire:
		TNT1 A 1
		{
			return ResolveState("Ready");
		}
	// Normally Select can be left as is in weapons based on this one.
	// Redefine if you want to change selection speed.
	Select:
		TNT1 A 1
		{
			A_overlay(PSP_RIGHTGUN, "Select.Right", nooverride:true);
			A_Overlay(PSP_LEFTGUN, "Select.Left", nooverride:true);
			A_Raise();
		}
		wait;
	// Normally Deselect can be left as is in weapons based on this one.
	// Redefine if you want to change deselection speed.
	Deselect:
		TNT1 A 1
		{
			A_overlay(PSP_RIGHTGUN, "Deselect.Right", nooverride:true);
			A_Overlay(PSP_LEFTGUN, "Deselect.Left", nooverride:true);
			A_Lower();
		}
		wait;
	}
}

Class EDW_PistolRL : EDW_Weapon
{
	Default
	{
		Weapon.AmmoType1 	"Clip";
		Weapon.AmmoGive1 	20;
		Weapon.Ammouse1 	1;
		Weapon.AmmoType2 	"RocketAmmo";
		Weapon.AmmoGive2 	2;
		Weapon.Ammouse2 	1;
		Weapon.Slotnumber	8;
	}
	States
	{
	//Pistol:
	Ready.Right:
		PISG A 1 {
			Right_WeaponReady();
			A_OverlayOffset(OverlayID(),-48,0,WOF_KEEPY);			
		}
		Loop;
	Deselect.Right:
		PISG A 1;
		Loop;
	Select.Right:
		PISG A 1 
		{
			Right_Raise();
			A_OverlayOffset(OverlayID(),-48,0,WOF_KEEPY);
		}
		Loop;
	Fire.Right:
		PISG A 4 A_OverlayOffset(OverlayID(),-48,0,WOF_KEEPY);
		PISG B 6 
		{
			Right_GunFlash();
			A_PlaySound("weapons/pistol",CHAN_RIGHTGUN);
			Right_FireBullets(5.6,0,1,5);
		}
		PISG C 4;
		PISG B 5 Right_ReFire;
		Goto Ready.Right;
	Flash.Right:
		PISF A 7 Bright 
		{
			A_Light1();
			A_OverlayOffset(OverlayID(),-48,0,WOF_KEEPY);
		}
		Goto LightDone;
		
	//Plasma Rifle:
	Ready.Left:
		MISG A 1 
		{
			A_OverlayOffset(OverlayID(),48,0,WOF_KEEPY);
			Left_WeaponReady();
		}
		Loop;
	Deselect.Left:
		MISG A 1;
		Loop;
	Select.Left:
		MISG A 1 
		{
			A_OverlayOffset(OverlayID(),48,0,WOF_KEEPY);
			Left_Raise();
		}
		Loop;
	Fire.Left:
		MISG B 8 
		{
			A_OverlayOffset(OverlayID(),48,0,WOF_KEEPY);	
			Left_GunFlash();		
		}
		MISG B 12
		{
			A_SetFireMode(true);
			A_FireMissile();
		}		
		MISG B 0 Left_ReFire;
		Goto Ready.Left;
	Flash.Left:
		MISF A 3 Bright A_Light1;
		MISF B 4 Bright;
		MISF CD 4 Bright A_Light2;
		Goto LightDone;
	}
}

Class EDW_PlasmaAndCannon : EDW_Weapon
{
	Default
	{
		Weapon.AmmoType1 	"RocketAmmo";
		Weapon.AmmoGive1 	20;
		Weapon.Ammouse1 	1;
		Weapon.AmmoType2 	"Cell";
		Weapon.AmmoGive2 	80;
		Weapon.Ammouse2 	1;
		Weapon.Slotnumber	9;
		Weapon.Bobstyle		'InverseSmooth';
		Weapon.BobRangeX	0.7;
		Weapon.BobRangeY	0.5;
		Weapon.BobSpeed		1.85;
	}
	States
	{
	//Cannon:
	Ready.Right:
		ATGG A 1 Right_WeaponReady();
		Loop;
	Deselect.Right:
		ATGG A 1;
		Loop;
	Select.Right:
		ATGG A 1 Right_Raise();
		Loop;
	Fire.Right:
		ATGG A 1
		{
			A_OverlayOffset(OverlayID(),0,0,WOF_INTERPOLATE);
			A_OverlayScale(OverlayID(),1,1,WOF_INTERPOLATE);
			Right_GunFlash();
			let proj = Right_FireProjectile("Rocket",spawnofs_xy:8);
			if (proj)
			{
				proj.vel *= 2;
				proj.scale *= 0.5;
			}
		}
		ATGG AAA 1
		{
			A_OverlayScale(OverlayID(),0.06,0.06,WOF_ADD);
			A_OverlayScale(PSP_RIGHTFLASH,0.06,0.06,WOF_ADD);
			A_OverlayOffset(OverlayID(),6,6,WOF_ADD);
			A_OverlayOffset(PSP_RIGHTFLASH,6,6,WOF_ADD);
		}
		ATGG AAAAAAAAA 1
		{
			A_OverlayOffset(OverlayID(),-1,-1,WOF_ADD);			
			A_OverlayScale(OverlayID(),-0.02,-0.02,WOF_ADD);
		}
		ATGG AAAAAAAAA 1
		{
			A_OverlayOffset(OverlayID(),-1,-1,WOF_ADD);
			Right_ReFire();
		}
		Goto Ready.Right;
	Flash.Right:
		ATGF A 2 bright A_Light2;
		ATGF B 2 bright A_Light1;
		Goto LightDone;
		
	//Plasma Rifle:
	Ready.Left:
		D3PG A 1 Left_WeaponReady();
		Loop;
	Deselect.Left:
		D3PG A 1;
		Loop;
	Select.Left:
		D3PG A 1 Left_Raise();
		Loop;
	Fire.Left:
		D3PG A 1
		{
			A_OverlayOffset(OverlayID(),0,0);
			Left_GunFlash();
			Left_FireProjectile("Plasmaball",spawnofs_xy:-8);
		}
		D3PG AA 1
		{
			double ofx = -frandom[sfx](2,4);
			double ofy = frandom[sfx](2,4);
			A_OverlayOffset(OverlayID(),ofx,ofy,WOF_ADD);
			A_OverlayOffset(PSP_LEFTFLASH,ofx,ofy,WOF_ADD);
		}
		D3PG A 5
		{
			A_OverlayOffset(OverlayID(),0,0,WOF_INTERPOLATE);
			Left_ReFire();
		}
		Goto Ready.Left;
	Flash.Left:
		D3PF A 2 bright
		{
			A_Light1();
			let psp = Player.FindPSprite(OverlayID());
			if (psp)
				psp.frame = random[sfx](0,2);
		}
		#### # 2 bright 
		{
			A_OverlayFlags(OverlayID(),PSPF_ALPHA|PSPF_FORCEALPHA,true);
			A_OverlayAlpha(OverlayID(),0.65);
		}
		Goto LightDone;
	}
}
	