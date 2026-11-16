extends SceneTree
func _init():
	var games := 3000
	var turns_total := 0
	var wins := [0, 0, 0]
	var errors := 0
	for g in games:
		var r := Rules.new()
		var n := 2 + (g % 2)
		var nm := ["A", "B", "C"].slice(0, n)
		r.new_game(nm, g % n, g)
		var t := 0
		while r.winner < 0 and t < 5000:
			var p := r.cur
			var m := r.ai_move(p)
			var ok := r.pass_turn(p) if m.has("pass") else r.play(p, m["card"], m["suit"])
			if not ok:
				errors += 1
				break
			var total := r.deck.size() + r.discard.size()
			for h in r.hands:
				total += h.size()
			if total != 32:
				errors += 1
				print("CARD COUNT ", total, " game ", g)
				break
			t += 1
		if r.winner < 0:
			errors += 1
			print("NO WINNER game ", g)
		else:
			wins[r.winner] += 1
		turns_total += t
	# targeted rule checks
	var r2 := Rules.new()
	r2.new_game(["A", "B"], 0, 1)
	r2.discard = [0 * 8 + 2]  # devitka srdce
	r2.top_suit = 0; r2.penalty = 0; r2.ace_stop = false; r2.cur = 0
	r2.hands[0] = [1 * 8 + 0, 2 * 8 + 5, 0 * 8 + 4]  # sedma kule, svrsek listy, spodek srdce
	assert(r2.can_play(0 * 8 + 4))  # same suit
	assert(not r2.can_play(1 * 8 + 0))  # wrong suit & rank
	assert(r2.can_play(2 * 8 + 5))  # svrsek on anything
	r2.play(0, 2 * 8 + 5, 3)
	assert(r2.top_suit == 3 and r2.cur == 1)
	r2.penalty = 2
	r2.hands[1] = [3 * 8 + 1, 1 * 8 + 0]
	assert(not r2.can_play(3 * 8 + 1) and r2.can_play(1 * 8 + 0))
	r2.pass_turn(1)
	assert(r2.hands[1].size() == 4 and r2.penalty == 0)
	print("games=", games, " avg_turns=", float(turns_total) / games, " wins=", wins, " errors=", errors)
	print("RULES_OK" if errors == 0 else "RULES_FAIL")
	quit()
