class_name Rules
extends RefCounted
## Pure game logic for Prší. No graphics, no networking.
## Card id 0..31: suit = id / 8, rank = id % 8.

const SUITS := ["srdce", "kule", "listy", "zaludy"]
const SUIT_NAMES := ["Srdce", "Kule", "Listy", "Žaludy"]
const RANKS := ["7", "8", "9", "10", "J", "Q", "K", "A"]
const RANK_NAMES := ["Sedma", "Osma", "Devítka", "Desítka", "Spodek", "Svršek", "Král", "Eso"]
const R7 := 0
const RQ := 5
const RA := 7
const HAND_SIZE := 4

var n: int = 2
var names: Array = []
var hands: Array = []
var deck: Array = []
var discard: Array = []
var top_suit: int = 0
var penalty: int = 0
var ace_stop: bool = false
var cur: int = 0
var winner: int = -1
var last_event: Dictionary = {}
var rng := RandomNumberGenerator.new()


static func suit_of(c: int) -> int:
	return c / 8


static func rank_of(c: int) -> int:
	return c % 8


static func card_name(c: int) -> String:
	return "%s %s" % [RANK_NAMES[rank_of(c)].to_lower(), SUIT_NAMES[suit_of(c)].to_lower()]


static func texture_path(c: int) -> String:
	return "res://cards/%s_%s.jpg" % [SUITS[suit_of(c)], RANKS[rank_of(c)]]


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func new_game(player_names: Array, start: int = 0, seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	names = player_names.duplicate()
	n = names.size()
	deck = []
	for i in 32:
		deck.append(i)
	_shuffle(deck)
	discard = []
	hands = []
	for i in n:
		hands.append(_draw(HAND_SIZE))
	var f: int = deck.pop_back()
	while rank_of(f) == RQ:
		deck.push_front(f)
		f = deck.pop_back()
	discard = [f]
	top_suit = suit_of(f)
	penalty = 2 if rank_of(f) == R7 else 0
	ace_stop = rank_of(f) == RA
	cur = start % n
	winner = -1
	last_event = {"type": "start", "seat": -1}


func _draw(k: int) -> Array:
	var out: Array = []
	for i in k:
		if deck.is_empty():
			if discard.size() > 1:
				var t: int = discard.pop_back()
				deck = discard
				_shuffle(deck)
				discard = [t]
			else:
				break
		out.append(deck.pop_back())
	return out


func top() -> int:
	return discard.back()


static func can_play_on(c: int, top_card: int, tsuit: int, pen: int, ace: bool) -> bool:
	if ace:
		return rank_of(c) == RA
	if pen > 0:
		return rank_of(c) == R7
	if rank_of(c) == RQ:
		return true
	return suit_of(c) == tsuit or rank_of(c) == rank_of(top_card)


func can_play(c: int) -> bool:
	return can_play_on(c, top(), top_suit, penalty, ace_stop)


func playable(p: int) -> Array:
	var out: Array = []
	for c in hands[p]:
		if can_play(c):
			out.append(c)
	return out


func play(p: int, c: int, suit: int = -1) -> bool:
	if winner >= 0 or p != cur or not hands[p].has(c) or not can_play(c):
		return false
	hands[p].erase(c)
	discard.append(c)
	top_suit = suit_of(c)
	var r := rank_of(c)
	if r == R7:
		penalty += 2
	elif r == RA:
		ace_stop = true
	elif r == RQ:
		if suit < 0 or suit > 3:
			suit = suit_of(c)
		top_suit = suit
	last_event = {"type": "play", "seat": p, "card": c, "suit": top_suit, "penalty": penalty, "left": hands[p].size()}
	if hands[p].is_empty():
		winner = p
		last_event["win"] = true
		return true
	cur = (cur + 1) % n
	return true


func pass_turn(p: int) -> bool:
	if winner >= 0 or p != cur:
		return false
	var ev := {"type": "pass", "seat": p}
	if ace_stop:
		ace_stop = false
		ev["kind"] = "stand"
	else:
		var k := penalty if penalty > 0 else 1
		var d := _draw(k)
		hands[p].append_array(d)
		ev["kind"] = "draw"
		ev["count"] = d.size()
		ev["forced"] = penalty > 0
		penalty = 0
	last_event = ev
	cur = (cur + 1) % n
	return true


func view_for(p: int) -> Dictionary:
	var counts: Array = []
	for h in hands:
		counts.append(h.size())
	var mine: Array = []
	if p >= 0 and p < n:
		mine = hands[p].duplicate()
	return {
		"seat": p, "n": n, "names": names.duplicate(), "hand": mine, "counts": counts,
		"discard": discard.slice(max(0, discard.size() - 6)), "top_suit": top_suit,
		"penalty": penalty, "ace_stop": ace_stop, "cur": cur, "deck": deck.size(),
		"winner": winner, "ev": last_event.duplicate(),
	}


# ---------------- AI ----------------
func ai_move(p: int) -> Dictionary:
	var opts := playable(p)
	if opts.is_empty():
		return {"pass": true}
	var nxt: int = hands[(p + 1) % n].size()
	var best: int = opts[0]
	var best_score := -1e9
	for c in opts:
		var r := rank_of(c)
		var v := 2.0
		if r == R7:
			v = 9.0 if nxt <= 2 else 5.0
		elif r == RA:
			v = 8.0 if nxt <= 2 else 4.0
		elif r == RQ:
			v = -3.0 + (8.0 if hands[p].size() <= 2 else 0.0)
		for k in hands[p]:
			if k != c and suit_of(k) == suit_of(c):
				v += 0.6
		v += rng.randf()
		if v > best_score:
			best_score = v
			best = c
	var suit := -1
	if rank_of(best) == RQ:
		suit = best_suit_for(p, best)
	return {"card": best, "suit": suit}


func best_suit_for(p: int, except_card: int = -1) -> int:
	var cnt := [0, 0, 0, 0]
	for k in hands[p]:
		if k != except_card and rank_of(k) != RQ:
			cnt[suit_of(k)] += 1
	var best := 0
	for s in 4:
		if cnt[s] > cnt[best]:
			best = s
	return best
