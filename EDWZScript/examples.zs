


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