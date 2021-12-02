/obj/item/airlock_painter
	name = "airlock painter"
	desc = "An advanced autopainter preprogrammed with several paintjobs for airlocks. Use it on an airlock during or after construction to change the paintjob."
	icon = 'icons/obj/objects.dmi'
	icon_state = "paint sprayer"
	inhand_icon_state = "paint sprayer"
	worn_icon_state = "painter"
	w_class = WEIGHT_CLASS_SMALL

	custom_materials = list(/datum/material/iron = 50, /datum/material/glass = 50)

	flags_1 = CONDUCT_1
	item_flags = NOBLUDGEON
	slot_flags = ITEM_SLOT_BELT
	usesound = 'sound/effects/spray2.ogg'

	/// Associate list of all paint jobs the airlock painter can apply. The key is the name of the airlock the user will see. The value is the type path of the airlock
	var/list/available_paint_jobs = list(
		"Public" = /obj/machinery/door/airlock/public,
		"Engineering" = /obj/machinery/door/airlock/engineering,
		"Atmospherics" = /obj/machinery/door/airlock/atmos,
		"Security" = /obj/machinery/door/airlock/security,
		"Command" = /obj/machinery/door/airlock/command,
		"Medical" = /obj/machinery/door/airlock/medical,
		"Research" = /obj/machinery/door/airlock/research,
		"Freezer" = /obj/machinery/door/airlock/freezer,
		"Science" = /obj/machinery/door/airlock/science,
		"Mining" = /obj/machinery/door/airlock/mining,
		"Maintenance" = /obj/machinery/door/airlock/maintenance,
		"External" = /obj/machinery/door/airlock/external,
		"External Maintenance"= /obj/machinery/door/airlock/maintenance/external,
		"Virology" = /obj/machinery/door/airlock/virology,
//SKYRAT EDIT ADDITION//
		"Standard" = /obj/machinery/door/airlock,
		"Corporate" = /obj/machinery/door/airlock/corporate,
		"Bathroom" = /obj/machinery/door/airlock/bathroom,
		"Psychologist" = /obj/machinery/door/airlock/psych,
		"Asylum" = /obj/machinery/door/airlock/asylum,
		"Captain" = /obj/machinery/door/airlock/captain,
		"Head of Personnel" = /obj/machinery/door/airlock/hop,
		"Head of Security" = /obj/machinery/door/airlock/hos,
		"Chief Medical Officer" = /obj/machinery/door/airlock/cmo,
		"Chief Engineer" = /obj/machinery/door/airlock/ce,
		"Research Director" = /obj/machinery/door/airlock/rd,
		"Quartermaster" = /obj/machinery/door/airlock/qm
//SKYRAT EDIT ADDITION END
	)

	power_use_amount = POWER_CELL_USE_HIGH
	var/cell_override

/obj/item/airlock_painter/ComponentInitialize()
	. = ..()
	AddComponent(/datum/component/cell, cell_override)

//This proc doesn't just check if the painter can be used, but also uses it.
//Only call this if you are certain that the painter will be used right after this check!
/obj/item/airlock_painter/proc/use_paint(mob/user)
	if(!(item_use_power(power_use_amount, user) & COMPONENT_POWER_SUCCESS))
		return FALSE
	playsound(src.loc, 'sound/effects/spray2.ogg', 50, TRUE)
	return TRUE


//This proc only checks if the painter can be used.
//Call this if you don't want the painter to be used right after this check, for example
//because you're expecting user input.
/obj/item/airlock_painter/proc/can_use(mob/user)
	if(!(item_use_power(power_use_amount, user) & COMPONENT_POWER_SUCCESS))
		return FALSE
	return TRUE

/obj/item/airlock_painter/suicide_act(mob/user)
	var/obj/item/organ/lungs/mob_lungs = user.getorganslot(ORGAN_SLOT_LUNGS)

	if(can_use(user) && mob_lungs)
		user.visible_message(span_suicide("[user] is inhaling toner from [src]! It looks like [user.p_theyre()] trying to commit suicide!"))
		use(user)

		// Once you've inhaled the toner, you throw up your lungs
		// and then die.

		// Find out if there is an open turf in front of us,
		// and if not, pick the turf we are standing on.
		var/turf/target_turf = get_step(get_turf(src), user.dir)
		if(!isopenturf(target_turf))
			target_turf = get_turf(src)

		// they managed to lose their lungs between then and
		// now. Good job.
		if(!mob_lungs)
			return OXYLOSS

		mob_lungs.Remove(user)

		// make some colorful reagent, and apply it to the lungs
		mob_lungs.create_reagents(10)
		mob_lungs.reagents.add_reagent(/datum/reagent/colorful_reagent, 10)
		mob_lungs.reagents.expose(mob_lungs, TOUCH, 1)

		// TODO maybe add some colorful vomit?

		user.visible_message(span_suicide("[user] vomits out [user.p_their()] [mob_lungs]!"))
		playsound(user.loc, 'sound/effects/splat.ogg', 50, TRUE)

		mob_lungs.forceMove(target_turf)

		return (TOXLOSS|OXYLOSS)
	else if(can_use(user) && !mob_lungs)
		user.visible_message(span_suicide("[user] is spraying toner on [user.p_them()]self from [src]! It looks like [user.p_theyre()] trying to commit suicide."))
		user.reagents.add_reagent(/datum/reagent/colorful_reagent, 1)
		user.reagents.expose(user, TOUCH, 1)
		return TOXLOSS

	else
		user.visible_message(span_suicide("[user] is trying to inhale toner from [src]! It might be a suicide attempt if [src] had any toner."))
		return SHAME

/obj/item/airlock_painter/decal
	name = "decal painter"
	desc = "An airlock painter, reprogramed to use a different style of paint in order to apply decals for floor tiles as well, in addition to repainting doors. Decals break when the floor tiles are removed. Alt-Click to change design."
	icon = 'icons/obj/objects.dmi'
	icon_state = "decal_sprayer"
	inhand_icon_state = "decalsprayer"
	custom_materials = list(/datum/material/iron = 50, /datum/material/glass = 50)
	var/stored_dir = 2
	var/stored_color = ""
	var/stored_decal = "warningline"
	var/stored_decal_total = "warningline"
	var/color_list = list("", "red", "white")
	var/dir_list = list(1, 2, 4, 8)
	var/decal_list = list(list("Warning Line", "warningline"),
			list("Warning Line Corner", "warninglinecorner"),
			list("Caution Label", "caution"),
			list("Directional Arrows", "arrows"),
			list("Stand Clear Label", "stand_clear"),
			list("Box", "box"),
			list("Box Corner", "box_corners"),
			list("Delivery Marker", "delivery"),
			list("Warning Box", "warn_full"))
	cell_override = /obj/item/stock_parts/cell/upgraded/plus

/obj/item/airlock_painter/decal/afterattack(atom/target, mob/user, proximity)
	. = ..()
	var/turf/open/floor/target_floor = target
	if(!proximity)
		to_chat(user, span_notice("You need to get closer!"))
		return
	if(use_paint(user) && isturf(target_floor))
		target_floor.AddElement(/datum/element/decal, 'icons/turf/decals.dmi', stored_decal_total, stored_dir, null, null, alpha, color, null, CLEAN_TYPE_PAINT, null)

/obj/item/airlock_painter/decal/AltClick(mob/user)
	. = ..()
	ui_interact(user)

/obj/item/airlock_painter/decal/proc/update_decal_path()
	var/yellow_fix = "" //This will have to do until someone refactor's markings.dm
	if (stored_color)
		yellow_fix = "_"
	stored_decal_total = "[stored_decal][yellow_fix][stored_color]"
	return

/obj/item/airlock_painter/decal/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "DecalPainter", name)
		ui.open()

/obj/item/airlock_painter/decal/ui_data(mob/user)
	var/list/data = list()
	data["decal_direction"] = stored_dir
	data["decal_color"] = stored_color
	data["decal_style"] = stored_decal
	data["decal_list"] = list()
	data["color_list"] = list()
	data["dir_list"] = list()

	for(var/i in decal_list)
		data["decal_list"] += list(list(
			"name" = i[1],
			"decal" = i[2]
		))
	for(var/j in color_list)
		data["color_list"] += list(list(
			"colors" = j
		))
	for(var/k in dir_list)
		data["dir_list"] += list(list(
			"dirs" = k
		))
	return data

/obj/item/airlock_painter/decal/ui_act(action, list/params)
	. = ..()
	if(.)
		return

	switch(action)
		//Lists of decals and designs
		if("select decal")
			var/selected_decal = params["decals"]
			stored_decal = selected_decal
		if("select color")
			var/selected_color = params["colors"]
			stored_color = selected_color
		if("selected direction")
			var/selected_direction = text2num(params["dirs"])
			stored_dir = selected_direction
	update_decal_path()
	. = TRUE

/obj/item/airlock_painter/decal/debug
	name = "extreme decal painter"
	icon_state = "decal_sprayer_ex"
	cell_override = /obj/item/stock_parts/cell/infinite
