extends SceneTree
func _init():
	var games := 4000
	var errors := 0
	var turns_total := 0
	var max_pen := 0
	var multi := 0
	for g in games:
		var r := Rules.new()
		var n := 2 + (g % 9)
		var decks := maxi(Rules.min_decks(n), 1 + (g % 5))
		var nm: Array = []
		for i in n:
			nm.append("P%d" % i)
		var mx := Rules.max_per_player(n, decks)
		var h := 4 + (g % 3)
		var o := 2 + (g % 2)
		r.new_game(nm, g % n, h, o, decks, g)
		if r.hand_n + r.open_n > mx or r.hand_n < 4 or r.open_n < 2:
			errors += 1
			print("DEAL LIMIT ", n, " ", decks, " ", r.hand_n, "+", r.open_n)
		var t := 0
		while r.winner < 0 and t < 20000:
			var p := r.cur
			var m := r.ai_move(p)
			var ok := r.pass_turn(p) if m.has("pass") else r.play(p, m["cards"], m["suit"])
			if not ok:
				errors += 1
				print("REJECTED ", m, " game ", g)
				break
			if m.has("cards") and m["cards"].size() != 1:
				errors += 1
				print("MULTI PLAY ", m)
			max_pen = maxi(max_pen, r.penalty)
			var total := r.deck.size() + r.discard.size()
			for i in n:
				total += r.hands[i].size() + r.opens[i].size()
			if total != decks * 32:
				errors += 1
				print("CARD COUNT ", total, " game ", g)
				break
			t += 1
		if r.winner < 0:
			errors += 1
			print("NO WINNER game ", g, " n=", n)
		elif r.loser < 0 or r.loser == r.winner:
			errors += 1
			print("BAD LOSER game ", g)
		turns_total += t
	# targeted checks (single deck, ids < 32)
	var r2 := Rules.new()
	r2.new_game(["A", "B", "C"], 2, 4, 2, 5, 1)
	r2.discard = [2]               # devitka srdce
	r2.top_suit = 0; r2.penalty = 0; r2.ace_stop = false; r2.cur = 0
	r2.hands[0] = [8 + 0, 32 + 8 + 0, 64 + 0]   # sedma kule (x2), sedma srdce
	r2.opens[0] = [16 + 3, 96 + 16 + 3]         # desitka listy x2
	assert(not r2.play(0, [8]))                 # sedma kule does not match srdce/9
	assert(not r2.play(0, [64, 8]))             # never two cards at once
	assert(r2.play(0, [64]) and r2.penalty == 2 and r2.cur == 1)
	r2.hands[1] = [24]                          # sedma zaludy
	assert(r2.play(1, [24]) and r2.penalty == 4)
	r2.hands[2] = [72]                          # sedma kule (3. balicek)
	assert(r2.play(2, [72]) and r2.penalty == 6)  # sevens stack without limit
	assert(r2.pass_turn(0) and r2.penalty == 0 and r2.hands[0].size() == 8)
	# open cards: win only when hand AND open cards are empty
	r2.cur = 0; r2.discard.append(16 + 1); r2.top_suit = 2; r2.penalty = 0; r2.ace_stop = false
	r2.hands[0] = []
	assert(r2.play(0, [19]) and r2.winner < 0 and r2.opens[0].size() == 1)
	r2.cur = 0
	assert(r2.play(0, [96 + 19]) and r2.winner == 0)
	assert(r2.loser >= 1)
	assert(Rules.max_per_player(10, 5) == 13)
	print("games=", games, " avg_turns=", float(turns_total) / games, " multi_plays=", multi, " max_penalty=", max_pen, " errors=", errors)
	print("RULES_OK" if errors == 0 else "RULES_FAIL")
	quit()
