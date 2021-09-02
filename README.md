# Easy Dual-Wield for GZDoom by Agent_Ash aka Jekyll Grim Payne

Easy Dual Wield is a base weapon class defined in ZScript that is designed to make it a bit easier to define dual-wielding weapons.

The idea is to have a base weapon class that allows defining a dual-wield weapon where each gun consumes different types of ammo, can be fired independently by using Fire/Altfire buttons, and can be (optionally) reloaded independently.

All of these things can be pretty difficult to get right without a lot of hackery, so Easy Dual Wield is supposed to make it easier.

## Credits and license

Coding: Jekyll Grim Payne aka Agent_Ash

Cannon sprites: Cardboard Marty

Plasma rifle sprites: KRoNoS

License: the project is licensed under MIT license. See LICENSE.txt for details.

## How do use

Copy-paste the `EDW_Weapon` class into your mod (and better rename it, just in case it gets used in another mod). Make your own dual-wield weapon inherit from `EDW_Weapon`, such as `Class MyDualWieldWeapon : EDW_Weapon`. Now you have access to a number of features and functions that will help.

All of the functions are heavily commented inside `zscript.zs` file, and it also contains 3 example weapons that are also heavily commented. I'll only cover some basics below.

### State sequences

You will need at least the following state sequences defined in your weapon: `Ready.Right`, `Fire.Right`, `Select.Right`, `Deselect.Right` and `Ready.Left`, `Fire.Left`, `Select.Left`, `Deselect.Left`.

`Hold.Right` and `Hold.Left` are also supported, functioning the same way as `Hold` and `AltHold` function in a regular weapon.

If your weapon can be reloaded, you will also need `Reload.Right` and `Reload.Left`. If your weapon does *not* have AKIMBORELOAD flag (meaning, guns can't be reloaded simultaneously), you will also need `ReloadWait.Right` and `ReloadWait.Left`—these state sequences will be entered by the *other* gun while the current one gets reloaded. (It's implied that, for example, when your right gun is reloaded in `Reload.Right`, your left gun will lower below the screen in `ReloadWait.Left`.)

### Functions

There's a number of custom functions in this weapon class. They're all commented in `zscript.zs` but here's a quick overview of the main ones:

* `Right_WeaponReady` and `Left_WeaponReady` should be called in `Ready.Right` and `Ready.Left` state sequences and make the gun ready for firing and reloading.
* `Right_GunFlash` and `Left_GunFlash` are analogs of `A_GunFlash`. They will draw `Flash.Right` and `Flash.Left` state sequences on `PSP_RIGHTFLAG` and `PSP_LEFTFLASH` layers.
* `Right_Reload` and `Left_Reload` make the gun enter its respective `Reload.Right`/`Reload.Left` state sequence. How the reload animation is designed is up to you.
* `Right_Loadmag` and `Left_Loadmag` functions refill the gun's magazine from the ammo pool. They're meant to be called somewhere in the `Reload.` sequence. If you want a detailed reload, like where every round is inserted in the gun, you'll have to design that yourself.

Attack functions are just simple wrapper functions that call `A_FireProjectile`, `A_FireBullets` and other vanilla functions. The trick here is that they set `invoker.bAltFire` to true or false depending on the gun—this is necessary, because this flag specifically determines which ammo type will be consumed.

As such, you will have functions such as `Right_FireBullets` and `Left_FireBullets` that have the same arguments as `A_FireBullets` but are meant to be called for the right and the left gun respectively. Same goes for all other functions.

If you're designing a custom function or for some other reason need to manually tell the gun which ammo to consume, use `A_SetFireMode(<value>)` function, where the <value> of `true` will make it consume secondary ammo, and `false` will make it consume primary ammo. Call it right before calling your attack function.

### Properties and flags

* `EDW_Weapon.MagAmmotype1` and `EDW_Weapon.MagAmmotype2`: if you want your weapons to be reloadable, use these properties to specify the name of the ammo classes used as magazine ammo. In this case `Ammotype1` and `Ammotype2` will be used as respective reserve ammo. Note that if you do that, the magazine ammo capacity will not be displayed on the HUD, because the default HUD is only coded to display `Ammotype1` and `Ammotype2`. You'll need to code your own HUD to display them as well.
* `EDW_Weapon.raisespeed` and `EDW_Weapon.lowerspeed` define the selection and deselection speed for the weapons (6 by default, which is the same as the vanilla `A_Raise`/`A_Lower` speed). If you want a completely custom animation, you can set this to a high value, then draw your own animation in the `Raise.Right` and `Raise.Left` states. (See `EDW_PlasmaAndCannonAkimbo` class in `zscript.zs` for an example of how to do that.)
* `EDW_Weapon.AKIMBORELOAD`: if this flag is set, the guns can be reloaded at any moment, independently from each other. You can keep firing the right gun and reload the left gun at the same time, or you can reload both guns simultaneously (doesn't matter if their reload animations are different in length). *Without* this flag the guns can only be reloaded when both of them are in their respective `Ready` sequences, and when one gun gets reloaded, the other one will have to enter its `ReloadWait` sequence (if that exists). The main example class, `EDW_PlasmaAndCannon`, illustrates how this can be done.

## Example weapons

The library comes with 3 example weapons which are all variations on a Plasma rifle + Rocket Cannon combo:

* Slot 3: This variation consumes `Cell` and `RocketAmmo` directly
* Slot 4: This version uses magazines and has `AKIMBORELOAD` flag, meaning each gun can be reloaded at any moment, regardless of what the other gun is doing.
* Slot 5: This version uses magazines and does not have `AKIMBORELOAD` flag, meaning the guns can be reloaded only when both guns are in the `Ready` sequence, and the other gun has to enter `ReloadWait` sequence for the current one to be reloaded.
