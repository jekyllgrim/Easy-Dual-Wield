# Easy Dual-Wield for GZDoom by Agent_Ash aka Jekyll Grim Payne

Easy Dual Wield is a base weapon class defined in ZScript that is designed to make it a bit easier to define dual-wielding weapons.

The idea is to have a base weapon class that allows defining a dual-wield weapon where each gun consumes different types of ammo, can be fired independently by using Fire/Altfire buttons, and can be (optionally) reloaded independently.

All of these things can be pretty difficult to get right without a lot of hackery, so Easy Dual Wield is supposed to make it easier.

## Credits and license

Coding: Jekyll Grim Payne aka Agent_Ash

Cannon sprites: Cardboard Marty (included to show case the example weapons only, NOT a part of the library)

Plasma rifle sprites: KRoNoS (included to show case the example weapons only, NOT a part of the library)

License: the project is licensed under MIT license. See LICENSE.txt for details.

## How do use

1. Copy-paste the `EDW_Weapon` class into your mod (and better rename it, just in case it gets used in another mod). This class can be found in `EDWZScript/edw_base.zs`.

2. Make your own dual-wield weapon inherit from `EDW_Weapon`, such as `Class MyDualWieldWeapon : EDW_Weapon`. Now you have access to a number of features and functions that will help.

All of the functions are heavily commented in the `edw_base.zs` file. You can also find 3 example weapons under `EDWZScript/examples.zs` (note, this file is *not* a part of the library, and doesn't have to be copied into your project).

### State sequences

* REQUIRED states for general use (the weapon will not work without them):
  
  * `Ready.Right`
  
  * `Fire.Right`
  
  * `Select.Right`
  
  * `Deselect.Right`
  
  * `Ready.Left`
  
  * `Fire.Left`
  
  * `Select.Left`
  
  * `Deselect.Left`

* OPTIONAL states for refiring (analogs of the Hold/AltHold in default GZDoom weapons):
  
  * `Hold.Right`
  
  * `Hold.Left`

* OPTIONAL states for muzzle flashes (analogs of the Flash/AltFlash states in default GZDoom weapons):

  * `Flash.Right`

  * `Flash.Left`

* Required states for reloading (analogs of the Reload state in regular GZDoom weapons):
  
  * `Reload.Right`
  
  * `Reload.Left`

* Optional states for reloading (entered by one gun while the *other* gun is reloading):
  
  * `ReloadWait.Right` — entered by the *right* weapon while the *left* weapon is being reloaded.
  
  * `ReloadWait.Left` — entered by the *left* weapon while the *right* weapon is being reloaded.

### Functions

There's a number of custom functions in this weapon class. They're all commented in `edw_base.zs` but here's a quick overview of the main ones:

* `Right_WeaponReady` and `Left_WeaponReady` are analogs of `A_WeaponReady`. Should be called in `Ready.Right` and `Ready.Left` state sequences respectively to make the gun ready for firing and reloading.
* `Right_GunFlash` and `Left_GunFlash` are analogs of `A_GunFlash`. They will draw `Flash.Right` and `Flash.Left` state sequences on `PSP_RIGHTFLASH` and `PSP_LEFTFLASH` layers when called.
* `Right_Reload` and `Left_Reload` make the gun enter its respective `Reload.Right`/`Reload.Left` state sequence if the Reload button is pressed. Normally there's no need to call these functions manually, since the weapon will call them automatically. Note, as usual with GZDoom, it's up to you to design the actual reload animations. You can see some examples in `examples.zs`.
* `Right_Loadmag` and `Left_Loadmag` functions refill the gun's magazine from the ammo pool. They're meant to be called somewhere in the `Reload.Right`/`Reload.Left` sequences. If you want a detailed reload, like where every round is inserted in the gun, you'll have to design that yourself.

Attack functions are just simple wrapper functions that call `A_FireProjectile`, `A_FireBullets` and other vanilla functions. The trick here is that they set `invoker.bAltFire` to true or false depending on the gun—this is necessary, because this flag specifically determines which ammo type will be consumed.

As such, you will have functions such as `Right_FireBullets` and `Left_FireBullets` that have the same arguments as `A_FireBullets` but are meant to be called for the right and the left gun respectively. Same goes for all other functions.

If you're designing a custom function or for some other reason need to manually tell the gun which ammo to consume, use `A_SetFireMode(<value>)` function, where the <value> of `true` will make it consume **secondary** ammo (`AmmoType2`), and `false` will make it consume **primary** ammo (`AmmoType1`). Call it right before calling your attack function.

### Properties

* `EDW_Weapon.MagAmmotype1` and `EDW_Weapon.MagAmmotype2`: if you want your weapons to be reloadable, use these properties to specify the name of the ammo classes used as **magazine** ammo. In this case `AmmoType1` and `AmmoType2` will be used as respective reserve ammo. Note that if you do that, the magazine ammo capacity will not be displayed on the HUD, because the default HUD is only coded to display `AmmoType1` and `AmmoType2`. You'll need to code your own HUD to display them as well, because GZDoom HUD is not capable of displaying new ammo properties generically.
* `EDW_Weapon.raisespeed` and `EDW_Weapon.lowerspeed` define the selection and deselection speed for the weapons (6 by default, which is the same as the vanilla `A_Raise`/`A_Lower` speed). If you want a completely custom animation, you can set this to a high value, then draw your own animation in the `Raise.Right` and `Raise.Left` states. (See `EDW_PlasmaAndCannonAkimbo` class in `examples.zs` for an example of how to do that.)

### Flags

* `EDW_Weapon.MIRRORBOB`: If this flag is set, the bobbing for the weapons will be horizontally mirrored.
* `EDW_Weapon.AKIMBORELOAD`: If this flag is set, the guns can be reloaded independently from each other, i.e. you can keep firing the right gun and reload the left gun at the same time, or you can reload both guns simultaneously (doesn't matter if their reload animations are different in length). *Without* this flag the guns can only be reloaded when both of them are in their respective `Ready` sequences, and when one gun gets reloaded, the other one will have to enter its `ReloadWait` sequence (if that exists). The main example class, `EDW_PlasmaAndCannon`, illustrates how this can be done.

## Example weapons

The library comes with 3 example weapons which are all variations on a Plasma rifle + Rocket Cannon combo (see the `examples.zs` file):

* Slot 3: This version consumes `Cell` and `RocketAmmo` directly.
* Slot 4: This version uses magazines and has the `AKIMBORELOAD` flag, meaning each gun can be reloaded at any moment, regardless of what the other gun is doing.
* Slot 5: This version uses magazines and does not have the `AKIMBORELOAD` flag, meaning the guns can be reloaded only when both guns are in the `Ready` sequence, and the other gun has to enter `ReloadWait` sequence for the current one to be reloaded.
