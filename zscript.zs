version "4.6.0"

Class EDW_Weapon : Weapon abstract
{
	const PI = 3.1415926535897932384626433;

	class<Ammo> MagAmmotype1, MagAmmotype2; //magazine ammo (if used)
	property MagAmmotype1 : MagAmmotype1;
	property MagAmmotype2 : MagAmmotype2;
	
	protected bool continueReload;
	
	int raisespeed;
	int lowerspeed;
	property raisespeed : raisespeed;
	property lowerspeed : lowerspeed;
	
	protected int EDWflags;
	FlagDef NOAUTOPRIMARY 		: EDWflags, 0; //NOAUTOFIRE analog for primary attack only
	FlagDef NOAUTOSECONDARY 	: EDWflags, 1; //NOAUTOFIRE analog for secondary attack only
	FlagDef AKIMBORELOAD		: EDWflags, 2; //if true, right and left guns can reload independently
	FlagDef MIRRORWEAPON		: EDWflags, 3; //if true, guns look and behave identical
	FlagDef MIRRORBOB			: EDWflags, 4; //if true, guns bob in opposite horizontal directions
	
	protected Ammo primaryAmmo, secondaryAmmo;	//points either to ammo1/ammo2 or to magammo1/magammo2	
	
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
	protected state s_reloadWaitRight;	
	protected state s_reloadWaitLeft;
	
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
	
	Default
	{
		EDW_Weapon.MagAmmotype1	"";		
		EDW_Weapon.MagAmmotype2 	"";
		EDW_Weapon.RaiseSpeed		6;
		EDW_Weapon.LowerSpeed		6;
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
		s_ReloadRight = FindState("Reload.Right");
		s_ReloadLeft = FindState("Reload.Left");
		s_ReloadWaitRight = FindState("ReloadWait.Right");
		s_ReloadWaitLeft = FindState("ReloadWait.Left");
	}
	
	override void DoEffect()
	{
		super.DoEffect();
		// This block makes sure overlays don't linger if
		// the main layer doesn't exist anymore (e.g. if
		// the player is dead):
		let weap = owner.player.readyweapon;
		if (!weap || weap != self)
			return;

		let psp = owner.player.FindPSprite(PSP_WEAPON);
		if (!psp)
		{
			let pl = owner.player.FindPSprite(PSP_LEFTGUN);
			if (pl)
				pl.Destroy();
			let pr = owner.player.FindPSprite(PSP_RIGHTGUN);
			if (pr)
				pr.Destroy();
		}
	}
	
	// Returns true if ammo should be infinite
	action bool EDW_CheckInfiniteAmmo()
	{
		return (sv_infiniteammo || FindInventory("PowerInfiniteAmmo",true) );
	}
	
	/*	This is meant to be called instead of A_WeaponReady() in the main
		Ready state sequence (NOT in the left/right ready sequences).
		This doesn't actually make the weapon ready for firing directly, but 
		rather	makes sure everything is set up correctly and creates overlays
		if they haven't been created yet.
		It also initiates reloading.
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
		
		// Create gun overlays (once) if they're not drawn for some reason:
		A_Overlay(PSP_RIGHTGUN, "Ready.Right", nooverride:true);
		A_Overlay(PSP_LEFTGUN, "Ready.Left", nooverride:true);		
		
		// Get a pointer to primary ammo (which is either ammotype1 or MagAmmotype1):
		if (!invoker.primaryAmmo && invoker.AmmoType1)
			invoker.primaryAmmo = invoker.MagAmmotype1 ? Ammo(FindInventory(invoker.MagAmmotype1)) : Ammo(FindInventory(invoker.Ammotype1));
		// Same for secondary:
		if (!invoker.secondaryAmmo && invoker.AmmoType2)
			invoker.secondaryAmmo = invoker.MagAmmotype2 ?Ammo(FindInventory(invoker.MagAmmotype2)) : Ammo(FindInventory(invoker.Ammotype2));			
		
		bool readyright = Right_CheckReady();
		bool readyleft = Left_CheckReady();
		bool reloadReadyRight = Right_CheckReadyForReload();
		bool reloadReadyLeft = Left_CheckReadyForReload();
		// disable "rage face" if neither weapon is firing:
		if (readyright && readyleft)
		{
			player.attackdown = false;
		}
		// Handle pressing Reload button
		if (player.cmd.buttons & BT_RELOAD)
		{
			// Check if guns can be reloaded independently:
			if (invoker.bAKIMBORELOAD)
			{
				//reload right gun
				if (reloadReadyRight)
					Right_Reload();
				//at the same time reload left gun
				if (reloadReadyLeft)
					Left_Reload();
			}
			// Otherwise both guns must be in their Ready states:
			else if (readyright && readyleft)
			{
				//only reload right:
				if (reloadReadyRight)
					Right_Reload();
				//otherwise only reload left:
				else
					Left_Reload();
			}
		}
		/*	If player isn't pressing Reload but this bool was set by the right gun,
			proceed to reload the left gun as well.
			This is done to reload both guns in succession without havgin to
			press the Reload button twice.
		*/
		else if (!invoker.bAKIMBORELOAD && invoker.continueReload && reloadReadyLeft)
		{
			invoker.continueReload = false;
			Left_Reload();
		}
		
		A_WeaponReady(WRF_NOFIRE); //let the gun bob and be deselected
		
	}
	
	// Returns true if the gun is in its respective Ready state sequence
	action bool Right_CheckReady(bool left = false)
	{
		let psp = left ? Player.FindPSprite(PSP_LEFTGUN) : Player.FindPSprite(PSP_RIGHTGUN);
		let checkstate = left ? invoker.s_readyleft : invoker.s_readyRight;
		return (psp && InStateSequence(psp.curstate, checkstate));
	}
	// left-gun alias:
	action bool Left_CheckReady()
	{
		return Right_CheckReady(true);
	}
	
	/*	Returns true if:
		- the appropriate Reload sequence exists
		- magazine isn't full
		- reserve ammo isn't empty
	*/
	action bool Right_CheckReadyForReload(bool left = false)
	{
		if (!left)
			return invoker.s_reloadRight && Right_CheckReady() && invoker.primaryAmmo != invoker.ammo1 && (invoker.primaryAmmo.amount < invoker.primaryAmmo.maxamount) && (invoker.ammo1.amount >= invoker.ammouse1);
		else
			return invoker.s_reloadLeft && Left_CheckReady() && invoker.secondaryAmmo != invoker.ammo2 && (invoker.secondaryAmmo.amount < invoker.secondaryAmmo.maxamount) && (invoker.ammo2.amount >= invoker.ammouse2);
	}
	// left-gun alias:
	action bool Left_CheckReadyForReload()
	{
		return Right_CheckReadyForReload(true);
	}
	
	/*	Returns true if the gun has enough ammo to fire.
	*/
	action bool Right_CheckAmmo(bool left = false)
	{
		let ammo2check = left ? invoker.secondaryAmmo : invoker.primaryAmmo;
		// Return true if the weapon doesn't define ammo (= doesn't need it)
		if (!ammo2check)
			return true;
		// Otherwise get the required amount
		int reqAmt = left ? invoker.ammouse2 : invoker.ammouse1;
		// Return true if infinite ammo is active or we have enough
		return EDW_CheckInfiniteAmmo() || ammo2check.amount >= reqAmt;
	}
	//left-gun alias:
	action bool Left_CheckAmmo()
	{
		return Right_CheckAmmo(true);
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
	//Left-gun alias:
	action void Left_Raise()
	{
		Right_Raise(true);
	}
	
	action void DoSingleWeaponBob()
	{
		if (!player || !player.mo)
			return;

		let psp = player.FindPSprite(OverlayID());
		if (!psp)
		{
			return;
		}

		if (!invoker.bMIRRORBOB)
		{
			A_OverlayFlags(OverlayID(), PSPF_ADDBOB, true);
			return;
		}
		
		A_OverlayFlags(OverlayID(), PSPF_ADDBOB, false);
		vector2 bob = player.mo.BobWeapon(1);
		A_OverlayOffset(OverlayID(), 
			(OverlayID() == PSP_RIGHTGUN) ? bob.x : bob.x * -PI * 0.5,
			bob.y,
			WOF_INTERPOLATE
		);
	}
	
	/* 	Ready function for the right weapon.
		Will jump into the right Fire sequence or right Reload sequence
		based on buttons pressed and ammo available.
	*/
	action void Right_WeaponReady(bool left = false)
	{
		if (!player)
			return;
			
		
		state targetState = null;
		bool pressingFire = player.cmd.buttons & (left ? BT_ALTATTACK : BT_ATTACK);
		if (pressingFire)
		{
			if (Right_CheckAmmo(left))
			{
				targetState = left ? invoker.s_fireLeft : invoker.s_fireRight;
				invoker.continueReload = false;
			}
			else
			{
				bool reloadGood = left ? (invoker.MagAmmotype2 && invoker.ammo2.amount > 0) : (invoker.MagAmmotype1 && invoker.ammo1.amount > 0);
				if (reloadGood && (invoker.bAKIMBORELOAD || Right_CheckReadyForReload(left)))
				{
					Right_Reload(left);
					return;
				}
			}			
		}
		//if we're going to fire/reload, disable bobbing:
		if (targetState) 
		{
			A_OverlayFlags(OverlayID(), PSPF_ADDBOB, false);
			player.SetPsprite(OverlayID(),targetState);
		}
		//otherwise re-enable bobbing:
		else 
		{
			// Handle bobbing:
			DoSingleWeaponBob();
		}
	}
	// 	Left-gun alias function:
	action void Left_WeaponReady()
	{
		Right_WeaponReady(true);
	}
	
	/*	Single-gun analong of A_GunFlash. Does two things:
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
			if (Right_CheckAmmo(left) && player.cmd.buttons & atkbutton && player.oldbuttons & atkbutton)
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
			//if the OTHER gun is in its Ready sequence, reset player.refire:
			if (Right_CheckReady(left))
				player.refire = 0;
		}
	}
	action void Left_ReFire()
	{
		Right_ReFire(true);
	}
	
	/*	This jumps to the reload state provided magazine isn't full
		and reserve ammo isn't empty.
	*/
	action void Right_Reload(bool left = false)
	{
		if (!Right_CheckReadyForReload(left))
		{
			return;
		}
		//if bAKIMBORELOAD is false, set the OTHER gun into ReloadWait state sequence:
		if (!invoker.bAKIMBORELOAD)
		{
			int othergun = left ? PSP_RIGHTGUN : PSP_LEFTGUN;
			state waitstate = left ? invoker.s_ReloadWaitRight : invoker.s_ReloadWaitLeft;
			if (waitstate)
			{
				player.SetPsprite(othergun,waitstate);
				invoker.continueReload = true;
			}
		}
		//set the current layer to the Reload state sequence:
		let targetState = left ? invoker.s_reloadLeft : invoker.s_reloadRight;
		int gunlayer = left ? PSP_LEFTGUN : PSP_RIGHTGUN;
		player.SetPsprite(gunlayer,targetState);
	}
	action void Left_Reload()
	{
		Right_Reload(true);
	}
	
	/*	This performs the actual reload by taking as much reserve ammo
		and giving as much mag ammo as possible.
		If you wish to make something like a shotgun reload animation
		where the magazine counter goes up while every shell is inserted,
		you'll have to code that manually.
	*/
	action void Right_Loadmag(bool left = false)
	{
		let magammo = left ? invoker.secondaryAmmo : invoker.primaryAmmo;
		let reserveammo = left ? invoker.ammo2 : invoker.ammo1;
		if (!magammo || !reserveammo || magammo == reserveammo)
			return;
		while (reserveammo.amount > 0 && magammo.amount < magammo.maxamount)
		{
			TakeInventory(reserveammo.GetClass(),1);
			GiveInventory(magammo.GetClass(),1);
		}
	}
	action void Left_Loadmag()
	{
		Right_Loadmag(true);
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

	override bool DepleteAmmo(bool altFire, bool checkEnough, int ammouse)
	{
		if (EDW_CheckInfiniteAmmo())
			return true;

		if (checkEnough && !CheckAmmo (altFire ? AltFire : PrimaryFire, false, false, ammouse))
		{
			return false;
		}
		if (!altFire)
		{
			if (primaryAmmo != null)
			{
				if (ammouse >= 0 && bDehAmmo)
				{
					primaryAmmo.Amount -= ammouse;
				}
				else
				{
					primaryAmmo.Amount -= AmmoUse1;
				}
			}
			if (bPRIMARY_USES_BOTH && secondaryAmmo != null)
			{
				secondaryAmmo.Amount -= AmmoUse2;
			}
		}
		else
		{
			if (secondaryAmmo != null)
			{
				secondaryAmmo.Amount -= AmmoUse2;
			}
			if (bALT_USES_BOTH && primaryAmmo != null)
			{
				primaryAmmo.Amount -= AmmoUse1;
			}
		}
		if (primaryAmmo != null && primaryAmmo.Amount < 0)
		{
			primaryAmmo.Amount = 0;
		}
		if (secondaryAmmo != null && secondaryAmmo.Amount < 0)
		{
			secondaryAmmo.Amount = 0;
		}

		return true;
	}
	
	/*	Ready, Fire, AltFire, Select and Deselect state sequences
		have to be defined in this base weapon, otherwise it won't
		compile.
		Left/right gun-specific states have to be defined in your 
		weapons by the modder.
	*/
	States
	{
	// Normally Ready can be left as is in weapons based on this one
	Ready:
		TNT1 A 1 
		{
			DualWeaponReady();
			//console.printf("primary: %d | secondary: %d",invoker.primaryAmmo.amount,invoker.secondaryAmmo.amount);
		}
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
	// Redefine only if you want to significantly change selection animation
	Select:
		TNT1 A 0
		{
			A_overlay(PSP_RIGHTGUN, "Select.Right");
			A_Overlay(PSP_LEFTGUN, "Select.Left");
		}
		TNT1 A 1 A_Raise(invoker.raisespeed);
		wait;
	// Normally Deselect can be left as is in weapons based on this one.
	// Redefine if you want to significantly change deselection animation
	Deselect:
		TNT1 A 0
		{
			A_overlay(PSP_RIGHTGUN, "Deselect.Right");
			A_Overlay(PSP_LEFTGUN, "Deselect.Left");
		}
		TNT1 A 1 A_Lower(invoker.lowerspeed);
		wait;
	}
}


/*	This is an example weapon that combines a plasma rifle
	and a rocket cannon.
	
	Apart from showing how to apply the Easy Dual-Wield functions,
	in this gun I'm also demonstrating how to apply overlay offset 
	and scale to make the gun look more interesting.
	You don't have to copy my methods exactly, this is just a showcase
	of things that could be done to improve the visuals of the weapon.
*/



// This is the main demo weapon. It shows how to define
// all required states and how to call functions.
// It also uses magazines, and guns can't be reloaded
// at the same time.
Class EDW_PlasmaAndCannon : EDW_Weapon
{
	Default
	{
		EDW_Weapon.MagAmmotype1 "EDW_RocketMag";
		EDW_Weapon.MagAmmotype2 "EDW_PlasmaMag";
		Weapon.Slotnumber	4;
		Weapon.AmmoType1 	"RocketAmmo";
		Weapon.AmmoGive1 	20;
		Weapon.Ammouse1 	1;
		Weapon.AmmoType2 	"Cell";
		Weapon.AmmoGive2 	80;
		Weapon.Ammouse2 	1;
		// InverseSmooth is my preferred bobbing style, but any should work
		Weapon.Bobstyle		'InverseSmooth';
		Weapon.BobRangeX	0.7;
		Weapon.BobRangeY	0.5;
		Weapon.BobSpeed		1.85;
	}
	States
	{
	/*//////////////////
		CANNON STATES
	*///////////////////[
	Ready.Right:
		ATGG A 1 Right_WeaponReady();
		Loop;
	Deselect.Right:
		ATGG A 1;
		Loop;
	Select.Right:
		ATGG A 1 Right_Raise();
		Loop;
	// Below I'm using some overlay functions for visuals only.
	Fire.Right:
		ATGG A 1
		{
			Right_GunFlash();
			//We change the gun's scale and offset in its attack animation,
			//so I start by resetting those just to be safe.
			A_OverlayOffset(OverlayID(),0,0,WOF_INTERPOLATE);
			A_OverlayScale(OverlayID(),1,1,WOF_INTERPOLATE);
			//Do the same with the muzzle flash so it's synced
			A_OverlayOffset(PSP_RIGHTFLASH,0,0,WOF_INTERPOLATE);
			A_OverlayScale(PSP_RIGHTFLASH,1,1,WOF_INTERPOLATE);
			// This simply spawns a rocket that looks smaller and flies faster,
			// because I didn't bother with making a new projectile for this demo.
			let proj = Right_FireProjectile("Rocket",spawnofs_xy:8);
			if (proj)
			{
				proj.vel *= 2.5;
				proj.scale *= 0.38;
			}
		}
		ATGG AAA 1
		{
			//Offset the gun and increase its scale:
			A_OverlayScale(OverlayID(),0.06,0.06,WOF_ADD);
			A_OverlayOffset(OverlayID(),6,6,WOF_ADD);
			//Do the same with the muzzle flash so it's synced
			A_OverlayScale(PSP_RIGHTFLASH,0.06,0.06,WOF_ADD);
			A_OverlayOffset(PSP_RIGHTFLASH,6,6,WOF_ADD);
		}
		ATGG AAAAAAAAA 1
		{
			//And here we'll slowly roll back the offset and the scale.
			//The flash isn't drawn at this point, so no need to worry about it.
			A_OverlayOffset(OverlayID(),-1,-1,WOF_ADD);			
			A_OverlayScale(OverlayID(),-0.02,-0.02,WOF_ADD);
		}
		ATGG AAAAAAAAA 1
		{
			//The gun keeps slowly retracting from the recoil, but at this point
			//we're letting the player refire it.
			A_OverlayOffset(OverlayID(),-1,-1,WOF_ADD);
			Right_ReFire();
		}
		Goto Ready.Right;
	Flash.Right:
		ATGF A 2 bright A_Light2;
		ATGF B 2 bright A_Light1;
		Goto LightDone;
	// The reload animation:
	Reload.Right:
		ATGG AAAAAAA 1
		{
			//Tilt the gun to the right, offset and scale it:
			A_OverlayRotate(OverlayID(),-2,WOF_ADD);
			A_OverlayOffset(OverlayID(),6,3,WOF_ADD);
			A_OverlayScale(OverlayID(),0.012,0.012,WOF_ADD);
		}
		ATGG A 6;
		ATGG A 1 
		{
			//Play reload sound and jerk the gun upward:
			A_OverlayOffset(OverlayID(),0,4,WOF_ADD);
			A_StartSound("misc/w_pkup",CHAN_AUTO);
			Right_Loadmag();
		}
		//now lower the gun as if we've inserted a magazine:
		ATGG AAAA 1 A_OverlayOffset(OverlayID(),0,-1,WOF_ADD);
		ATGG A 5;
		ATGG AAAAAAA 1
		{
			//Restore the gun's angle, offset and scale:
			A_OverlayRotate(OverlayID(),2,WOF_ADD);
			A_OverlayOffset(OverlayID(),-6,-3,WOF_ADD);
			A_OverlayScale(OverlayID(),-0.012,-0.012,WOF_ADD);
		}
		TNT1 A 0 
		{
			//Make sure the angle/scale/offset are correct:
			A_OverlayRotate(OverlayID(),0);
			A_OverlayOffset(OverlayID(),0,0);
			A_OverlayScale(OverlayID(),1,1);
		}
		goto Ready.Right;
	// This animation plays out while the OTHER gun is being reloaded:
	ReloadWait.Right:
		ATGG AAAA 1 A_OverlayOffset(OverlayID(),10,20,WOF_ADD);
		TNT1 A 1
		{
			//keep checking if the other gun is still in Reload,
			//and if not, jump to the end of the animation:
			let psp = Player.FindPSprite(PSP_LEFTGUN);
			return A_JumpIf(!psp || !InStateSequence(psp.curstate,invoker.s_reloadLeft), "ReloadWaitEnd.Right");
		}
		wait;
	ReloadWaitEnd.Right:
		ATGG AAAA 1 A_OverlayOffset(OverlayID(),-10,-20,WOF_ADD);
		TNT1 A 0 A_OverlayOffset(OverlayID(),0,0);
		goto Ready.Right;
			
		
	/*////////////////////////
		PLASMA RIFLE STATES
	*/////////////////////////
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
			//Plasma rifle animation is a bit simpler, it only uses some offsets
			//without modifying scale:
			A_OverlayOffset(OverlayID(),0,0);
			Left_GunFlash();
			Left_FireProjectile("Plasmaball",spawnofs_xy:-8);
		}
		D3PG AA 1
		{
			//I want the gun to recoil with a bit of randomization,
			//so I'm first getting some random values:
			vector2 ofs = (-frandom[sfx](2,4), frandom[sfx](2,4));
			//Then I'm applying those values both to the gun
			//and to its muzzle flash, so that they're synced:
			A_OverlayOffset(OverlayID(),ofs.x,ofs.y,WOF_ADD);
			A_OverlayOffset(PSP_LEFTFLASH,ofs.x,ofs.y,WOF_ADD);
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
			//The muzzle flash randomly uses one of 3 possible frames:
			let psp = Player.FindPSprite(OverlayID());
			if (psp)
				psp.frame = random[sfx](0,2);
			//I also want to modify the layer's alpha, so I'm setting this here too
			//(without setting these flags overlay's alpha can't be changed)
			A_OverlayFlags(OverlayID(),PSPF_ALPHA|PSPF_FORCEALPHA,true);
		}
		//and I fade the flash out just to make it a bit more interesting:
		#### # 1 bright A_OverlayAlpha(OverlayID(),0.65);
		#### # 1 bright A_OverlayAlpha(OverlayID(),0.3);
		Goto LightDone;
	Reload.Left:
		D3PG AAAAAAA 1
		{
			//Tilt the gun to the left, offset and scale it:
			A_OverlayRotate(OverlayID(),2,WOF_ADD);
			A_OverlayOffset(OverlayID(),-6,3,WOF_ADD);
			A_OverlayScale(OverlayID(),0.012,0.012,WOF_ADD);
		}
		D3PG A 6;
		D3PG A 1 
		{
			//Play reload sound and jerk the gun upward:
			A_OverlayOffset(OverlayID(),0,4,WOF_ADD);
			A_StartSound("misc/w_pkup",CHAN_AUTO);
			Left_Loadmag();
		}
		D3PG AAAA 1 A_OverlayOffset(OverlayID(),0,-1,WOF_ADD);
		D3PG A 5;
		D3PG AAAAAAA 1
		{
			//Restore the gun's angle, offset and scale:
			A_OverlayRotate(OverlayID(),-2,WOF_ADD);
			A_OverlayOffset(OverlayID(),6,-3,WOF_ADD);
			A_OverlayScale(OverlayID(),-0.012,-0.012,WOF_ADD);
		}
		TNT1 A 0 
		{
			//Make sure the angle/scale/offset are correct:
			A_OverlayRotate(OverlayID(),0);
			A_OverlayOffset(OverlayID(),0,0);
			A_OverlayScale(OverlayID(),1,1);
		}
		Goto Ready.Left;
	// This animation plays out while the OTHER gun is being reloaded:
	ReloadWait.Left:
		D3PG AAAA 1 A_OverlayOffset(OverlayID(),-10,20,WOF_ADD);
		TNT1 A 1
		{
			//keep checking if the other gun is still in Reload,
			//and if not, jump to the end of the animation:
			let psp = Player.FindPSprite(PSP_RIGHTGUN);
			return A_JumpIf(!psp || !InStateSequence(psp.curstate,invoker.s_reloadRight), "ReloadWaitEnd.Left");
		}
		wait;
	ReloadWaitEnd.Left:
		D3PG AAAA 1 A_OverlayOffset(OverlayID(),10,-20,WOF_ADD);
		TNT1 A 0 A_OverlayOffset(OverlayID(),0,0);
		goto Ready.Left;
	}
}

Class EDW_PlasmaMag : Ammo
{
	Default
	{
		Inventory.Amount 1;
		Inventory.Maxamount 40;
		Ammo.BackPackAmount 0;
		Ammo.BackPackMaxamount 40;
		+INVENTORY.IGNORESKILL
	}
}

Class EDW_RocketMag : Ammo
{
	Default
	{
		Inventory.Amount 1;
		Inventory.Maxamount 8;
		Ammo.BackPackAmount 0;
		Ammo.BackPackMaxamount 8;
		+INVENTORY.IGNORESKILL
	}
}

// This is a simple version that doesn't use magazines,
// it consumes ammo directly.
Class EDW_PlasmaAndCannonNoMags : EDW_PlasmaAndCannon
{
	Default
	{
		EDW_Weapon.MagAmmotype1 "";
		EDW_Weapon.MagAmmotype2 "";
		Weapon.Slotnumber	3;
		+EDW_Weapon.MIRRORBOB
	}
}

// This version does use magazines, but both guns can be
// reloaded independently, so the reload animation is
// simpler and is easier to handle.
Class EDW_PlasmaAndCannonAkimbo : EDW_PlasmaAndCannon
{
	Default
	{
		+EDW_Weapon.AKIMBORELOAD
		+EDW_Weapon.MIRRORBOB
		Weapon.Slotnumber	5;
		EDW_Weapon.raisespeed 32; //this is high because we're using custom animation
		Weapon.BobStyle 'Normal';
	}
	States
	{
	/*	In this example we're using custom selection animation.
		The right gun is selected slowly and rotates.
	*/
	Select.Right:
		TNT1 A 0
		{
			A_OverlayOffset(OverlayID(),20,60);
			A_OverlayRotate(OverlayID(),16);
		}
		ATGG AAAAAAAAAAAAAAAA 1 
		{
			A_OverlayOffset(OverlayID(),-1.25,-3.75,WOF_ADD);
			A_OverlayRotate(OverlayID(),-1,WOF_ADD);
		}
		goto Ready.Right;
	// The left gun is selected quickly
	Select.Left:
		TNT1 A 0 A_OverlayOffset(OverlayID(),-60,60);
		D3PG AAAAA 1 A_OverlayOffset(OverlayID(), 12,-12,WOF_ADD);
		goto Ready.Left;
	}
}