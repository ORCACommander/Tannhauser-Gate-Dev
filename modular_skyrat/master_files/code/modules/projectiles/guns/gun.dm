
#define DUALWIELD_PENALTY_EXTRA_MULTIPLIER 1.4
#define FIRING_PIN_REMOVAL_DELAY 50

/obj/item/gun
	name = "gun"
	desc = "It's a gun. It's pretty terrible, though."
	icon = 'modular_skyrat/modules/fixing_missing_icons/ballistic.dmi' // skyrat edit
	icon_state = "detective"
	inhand_icon_state = "gun"
	worn_icon_state = "gun"
	flags_1 =  CONDUCT_1
	slot_flags = ITEM_SLOT_BELT
	custom_materials = list(/datum/material/iron = 2000)
	w_class = WEIGHT_CLASS_NORMAL
	throwforce = 5
	throw_speed = 3
	throw_range = 5
	force = 5
	item_flags = NEEDS_PERMIT
	attack_verb_continuous = list("strikes", "hits", "bashes")
	attack_verb_simple = list("strike", "hit", "bash")

	var/gun_flags = NONE
	var/fire_sound = 'sound/weapons/gun/pistol/shot.ogg'
	var/vary_fire_sound = TRUE
	var/fire_sound_volume = 50
	var/dry_fire_sound = 'sound/weapons/gun/general/dry_fire.ogg'
	var/suppressed = null // whether or not a message is displayed when fired
	var/can_suppress = FALSE
	var/suppressed_sound = 'sound/weapons/gun/general/heavy_shot_suppressed.ogg'
	var/suppressed_volume = 60
	var/can_unsuppress = TRUE
	var/recoil = 0 // boom boom shake the room
	var/clumsy_check = TRUE
	var/obj/item/ammo_casing/chambered = null
	trigger_guard = TRIGGER_GUARD_NORMAL // trigger guard on the weapon, hulks can't fire them with their big meaty fingers
	var/sawn_desc = null // description change if weapon is sawn-off
	var/sawn_off = FALSE
	var/burst_size = 1 // how large a burst is
	var/fire_delay = 0 // rate of fire for burst firing and semi auto
	var/firing_burst = 0 // Prevent the weapon from firing again while already firing
	var/semicd = 0 // cooldown handler
	var/weapon_weight = WEAPON_LIGHT
	var/dual_wield_spread = 24 // additional spread when dual wielding

	/// Just 'slightly' snowflakey way to modify projectile damage for projectiles fired from this gun.
	var/projectile_damage_multiplier = 1

	var/spread = 0 // Spread induced by the gun itself.
	var/randomspread = 1 // Set to 0 for shotguns. This is used for weapons that don't fire all their bullets at once.

	lefthand_file = 'icons/mob/inhands/weapons/guns_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/weapons/guns_righthand.dmi'

	var/obj/item/firing_pin/pin = /obj/item/firing_pin // standard firing pin for most guns

	var/pinless = FALSE

	var/can_bayonet = FALSE // if a bayonet can be added or removed if it already has one.
	var/bayonet_state = "bayonet"
	var/bayonet_icon = 'icons/obj/guns/bayonets.dmi'
	var/obj/item/knife/bayonet
	var/knife_x_offset = 0
	var/knife_y_offset = 0

	var/ammo_x_offset = 0 // used for positioning ammo count overlay on sprite
	var/ammo_y_offset = 0

	// Zooming
	var/pb_knockback = 0

	var/safety = FALSE /// Internal variable for keeping track whether the safety is on or off
	var/has_gun_safety = FALSE /// Whether the gun actually has a gun safety
	var/datum/action/item_action/toggle_safety/toggle_safety_action

	var/datum/action/item_action/toggle_firemode/firemode_action
	/// Current fire selection, can choose between burst, single, and full auto.
	var/fire_select = SELECT_SEMI_AUTOMATIC
	var/fire_select_index = 1
	/// What modes does this weapon have? Put SELECT_FULLY_AUTOMATIC in here to enable fully automatic behaviours.
	var/list/fire_select_modes = list(SELECT_SEMI_AUTOMATIC)
	/// if i`1t has an icon for a selector switch indicating current firemode.
	var/selector_switch_icon = FALSE
	/// Bitflags for the company that produces the gun, do not give more than one company.
	var/company_flag

/datum/action/item_action/toggle_safety
	name = "Toggle Safety"
	icon_icon = 'modular_skyrat/modules/gunsafety/icons/actions.dmi'
	button_icon_state = "safety_on"

/obj/item/gun/ui_action_click(mob/user, actiontype)
	if(istype(actiontype, /datum/action/item_action/toggle_firemode))
		fire_select()
	else if(istype(actiontype, toggle_safety_action))
		toggle_safety(user)
	else
		..()

/obj/item/gun/Initialize()
	. = ..()
	if(pin && !pinless)
		pin = new pin(src)

	add_seclight_point()

	if(has_gun_safety)
		safety = TRUE
		toggle_safety_action = new(src)
		add_item_action(toggle_safety_action)

	if(burst_size > 1 && !(SELECT_BURST_SHOT in fire_select_modes))
		fire_select_modes.Add(SELECT_BURST_SHOT)
	else if(burst_size <= 1 && (SELECT_BURST_SHOT in fire_select_modes))
		fire_select_modes.Remove(SELECT_BURST_SHOT)

	burst_size = 1

	sort_list(fire_select_modes, /proc/cmp_numeric_asc)

	if(fire_select_modes.len > 1)
		firemode_action = new(src)
		firemode_action.button_icon_state = "fireselect_[fire_select]"
		firemode_action.UpdateButtons()
		add_item_action(firemode_action)


/obj/item/gun/ComponentInitialize()
	. = ..()
	if(SELECT_FULLY_AUTOMATIC in fire_select_modes)
		AddComponent(/datum/component/automatic_fire, fire_delay)

/obj/item/gun/Destroy()
	if(isobj(pin)) // Can still be the initial path, then we skip
		QDEL_NULL(pin)
	if(bayonet)
		QDEL_NULL(bayonet)
	if(chambered) // Not all guns are chambered (EMP'ed energy guns etc)
		QDEL_NULL(chambered)
	if(isatom(suppressed))
		QDEL_NULL(suppressed)
	if(toggle_safety_action)
		QDEL_NULL(toggle_safety_action)
	if(firemode_action)
		QDEL_NULL(firemode_action)
	. = ..()

/// Handles adding [the seclite mount component][/datum/component/seclite_attachable] to the gun.
/// If the gun shouldn't have a seclight mount, override this with a return.
/// Or, if a child of a gun with a seclite mount has slightly different behavior or icons, extend this.
/obj/item/gun/proc/add_seclight_point()
	return

/obj/item/gun/handle_atom_del(atom/gun_atom)
	if(gun_atom == pin)
		pin = null
	if(gun_atom == chambered)
		chambered = null
		update_appearance()
	if(gun_atom == bayonet)
		clear_bayonet()
	if(gun_atom == suppressed)
		clear_suppressor()
	. = ..()

/// Clears var and updates icon. In the case of ballistic weapons, also updates the gun's weight.
/obj/item/gun/proc/clear_suppressor()
	if(!can_unsuppress)
		return
	suppressed = null
	update_appearance()

/obj/item/gun/examine(mob/user)
	. = ..()
	if(!pinless)
		if(pin)
			. += "It has \a [pin] installed."
			. += span_info("[pin] looks like it could be removed with some <b>tools</b>.")
		else
			. += "It doesn't have a <b>firing pin</b> installed, and won't fire."

	if(bayonet)
		. += "It has \a [bayonet] [can_bayonet ? "" : "permanently "]affixed to it."
		if(can_bayonet) // if it has a bayonet and this is false, the bayonet is permanent.
			. += span_info("[bayonet] looks like it can be <b>unscrewed</b> from [src].")
	if(can_bayonet)
		. += "It has a <b>bayonet</b> lug on it."
	if(has_gun_safety)
		. += "<span>The safety is [safety ? "<font color='#00ff15'>ON</font>" : "<font color='#ff0000'>OFF</font>"].</span>"

	switch(company_flag)
		if(COMPANY_CANTALAN)
			. += "<br>It has <b>[span_purple("Cantalan Federal Arms")]</b> etched into the grip."
		if(COMPANY_ARMADYNE)
			. += "<br>It has <b>[span_red("Armadyne Corporation")]</b> etched into the barrel."
		if(COMPANY_SCARBOROUGH)
			. += "<br>It has <b>[span_orange("Scarborough Arms")]</b> stamped onto the grip."
		if(COMPANY_DONK)
			. += "<br>It has a <b>[span_green("Donk Corporation")]</b> label visible in the plastic."
		if(COMPANY_BOLT)
			. += "<br>It has <b>[span_yellow("Bolt Fabrications")]</b> stamped onto the reciever."
		if(COMPANY_OLDARMS)
			. += "<br>It has <b><i>[span_red("Armadyne Oldarms")]</i></b> etched into the barrel."
		if(COMPANY_IZHEVSK)
			. += "<br>It has <b>[span_brown("Izhevsk Coalition")]</b> cut in above the magwell."
		if(COMPANY_NANOTRASEN)
			. += "<br>It has <b>[span_blue("Nanotrasen Armories")]</b> etched into the reciever."
		if(COMPANY_ALLSTAR)
			. += "<br>It has <b>[span_red("Allstar Lasers Inc.")]</b> stamped on the front grip."
		if(COMPANY_MICRON)
			. += "<br>It has <b>[span_cyan("Micron Control Sys.")]</b> cut in above the cell slot."
		if(COMPANY_INTERDYNE)
			. += "<br>It has <b>[span_cyan("Interdyne Pharmaceuticals")]</b> stamped onto the barrel."
		if(COMPANY_ABDUCTOR)
			. += "<br>It has <b>[span_abductor("✌︎︎♌︎︎♎︎︎◆︎︎♍︎︎⧫︎︎❄︎♏︎♍︎♒︎")]</b> engraved into the photon accelerator."

/obj/item/gun/proc/fire_select()
	var/mob/living/carbon/human/user = usr

	var/max_mode = fire_select_modes.len

	if(max_mode <= 1)
		balloon_alert(user, "only one firemode!")
		return

	fire_select_index = 1 + fire_select_index % max_mode // Magic math to cycle through this shit!

	fire_select = fire_select_modes[fire_select_index]

	switch(fire_select)
		if(SELECT_SEMI_AUTOMATIC)
			burst_size = 1
			fire_delay = 0
			SEND_SIGNAL(src, COMSIG_GUN_AUTOFIRE_DESELECTED, user)
			balloon_alert(user, "semi-automatic")
		if(SELECT_BURST_SHOT)
			burst_size = initial(burst_size)
			fire_delay = initial(fire_delay)
			SEND_SIGNAL(src, COMSIG_GUN_AUTOFIRE_DESELECTED, user)
			balloon_alert(user, "[burst_size]-round burst")
		if(SELECT_FULLY_AUTOMATIC)
			burst_size = 1
			SEND_SIGNAL(src, COMSIG_GUN_AUTOFIRE_SELECTED, user)
			balloon_alert(user, "automatic")

	playsound(user, 'sound/weapons/empty.ogg', 100, TRUE)
	update_appearance()
	firemode_action.button_icon_state = "fireselect_[fire_select]"
	firemode_action.UpdateButtons()
	SEND_SIGNAL(src, COMSIG_UPDATE_AMMO_HUD)
	return TRUE

// called after the gun has successfully fired its chambered ammo.
/obj/item/gun/proc/process_chamber(empty_chamber = TRUE, from_firing = TRUE, chamber_next_round = TRUE)
	handle_chamber(empty_chamber, from_firing, chamber_next_round)
	SEND_SIGNAL(src, COMSIG_GUN_CHAMBER_PROCESSED)

/obj/item/gun/proc/handle_chamber(empty_chamber = TRUE, from_firing = TRUE, chamber_next_round = TRUE)
	return


// check if there's enough ammo/energy/whatever to shoot one time
// i.e if clicking would make it shoot
/obj/item/gun/proc/can_shoot()
	return TRUE

/obj/item/gun/proc/tk_firing(mob/living/user)
	return !user.contains(src)

/obj/item/gun/proc/shoot_with_empty_chamber(mob/living/user as mob|obj)
	balloon_alert(user, "*click*")
	playsound(src, dry_fire_sound, 30, TRUE)

/obj/item/gun/proc/fire_sounds()
	if(suppressed)
		playsound(src, suppressed_sound, suppressed_volume, vary_fire_sound, ignore_walls = FALSE, extrarange = SILENCED_SOUND_EXTRARANGE, falloff_distance = 0)
	else
		playsound(src, fire_sound, fire_sound_volume, vary_fire_sound)

/obj/item/gun/proc/shoot_live_shot(mob/living/user, pointblank = 0, atom/pbtarget = null, message = 1)
	if(recoil && !tk_firing(user))
		shake_camera(user, recoil + 1, recoil)
	fire_sounds()
	if(!suppressed)
		if(message)
			if(tk_firing(user))
				visible_message(
						span_danger("[src] fires itself[pointblank ? " point blank at [pbtarget]!" : "!"]"),
						blind_message = span_hear("You hear a gunshot!"),
						vision_distance = COMBAT_MESSAGE_RANGE
				)
			else if(pointblank)
				user.visible_message(
						span_danger("[user] fires [src] point blank at [pbtarget]!"),
						span_danger("You fire [src] point blank at [pbtarget]!"),
						span_hear("You hear a gunshot!"), COMBAT_MESSAGE_RANGE, pbtarget
				)
				to_chat(pbtarget, span_userdanger("[user] fires [src] point blank at you!"))
				if(pb_knockback > 0 && ismob(pbtarget))
					var/mob/PBT = pbtarget
					var/atom/throw_target = get_edge_target_turf(PBT, user.dir)
					PBT.throw_at(throw_target, pb_knockback, 2)
			else if(!tk_firing(user))
				user.visible_message(
						span_danger("[user] fires [src]!"),
						blind_message = span_hear("You hear a gunshot!"),
						vision_distance = COMBAT_MESSAGE_RANGE,
						ignored_mobs = user
				)
	if(user.resting) // SKYRAT EDIT ADD - no crawlshooting
		user.Immobilize(20, TRUE) // SKYRAT EDIT END

/obj/item/gun/emp_act(severity)
	. = ..()
	if(!(. & EMP_PROTECT_CONTENTS))
		for(var/obj/iterated_object in contents)
			iterated_object.emp_act(severity)

/obj/item/gun/afterattack_secondary(mob/living/victim, mob/living/user, params)
	if(!ismob(victim))
		return
	if(user.GetComponent(/datum/component/gunpoint))
		balloon_alert(user, "already holding someone up!")
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN
	if(user == victim)
		balloon_alert(user, "can't hold yourself up!")
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

	user.AddComponent(/datum/component/gunpoint, victim, src)
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/obj/item/gun/afterattack(atom/target, mob/living/user, flag, params)
	. = ..()
	return fire_gun(target, user, flag, params)

/obj/item/gun/proc/fire_gun(atom/target, mob/living/user, flag, params)
	if(QDELETED(target))
		return
	if(firing_burst)
		return
	if(SEND_SIGNAL(src, COMSIG_GUN_TRY_FIRE, user, target, flag, params) & COMPONENT_CANCEL_GUN_FIRE)
		return
	if(flag) // It's adjacent, is the user, or is on the user's person
		if(target in user.contents) // can't shoot stuff inside us.
			return
		if(!ismob(target) || user.combat_mode) // melee attack
			return
		if(target == user && user.zone_selected != BODY_ZONE_PRECISE_MOUTH) // so we can't shoot ourselves (unless mouth selected)
			return
		if(iscarbon(target))
			var/mob/living/carbon/carbon_target = target
			for(var/i in carbon_target.all_wounds)
				var/datum/wound/target_wound = i
				if(target_wound.try_treating(src, user))
					return // another coward cured!

	if(istype(user))// Check if the user can use the gun, if the user isn't alive(turrets) assume it can.
		var/mob/living/living_user = user
		if(!can_trigger_gun(living_user))
			return
	if(flag)
		if(user.zone_selected == BODY_ZONE_PRECISE_MOUTH)
			handle_suicide(user, target, params)
			return

	if(!can_shoot()) // Just because you can pull the trigger doesn't mean it can shoot.
		shoot_with_empty_chamber(user)
		return

	if(check_botched(user))
		return

	var/obj/item/bodypart/other_hand = user.has_hand_for_held_index(user.get_inactive_hand_index()) // returns non-disabled inactive hands
	if(weapon_weight == WEAPON_HEAVY && (user.get_inactive_held_item() || !other_hand))
		balloon_alert(user, "need two hands!")
		return
	// DUAL (or more!) WIELDING
	var/bonus_spread = 0
	var/loop_counter = 0
	if(ishuman(user) && user.combat_mode)
		var/mob/living/carbon/human/human_user = user
		for(var/obj/item/gun/held_gun in human_user.held_items)
			if(held_gun == src || held_gun.weapon_weight >= WEAPON_MEDIUM)
				continue
			else if(held_gun.can_trigger_gun(user))
				bonus_spread += dual_wield_spread
				loop_counter++
				addtimer(CALLBACK(held_gun, /obj/item/gun.proc/process_fire, target, user, TRUE, params, null, bonus_spread), loop_counter)

	return process_fire(target, user, TRUE, params, null, bonus_spread)

/obj/item/gun/proc/check_botched(mob/living/user, params)
	if(clumsy_check)
		if(istype(user))
			if(HAS_TRAIT(user, TRAIT_CLUMSY) && prob(40))
				to_chat(user, span_userdanger("You shoot yourself in the foot with [src]!"))
				var/shot_leg = pick(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
				process_fire(user, user, FALSE, params, shot_leg)
				SEND_SIGNAL(user, COMSIG_MOB_CLUMSY_SHOOT_FOOT)
				if(!tk_firing(user) && !HAS_TRAIT(src, TRAIT_NODROP))
					user.dropItemToGround(src, TRUE)
				return TRUE

/obj/item/gun/can_trigger_gun(mob/living/user)
	. = ..()
	if(!handle_pins(user))
		return FALSE
	if(has_gun_safety && safety)
		balloon_alert(user, "safety on!")
		return FALSE

/obj/item/gun/proc/toggle_safety(mob/user, override)
	if(!has_gun_safety)
		return
	if(override)
		if(override == "off")
			safety = FALSE
		else
			safety = TRUE
	else
		safety = !safety
	toggle_safety_action.button_icon_state = "safety_[safety ? "on" : "off"]"
	toggle_safety_action.UpdateButtons()
	playsound(src, 'sound/weapons/empty.ogg', 100, TRUE)
	user.visible_message(
		span_notice("[user] toggles [src]'s safety [safety ? "<font color='#00ff15'>ON</font>" : "<font color='#ff0000'>OFF</font>"]."),
		span_notice("You toggle [src]'s safety [safety ? "<font color='#00ff15'>ON</font>" : "<font color='#ff0000'>OFF</font>"].")
	)
	SEND_SIGNAL(src, COMSIG_UPDATE_AMMO_HUD)

/obj/item/gun/proc/handle_pins(mob/living/user)
	if(pinless)
		return TRUE
	if(pin)
		if(pin.pin_auth(user) || (pin.obj_flags & EMAGGED))
			return TRUE
		else
			pin.auth_fail(user)
			return FALSE
	else
		balloon_alert(user, "no firing pin!")
	return FALSE

/obj/item/gun/proc/recharge_newshot()
	return

/obj/item/gun/proc/process_burst(mob/living/user, atom/target, message = TRUE, params = null, zone_override = "", sprd = 0, randomized_gun_spread = 0, randomized_bonus_spread = 0, rand_spr = 0, iteration = 0)
	if(!user || !firing_burst)
		firing_burst = FALSE
		return FALSE
	if(!issilicon(user))
		if(iteration > 1 && !(user.is_holding(src))) // for burst firing
			firing_burst = FALSE
			return FALSE
	if(chambered?.loaded_projectile)
		if(HAS_TRAIT(user, TRAIT_PACIFISM)) // If the user has the pacifist trait, then they won't be able to fire [src] if the round chambered inside of [src] is lethal.
			if(chambered.harmful) // Is the bullet chambered harmful?
				balloon_alert(user, "lethally chambered!")
				return
		if(randomspread)
			sprd = round((rand(0, 1) - 0.5) * DUALWIELD_PENALTY_EXTRA_MULTIPLIER * (randomized_gun_spread + randomized_bonus_spread))
		else // Smart spread
			sprd = round((((rand_spr/burst_size) * iteration) - (0.5 + (rand_spr * 0.25))) * (randomized_gun_spread + randomized_bonus_spread))
		before_firing(target, user)
		if(!chambered.fire_casing(target, user, params, , suppressed, zone_override, sprd, src))
			shoot_with_empty_chamber(user)
			firing_burst = FALSE
			return FALSE
		else
			if(get_dist(user, target) <= 1) // Making sure whether the target is in vicinity for the pointblank shot
				shoot_live_shot(user, 1, target, message)
			else
				shoot_live_shot(user, 0, target, message)
			if (iteration >= burst_size)
				firing_burst = FALSE
	else
		shoot_with_empty_chamber(user)
		firing_burst = FALSE
		return FALSE
	process_chamber()
	update_appearance()
	SEND_SIGNAL(src, COMSIG_UPDATE_AMMO_HUD)
	return TRUE

/obj/item/gun/proc/process_fire(atom/target, mob/living/user, message = TRUE, params = null, zone_override = "", bonus_spread = 0)
	if(user)
		SEND_SIGNAL(user, COMSIG_MOB_FIRED_GUN, user, target, params, zone_override)

	SEND_SIGNAL(src, COMSIG_GUN_FIRED, user, target, params, zone_override)

	add_fingerprint(user)

	if(semicd)
		return

	// Vary by at least this much
	var/base_bonus_spread = 0
	var/sprd = 0
	var/randomized_gun_spread = 0
	var/rand_spr = rand()
	if(user && HAS_TRAIT(user, TRAIT_POOR_AIM)) // Nice job hotshot
		bonus_spread += 35
		base_bonus_spread += 10

	if(spread)
		randomized_gun_spread =	rand(0, spread)
	var/randomized_bonus_spread = rand(base_bonus_spread, bonus_spread)

	if(burst_size > 1)
		firing_burst = TRUE
		for(var/i = 1 to burst_size)
			addtimer(CALLBACK(src, .proc/process_burst, user, target, message, params, zone_override, sprd, randomized_gun_spread, randomized_bonus_spread, rand_spr, i), fire_delay * (i - 1))
	else
		if(chambered)
			if(HAS_TRAIT(user, TRAIT_PACIFISM)) // If the user has the pacifist trait, then they won't be able to fire [src] if the round chambered inside of [src] is lethal.
				if(chambered.harmful) // Is the bullet chambered harmful?
					balloon_alert(user, "lethally chambered!")
					return
			sprd = round((rand(0, 1) - 0.5) * DUALWIELD_PENALTY_EXTRA_MULTIPLIER * (randomized_gun_spread + randomized_bonus_spread))
			before_firing(target, user)
			if(!chambered.fire_casing(target, user, params, , suppressed, zone_override, sprd, src))
				shoot_with_empty_chamber(user)
				return
			else
				if(get_dist(user, target) <= 1) // Making sure whether the target is in vicinity for the pointblank shot
					shoot_live_shot(user, 1, target, message)
				else
					shoot_live_shot(user, 0, target, message)
		else
			shoot_with_empty_chamber(user)
			return
		process_chamber()
		update_appearance()
		semicd = TRUE
		addtimer(CALLBACK(src, .proc/reset_semicd), fire_delay)

	if(user)
		user.update_inv_hands()
	SSblackbox.record_feedback("tally", "gun_fired", 1, type)

	SEND_SIGNAL(src, COMSIG_UPDATE_AMMO_HUD)

	return TRUE

/obj/item/gun/proc/reset_semicd()
	semicd = FALSE

/obj/item/gun/attack(mob/target, mob/living/user)
	if(user.combat_mode) // Flogging
		if(bayonet)
			target.attackby(bayonet, user)
			return
		else
			return ..()
	return

/obj/item/gun/attack_atom(obj/target, mob/living/user, params)
	if(user.combat_mode)
		if(bayonet)
			target.attackby(bayonet, user)
			return
	return ..()

/obj/item/gun/attackby(obj/item/attacking_item, mob/living/user, params)
	if(user.combat_mode)
		return ..()
	else if(istype(attacking_item, /obj/item/knife))
		var/obj/item/knife/attaching_knife = attacking_item
		if(!can_bayonet || !attaching_knife.bayonet || bayonet) // ensure the gun has an attachment point available, and that the knife is compatible with it.
			return ..()
		if(!user.transferItemToLoc(attacking_item, src))
			return
		balloon_alert(user, "[attaching_knife] attached")
		bayonet = attaching_knife
		update_appearance()

	else
		return ..()

/obj/item/gun/screwdriver_act(mob/living/user, obj/item/tool)
	. = ..()
	if(.)
		return
	if(!user.canUseTopic(src, BE_CLOSE, FALSE, NO_TK))
		return
	if(bayonet && can_bayonet) //if it has a bayonet, and the bayonet can be removed
		return remove_bayonet(user, tool)

	else if(pin && user.is_holding(src))
		if(!pin.can_remove)
			balloon_alert(user, "pin can't be removed!")
			return
		user.visible_message(span_warning("[user] attempts to remove [pin] from [src] with [tool]."),
		span_notice("You attempt to remove [pin] from [src]. (It will take [DisplayTimeText(FIRING_PIN_REMOVAL_DELAY)].)"), null, 3)
		if(tool.use_tool(src, user, FIRING_PIN_REMOVAL_DELAY, volume = 50))
			if(!pin) // check to see if the pin is still there, or we can spam messages by clicking multiple times during the tool delay
				return
			user.visible_message(span_notice("[pin] is pried out of [src] by [user], destroying the pin in the process."),
								span_warning("You pry [pin] out with [tool], destroying the pin in the process."), null, 3)
			QDEL_NULL(pin)
			return TRUE

/obj/item/gun/welder_act(mob/living/user, obj/item/tool)
	. = ..()
	if(.)
		return
	if(!pin.can_remove)
		balloon_alert(user, "pin can't be removed!")
		return
	if(!user.canUseTopic(src, BE_CLOSE, FALSE, NO_TK))
		return
	if(pin && user.is_holding(src))
		user.visible_message(span_warning("[user] attempts to remove [pin] from [src] with [tool]."),
		span_notice("You attempt to remove [pin] from [src]. (It will take [DisplayTimeText(FIRING_PIN_REMOVAL_DELAY)].)"), null, 3)
		if(tool.use_tool(src, user, FIRING_PIN_REMOVAL_DELAY, 5, volume = 50))
			if(!pin) // check to see if the pin is still there, or we can spam messages by clicking multiple times during the tool delay
				return
			user.visible_message(span_notice("[pin] is spliced out of [src] by [user], melting part of the pin in the process."),
								span_warning("You splice [pin] out of [src] with [tool], melting part of the pin in the process."), null, 3)
			QDEL_NULL(pin)
			return TRUE

/obj/item/gun/wirecutter_act(mob/living/user, obj/item/tool)
	. = ..()
	if(.)
		return
	if(!user.canUseTopic(src, BE_CLOSE, FALSE, NO_TK))
		return
	if(!pin.can_remove)
		balloon_alert(user, "pin can't be removed!")
		return
	if(pin && user.is_holding(src))
		user.visible_message(span_warning("[user] attempts to remove [pin] from [src] with [tool]."),
		span_notice("You attempt to remove [pin] from [src]. (It will take [DisplayTimeText(FIRING_PIN_REMOVAL_DELAY)].)"), null, 3)
		if(tool.use_tool(src, user, FIRING_PIN_REMOVAL_DELAY, volume = 50))
			if(!pin) // check to see if the pin is still there, or we can spam messages by clicking multiple times during the tool delay
				return
			user.visible_message(span_notice("[pin] is ripped out of [src] by [user], mangling the pin in the process."),
								span_warning("You rip [pin] out of [src] with [tool], mangling the pin in the process."), null, 3)
			QDEL_NULL(pin)
			return TRUE

/obj/item/gun/proc/remove_bayonet(mob/living/user, obj/item/tool_item)
	tool_item?.play_tool_sound(src)
	to_chat(user, span_notice("You unfix [bayonet] from [src]."))
	bayonet.forceMove(drop_location())

	if(Adjacent(user) && !issilicon(user))
		user.put_in_hands(bayonet)

	return clear_bayonet()

/obj/item/gun/proc/clear_bayonet()
	if(!bayonet)
		return
	bayonet = null
	update_appearance()
	return TRUE

/obj/item/gun/update_overlays()
	. = ..()

	if(bayonet)
		var/mutable_appearance/knife_overlay
		var/state = bayonet_state
		if(bayonet.icon_state in icon_states(bayonet_icon)) // Snowflake state?
			state = bayonet.icon_state
		knife_overlay = mutable_appearance(bayonet_icon, state)
		knife_overlay.pixel_x = knife_x_offset
		knife_overlay.pixel_y = knife_y_offset
		. += knife_overlay

/obj/item/gun/proc/handle_suicide(mob/living/carbon/human/user, mob/living/carbon/human/target, params, bypass_timer)
	if(!ishuman(user) || !ishuman(target))
		return

	if(semicd)
		return

	if(user == target)
		target.visible_message(span_warning("[user] sticks [src] in [user.p_their()] mouth, ready to pull the trigger..."), \
			span_userdanger("You stick [src] in your mouth, ready to pull the trigger..."))
	else
		target.visible_message(span_warning("[user] points [src] at [target]'s head, ready to pull the trigger..."), \
			span_userdanger("[user] points [src] at your head, ready to pull the trigger..."))

	semicd = TRUE

	if(!bypass_timer && (!do_mob(user, target, 120) || user.zone_selected != BODY_ZONE_PRECISE_MOUTH))
		if(user)
			if(user == target)
				user.visible_message(span_notice("[user] decided not to shoot."))
			else if(target?.Adjacent(user))
				target.visible_message(span_notice("[user] has decided to spare [target]"), span_notice("[user] has decided to spare your life!"))
		semicd = FALSE
		return

	semicd = FALSE

	target.visible_message(span_warning("[user] pulls the trigger!"), span_userdanger("[(user == target) ? "You pull" : "[user] pulls"] the trigger!"))

	if(chambered?.loaded_projectile)
		chambered.loaded_projectile.damage *= 5
		if(chambered.loaded_projectile.wound_bonus != CANT_WOUND)
			chambered.loaded_projectile.wound_bonus += 5 // much more dramatic on multiple pellet'd projectiles really

	var/fired = process_fire(target, user, TRUE, params, BODY_ZONE_HEAD)
	if(!fired && chambered?.loaded_projectile)
		chambered.loaded_projectile.damage /= 5
		if(chambered.loaded_projectile.wound_bonus != CANT_WOUND)
			chambered.loaded_projectile.wound_bonus -= 5

/obj/item/gun/proc/unlock() // used in summon guns and as a convience for admins
	if(pin)
		qdel(pin)
	pin = new /obj/item/firing_pin

// Happens before the actual projectile creation
/obj/item/gun/proc/before_firing(atom/target, mob/user)
	return

/obj/item/gun/emag_act(mob/user, obj/item/card/emag/emag_card)
	. = ..()
	if(!pin.can_remove)
		balloon_alert(user, "firing pin shorted!")
		pin.can_remove = TRUE
		if(!(pin.obj_flags & EMAGGED))
			pin.obj_flags |= EMAGGED

#undef FIRING_PIN_REMOVAL_DELAY
#undef DUALWIELD_PENALTY_EXTRA_MULTIPLIER
