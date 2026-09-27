class_name VoyageUI
extends RefCounted
## Star chart and commission board share the game's scale-aware drawing vocabulary.


func rebuild(ui: GameUI) -> void:
	var game: Node = ui.game
	var voyage: VoyageController = game.voyage
	var model: Expedition = game.expedition
	if game.mode == "galaxy":
		for i in StarNetwork.COUNT:
			var p := star_position(i)
			ui.button_at(
				"%02d" % (i + 1),
				Rect2(p - Vector2(26, 26), Vector2(52, 52)),
				voyage.select_system.bind(i),
				i == voyage.selected_system
			)
		var route := model.network.route(model.network.current, voyage.selected_system)
		var next := route[0] if not route.is_empty() else -1
		ui.button_at(
			"JUMP TO " + StarNetwork.NAMES[next].to_upper() if next >= 0 else "CURRENT SYSTEM",
			Rect2(1130, 735, 390, 58),
			func():
				if next >= 0:
					voyage.selected_system = next
					voyage.begin_jump(),
			true,
			next < 0 or not voyage.jump_blocker(next).is_empty()
		)
		ui.button_at(
			"SET COURSE TO TRANSIT RELAY",
			Rect2(1130, 809, 390, 48),
			voyage.approach_relay,
			false,
			voyage.return_mode == "dock"
		)
		ui.button_at("RETURN / J / ESC", Rect2(1130, 879, 390, 50), voyage.close)
	elif game.mode == "jobs":
		if voyage.return_mode == "dock":
			ui.button_at(
				"AVAILABLE OFFERS" if voyage.show_active else "ACTIVE CONTRACTS",
				Rect2(1040, 128, 238, 43),
				voyage.toggle_job_list
			)
		ui.button_at("STAR NETWORK / J", Rect2(1296, 128, 238, 43), voyage.open_chart)
		var jobs: Array[Dictionary] = (
			model.contracts.active_jobs(model.network)
			if voyage.show_active
			else model.contracts.office_jobs(model.network, model.network.current)
		)
		for i in jobs.size():
			var job := jobs[i]
			var origin := card_origin(i)
			var action := origin + Vector2(30, 228)
			if job.status == StationContracts.ACTIVE:
				var can_claim: bool = (
					voyage.return_mode == "dock"
					and job.office == model.network.current
					and model.contracts.ready(job, model)
				)
				ui.button_at(
					(
						"DELIVER / +%d CR" % job.reward
						if can_claim
						else (
							"TRACKED"
							if model.contracts.tracked_job(model.network).get("id") == job.id
							else "TRACK CONTRACT"
						)
					),
					Rect2(action, Vector2(300, 43)),
					voyage.claim_job.bind(job.id) if can_claim else voyage.track_job.bind(job.id),
					can_claim
				)
				ui.button_at(
					"ABANDON",
					Rect2(action + Vector2(319, 0), Vector2(140, 43)),
					voyage.abandon_job.bind(job.id)
				)
			else:
				var can_accept := (
					voyage.return_mode == "dock" and model.contracts.can_accept(job, model)
				)
				var label := (
					"ACCEPT COMMISSION"
					if can_accept
					else (
						"COMPLETED"
						if job.status == StationContracts.PAID
						else ("CLOSED" if job.status == StationContracts.CLOSED else "UNAVAILABLE")
					)
				)
				ui.button_at(
					label,
					Rect2(action, Vector2(459, 43)),
					voyage.accept_job.bind(job.id),
					can_accept,
					not can_accept
				)
		if voyage.return_mode == "dock" and not voyage.show_active:
			ui.button_at(
				"REQUEST NEW OFFERS",
				Rect2(73, 906, 300, 48),
				voyage.refresh_board,
				false,
				model.contracts.boards[model.network.current].states.has(StationContracts.ACTIVE)
			)
		ui.button_at("RETURN / L / ESC", Rect2(1240, 906, 290, 48), voyage.close)
	ui._layout_buttons()


func star_position(index: int) -> Vector2:
	return Vector2(142, 330) + StarNetwork.COORDS[index] * Vector2(825, 440)


func card_origin(index: int) -> Vector2:
	return Vector2(73 + (index % 2) * 744, 242 + (index / 2) * 322)


func draw(ui: GameUI) -> void:
	match ui.game.mode:
		"galaxy":
			draw_chart(ui)
		"jobs":
			draw_jobs(ui)
		"jump":
			draw_jump(ui)


func draw_chart(ui: GameUI) -> void:
	var model: Expedition = ui.game.expedition
	var network := model.network
	var voyage: VoyageController = ui.game.voyage
	var selected := voyage.selected_system
	ui.draw_rect(Rect2(0, 0, 1600, 1000), Color("07101b"))
	# Quiet deterministic star field; the graph remains the strongest visual element.
	for i in 110:
		var p := Vector2(fposmod(i * 617.31, 1070), fposmod(i * 293.73, 780) + 150)
		ui.draw_circle(p, 0.8 if i % 5 else 1.4, Color(ui.MUTED, 0.28))
	ui.topbar("INTERSTELLAR NAVIGATION")
	ui.ink("The frontier is open.", Vector2(73, 177), 49, ui.WHITE, ui.display)
	ui.ink(
		"Choose a destination. Each jump follows one connected lane.",
		Vector2(76, 214),
		19,
		ui.MUTED
	)
	var route := network.route(network.current, selected)
	var course: Array[int] = [network.current]
	course.append_array(route)
	for edge in StarNetwork.LINKS:
		var planned := false
		for i in range(course.size() - 1):
			if (
				(course[i] == edge[0] and course[i + 1] == edge[1])
				or (course[i] == edge[1] and course[i + 1] == edge[0])
			):
				planned = true
		var adjacent: bool = edge.has(network.current)
		ui.draw_line(
			star_position(edge[0]),
			star_position(edge[1]),
			Color(ui.AMBER, 0.85) if planned else Color(ui.CYAN, 0.33 if adjacent else 0.12),
			3 if planned else 1.5,
			true
		)
	for i in StarNetwork.COUNT:
		var p := star_position(i)
		var color: Color = StarNetwork.COLORS[i]
		ui.draw_arc(
			p,
			39 if i == network.current else 34,
			0,
			TAU,
			48,
			color if i == network.current else Color(color, 0.3),
			2 if i == network.current else 1,
			true
		)
		ui.ink(StarNetwork.NAMES[i].to_upper(), p + Vector2(-69, 56), 17, color, ui.bold)
		ui.ink(
			(
				"YOU ARE HERE"
				if i == network.current
				else ("VISITED" if network.visited[i] else "UNCHARTED")
			),
			p + Vector2(-48, 77),
			12,
			ui.WHITE if i == network.current else ui.MUTED
		)
	ui.panel(Rect2(1092, 99, 508, 901))
	ui.ink("DESTINATION / %02d" % (selected + 1), Vector2(1130, 147), 13, ui.AMBER)
	ui.ink(StarNetwork.NAMES[selected], Vector2(1130, 194), 43, ui.WHITE, ui.display)
	ui.ink(StarNetwork.BIOMES[selected], Vector2(1132, 226), 18, StarNetwork.COLORS[selected])
	ui.line(Vector2(1130, 254), Vector2(1520, 254))
	ui.ink("THREAT ASSESSMENT", Vector2(1130, 289), 13, ui.MUTED)
	for i in 3:
		ui.draw_rect(
			Rect2(1130 + i * 42, 307, 30, 5),
			MeshKit.RED if i < network.risk(selected) else Color("21313e")
		)
	ui.ink(
		["Protected frontier", "Light patrols", "Contested lanes", "Heavy resistance"][network.risk(
			selected
		)],
		Vector2(1130, 346),
		22,
		ui.WHITE
	)
	var types: Dictionary = {}
	var surviving := 0
	for spec in network.encounter(selected):
		if model.consumed.has(spec.id):
			continue
		surviving += 1
		types[spec.role] = true
	ui.ink(
		"%d hostiles / %d ion fields" % [surviving, 0 if selected == 0 else network.risk(selected)],
		Vector2(1130, 378),
		18,
		ui.MUTED
	)
	ui.ink(
		(
			" + ".join(types.keys()).capitalize()
			if not types.is_empty()
			else "No frontier patrol signals"
		),
		Vector2(1130, 409),
		17,
		ui.CYAN
	)
	ui.ink("STATION SERVICES", Vector2(1130, 462), 13, ui.MUTED)
	ui.ink(StarNetwork.PORTS[selected], Vector2(1130, 498), 25, ui.WHITE, ui.bold)
	ui.ink("Contracts · repairs · supplies · upgrades", Vector2(1130, 530), 17, ui.MUTED)
	ui.ink(
		"ROUTE / %d JUMP%s" % [route.size(), "" if route.size() == 1 else "S"],
		Vector2(1130, 580),
		13,
		ui.AMBER
	)
	var next := route[0] if not route.is_empty() else -1
	var cost := network.jump_cost(next) if next >= 0 else 0
	ui.ink(
		"Next leg: %s" % StarNetwork.NAMES[next] if next >= 0 else "Currently in this system",
		Vector2(1130, 614),
		20,
		ui.WHITE
	)
	ui.ink(
		"Battery %d%%  /  jump uses %d%%" % [model.interior_state.resources.power, cost],
		Vector2(1130, 646),
		17,
		ui.CYAN
	)
	var blocker := voyage.jump_blocker(next) if next >= 0 else ""
	paragraph(
		ui,
		blocker if not blocker.is_empty() else "Fleet secured. Transit corridor available.",
		Vector2(1130, 683),
		48,
		17,
		ui.AMBER if not blocker.is_empty() else ui.CYAN
	)
	ui.ink("CAPTAIN'S LOG", Vector2(75, 872), 13, ui.AMBER)
	ui.ink(
		(
			"%d / 9 systems visited    ·    %d transits    ·    %d commissions completed"
			% [network.visited.count(true), network.jumps, model.contracts.completed]
		),
		Vector2(75, 910),
		20,
		ui.WHITE
	)
	ui.ink(
		"Travel consumes battery and 20 seconds of crew supplies. Engineering recharges the drive.",
		Vector2(75, 945),
		16,
		ui.MUTED
	)


func draw_jobs(ui: GameUI) -> void:
	var model: Expedition = ui.game.expedition
	var voyage: VoyageController = ui.game.voyage
	ui.draw_rect(Rect2(0, 0, 1600, 1000), Color("08111a"))
	ui.topbar("STATION COMMISSIONS" if voyage.return_mode == "dock" else "CAPTAIN'S CONTRACT LOG")
	ui.ink("Work worth the journey.", Vector2(73, 167), 46, ui.WHITE, ui.display)
	ui.ink(
		(
			(StarNetwork.PORTS[model.network.current] + " / ")
			if not voyage.show_active
			else "ALL ISSUING STATIONS / "
		),
		Vector2(75, 205),
		17,
		ui.CYAN
	)
	ui.ink(
		(
			"%d / 3 active    ·    %d completed    ·    Return to the issuing port for payment"
			% [model.contracts.active_jobs(model.network).size(), model.contracts.completed]
		),
		Vector2(476, 205),
		16,
		ui.MUTED
	)
	var jobs: Array[Dictionary] = (
		model.contracts.active_jobs(model.network)
		if voyage.show_active
		else model.contracts.office_jobs(model.network, model.network.current)
	)
	if jobs.is_empty():
		ui.ink("Your log is clear.", Vector2(110, 354), 38, ui.WHITE, ui.display)
		ui.ink(
			"Dock at any station, open Station Commissions, and accept up to three jobs.",
			Vector2(112, 404),
			21,
			ui.MUTED
		)
	for i in jobs.size():
		var job := jobs[i]
		var p := card_origin(i)
		ui.panel(Rect2(p, Vector2(714, 298)), 1)
		ui.draw_rect(
			Rect2(p, Vector2(3, 298)),
			ui.CYAN if job.status == StationContracts.ACTIVE else ui.AMBER
		)
		ui.ink(
			[
				"PROCUREMENT / DRONE MINING",
				"RECOVERY / CREWED SALVAGE",
				"SECURITY / SQUADRON BOUNTY",
				"EXPLORATION / RELAY SURVEY"
			][job.slot],
			p + Vector2(30, 34),
			13,
			ui.CYAN
		)
		ui.ink(job.title, p + Vector2(30, 78), 34, ui.WHITE, ui.display)
		ui.ink("+%d CR" % job.reward, p + Vector2(562, 75), 25, ui.AMBER, ui.display)
		var description: String = ""
		match job.kind:
			"ore":
				description = (
					"Deliver %d t of ferrite. Scout %s; ore from any field qualifies."
					% [job.amount, StarNetwork.NAMES[job.target]]
				)
			"salvage":
				description = (
					"Tow %d freight containers into your bay. Search %s or another wreck field."
					% [job.amount / 12, StarNetwork.NAMES[job.target]]
				)
			"bounty":
				description = (
					"Eliminate the %d-ship patrol in %s. Each destroyed ship stays cleared."
					% [job.amount, StarNetwork.NAMES[job.target]]
				)
			"survey":
				description = (
					"Reach the lost relay in %s. Break hostile contact and hold E to decode."
					% StarNetwork.NAMES[job.target]
				)
		paragraph(ui, description, p + Vector2(30, 112), 73, 18, ui.WHITE)
		ui.ink("ISSUER  " + StarNetwork.PORTS[job.office], p + Vector2(30, 176), 15, ui.MUTED)
		var status: String = model.contracts.summary(job, model)
		if job.status == StationContracts.PAID:
			status = "Payment received. This commission is closed."
		elif job.status == StationContracts.CLOSED:
			status = "Commission abandoned."
		elif job.status == StationContracts.OFFER and not model.contracts.can_accept(job, model):
			status = model.contracts.unavailable_reason(job, model)
		elif job.status == StationContracts.ACTIVE and model.contracts.ready(job, model):
			status = "READY / Deliver at " + StarNetwork.PORTS[job.office]
		ui.ink(
			status,
			p + Vector2(30, 207),
			16,
			ui.CYAN if job.status == StationContracts.ACTIVE else ui.AMBER
		)
	ui.ink(
		"Supply deliveries consume physical cargo. Selling it first removes delivery progress.",
		Vector2(401, 937),
		16,
		ui.MUTED
	)
	if not voyage.show_active:
		ui.ink(
			"New offers require this office to have no active commissions. No fee.",
			Vector2(74, 981),
			15,
			ui.MUTED
		)


func paragraph(
	ui: GameUI, text: String, origin: Vector2, width: int, font_size: int, color: Color
) -> void:
	var line_text := ""
	var y := 0
	for word in text.split(" "):
		if line_text.length() + word.length() + 1 > width:
			ui.ink(line_text, origin + Vector2(0, y), font_size, color)
			y += font_size + 6
			line_text = ""
		line_text += ("" if line_text.is_empty() else " ") + word
	ui.ink(line_text, origin + Vector2(0, y), font_size, color)


func draw_jump(ui: GameUI) -> void:
	var v: VoyageController = ui.game.voyage
	var progress := clampf(v.jump_elapsed / v.JUMP_SECONDS, 0, 1)
	var center := Vector2(800, 450)
	for i in 85:
		var angle := i * 2.39996
		var radius := fposmod(i * 39.0 + v.jump_elapsed * 320, 1000)
		var direction := Vector2(cos(angle), sin(angle))
		ui.draw_line(
			center + direction * radius,
			center + direction * (radius + 10 + progress * 100),
			Color(ui.CYAN, 0.1 + progress * 0.32),
			1.5,
			true
		)
	ui.panel(Rect2(0, 0, 1600, 151), 0.92)
	ui.ink("TRANSIT CORRIDOR / DRIVE SYNCHRONIZED", Vector2(572, 66), 15, ui.CYAN)
	ui.ink(
		"Bound for " + StarNetwork.NAMES[v.jump_target], Vector2(568, 120), 42, ui.WHITE, ui.display
	)
	ui.panel(Rect2(0, 807, 1600, 193), 0.94)
	ui.ink("All craft aboard. Hold steady, Wayfarer.", Vector2(573, 861), 24, ui.WHITE)
	ui.draw_rect(Rect2(450, 895, 700, 4), Color("243a47"))
	ui.draw_rect(Rect2(450, 895, 700 * progress, 4), ui.CYAN)
	ui.ink("CORRIDOR %02d%%" % int(progress * 100), Vector2(728, 937), 16, ui.AMBER)
	var flash := maxf(0, 1 - absf(progress - 0.30) / 0.08)
	if flash > 0:
		ui.draw_rect(Rect2(0, 0, 1600, 1000), Color(0.65, 0.9, 1, flash * 0.85))
