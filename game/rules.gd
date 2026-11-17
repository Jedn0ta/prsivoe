class_name Rules
extends RefCounted
## Pure game logic for pub Prší. No graphics, no networking.
## Card id = deck * 32 + base; base: suit = base / 8, rank = base % 8.
## Variant: several decks, open cards per player, several cards of one rank at once,
## sevens stack without limit, the loser deals the next round.

const SUITS := ["srdce", "kule", "listy", "zaludy"]
const SUIT_NAMES := ["Srdce", "Kule", "Listy", "Žaludy"]
const RANKS := ["7", "8", "9", "10", "J", "Q", "K", "A"]
const RANK_NAMES := ["Sedma", "Osma", "Devítka", "Desítka", "Spodek", "Svršek", "Král", "Eso"]
const R7 := 0
const RQ := 5
const RA := 7
const MIN_HAND := 4
const MIN_OPEN := 2

var n: int = 2
var decks: int = 1
var names: Array = []
var hands: Array = []
var opens: Array = []
var deck: Array = []
var discard: Array = []
var top_suit: int = 0
var penalty: int = 0
var ace_stop: bool = false
var cur: int = 0
var dealer: int = 0
var hand_n: int = 4
var open_n: int = 2
var winner: int = -1
var loser: int = -1
var last_event: Dictionary = {}
var seq: int = 0
var rng := RandomNumberGenerator.new()


static func base_of(c: int) -> int:
	return c % 32


static func suit_of(c: int) -> int:
	return (c % 32) / 8


static func rank_of(c: int) -> int:
	return c % 8


static func card_name(c: int) -> String:
	return "%s %s" % [RANK_NAMES[rank_of(c)].to_lower(), SUIT_NAMES[suit_of(c)].to_lower()]


static func texture_path(c: int) -> String:
	return "res://cards/%s_%s.jpg" % [SUITS[suit_of(c)], RANKS[rank_of(c)]]


## Highest number of cards (hand + open) one player may get.
static func max_per_player(players: int, deck_count: int) -> int:
	var reserve := maxi(5, deck_count * 5)
	return (deck_count * 32 - 1 - reserve) / maxi(players, 1)


static func min_decks(players: int) -> int:
	for d in range(1, 6):
		if max_per_player(players, d) >= MIN_HAND + MIN_OPEN:
			return d
	return 5


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func new_game(player_names: Array, dealer_seat: int, hand_count: int, open_count: int, deck_count: int, seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	names = player_names.duplicate()
	n = names.size()
	decks = clampi(deck_count, 1, 5)
	var mx := max_per_player(n, decks)
	hand_n = maxi(MIN_HAND, hand_count)
	open_n = maxi(MIN_OPEN, open_count)
	while hand_n + open_n > mx and hand_n > MIN_HAND:
		hand_n -= 1
	while hand_n + open_n > mx and open_n > MIN_OPEN:
		open_n -= 1
	deck = []
	for i in decks * 32:
		deck.append(i)
	_shuffle(deck)
	discard = []
	hands = []
	opens = []
	for i in n:
		hands.append(_draw(hand_n))
	for i in n:
		opens.append(_draw(open_n))
	var f: int = deck.pop_back()
	while rank_of(f) == RQ:
		deck.push_front(f)
		f = deck.pop_back()
	discard = [f]
	top_suit = suit_of(f)
	penalty = 2 if rank_of(f) == R7 else 0
	ace_stop = rank_of(f) == RA
	dealer = dealer_seat % n
	cur = (dealer + 1) % n
	winner = -1
	loser = -1
	_event({"type": "start", "seat": dealer, "hand_n": hand_n, "open_n": open_n})


func _event(ev: Dictionary) -> void:
	seq += 1
	ev["seq"] = seq
	last_event = ev


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


## Checks a group play: all same rank, first one playable. Returns ordered group or [] if invalid.
static func order_group(cards: Array, top_card: int, tsuit: int, pen: int, ace: bool) -> Array:
	if cards.is_empty():
		return []
	var r := rank_of(cards[0])
	for c in cards:
		if rank_of(c) != r:
			return []
	for i in cards.size():
		if can_play_on(cards[i], top_card, tsuit, pen, ace):
			var out: Array = [cards[i]]
			for j in cards.size():
				if j != i:
					out.append(cards[j])
			return out
	return []


func can_play(c: int) -> bool:
	return can_play_on(c, top(), top_suit, penalty, ace_stop)


func owns(p: int, c: int) -> bool:
	return hands[p].has(c) or opens[p].has(c)


func cards_left(p: int) -> int:
	return hands[p].size() + opens[p].size()


func play(p: int, cards: Array, suit: int = -1) -> bool:
	if winner >= 0 or p != cur or cards.is_empty():
		return false
	var seen := {}
	for c in cards:
		if seen.has(c) or not owns(p, c):
			return false
		seen[c] = true
	var group := order_group(cards, top(), top_suit, penalty, ace_stop)
	if group.is_empty():
		return false
	for c in group:
		if hands[p].has(c):
			hands[p].erase(c)
		else:
			opens[p].erase(c)
		discard.append(c)
	var last: int = group.back()
	top_suit = suit_of(last)
	var r := rank_of(last)
	if r == R7:
		penalty += 2 * group.size()
	elif r == RA:
		ace_stop = true
	elif r == RQ:
		if suit < 0 or suit > 3:
			suit = suit_of(last)
		top_suit = suit
	_event({"type": "play", "seat": p, "cards": group, "suit": top_suit, "penalty": penalty, "left": cards_left(p)})
	if cards_left(p) == 0:
		winner = p
		last_event["win"] = true
		_pick_loser()
		return true
	cur = (cur + 1) % n
	return true


func _pick_loser() -> void:
	var best := -1
	var most := -1
	for k in range(1, n):
		var q := (winner + k) % n
		if cards_left(q) > most:
			most = cards_left(q)
			best = q
	loser = best


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
	_event(ev)
	cur = (cur + 1) % n
	return true


func view_for(p: int) -> Dictionary:
	var counts: Array = []
	for h in hands:
		counts.append(h.size())
	var op: Array = []
	for o in opens:
		op.append(o.duplicate())
	var mine: Array = []
	if p >= 0 and p < n:
		mine = hands[p].duplicate()
	return {
		"seat": p, "n": n, "names": names.duplicate(), "hand": mine, "counts": counts, "opens": op,
		"discard": discard.slice(max(0, discard.size() - 6)), "top_suit": top_suit,
		"penalty": penalty, "ace_stop": ace_stop, "cur": cur, "deck": deck.size(), "decks": decks,
		"dealer": dealer, "winner": winner, "loser": loser, "ev": last_event.duplicate(true),
	}


# ---------------- AI ----------------
func ai_move(p: int) -> Dictionary:
	var mine: Array = hands[p] + opens[p]
	var opts: Array = []
	for c in mine:
		if can_play(c):
			opts.append(c)
	if opts.is_empty():
		return {"pass": true}
	var nxt: int = cards_left((p + 1) % n)
	var best: int = opts[0]
	var best_score := -1e9
	for c in opts:
		var r := rank_of(c)
		var v := 2.0
		if r == R7:
			v = 9.0 if nxt <= 3 else 5.0
		elif r == RA:
			v = 8.0 if nxt <= 3 else 4.0
		elif r == RQ:
			v = -3.0 + (8.0 if mine.size() <= 3 else 0.0)
		if opens[p].has(c):
			v += 1.5
		for k in mine:
			if k != c and rank_of(k) == r:
				v += 1.2
			elif k != c and suit_of(k) == suit_of(c):
				v += 0.5
		v += rng.randf()
		if v > best_score:
			best_score = v
			best = c
	var group: Array = [best]
	if rank_of(best) != RQ or mine.size() <= 3:
		for k in mine:
			if k != best and rank_of(k) == rank_of(best):
				group.append(k)
	var suit := -1
	if rank_of(best) == RQ:
		suit = best_suit_for(p, group)
	return {"cards": group, "suit": suit}


func best_suit_for(p: int, except_cards: Array = []) -> int:
	var cnt := [0, 0, 0, 0]
	for k in hands[p] + opens[p]:
		if not except_cards.has(k) and rank_of(k) != RQ:
			cnt[suit_of(k)] += 1
	var best := 0
	for s in 4:
		if cnt[s] > cnt[best]:
			best = s
	return best


func ai_deal_choice() -> Array:
	var mx := max_per_player(n, decks)
	var h := rng.randi_range(MIN_HAND, mini(6, mx - MIN_OPEN))
	var o := rng.randi_range(MIN_OPEN, mini(3, mx - h))
	return [h, o]
