# Prší – hospodská klasika u baru (Godot 4)

Česká karetní hra **Prší** pro Android s fotkami skutečných jednohlavých
mariášek. U baru až pro 10 hráčů s 5 balíčky – proti počítači nebo s kamarády **přes Wi-Fi**.

**Stáhnout APK:** https://github.com/Jedn0ta/prsivoe/releases/download/latest/prsi.apk

## Ovládání
- **Táhni kartu** prstem na odhoz, nebo ji **švihni nahoru**.
- **Víc stejných karet:** ťukni na ně (zvednou se) a dej **Vyložit**, nebo jednu z nich přetáhni.
- **Ťukni na balík** = líznout si / vzít trest za sedmy / stát po esu.
- Svršek → vybereš barvu.

## U baru až pro 10 hráčů
- 2–10 hráčů, 1–5 balíčků (výchozí 5 = 160 karet). Volná místa doplní počítač.
- **Rozdávající** zvolí, kolik karet dá **do ruky (min. 4)** a **otevřeně na stůl (min. 2)**;
  max. 13 karet na hráče, aby v balíku zbylo dost na lízání.
- Další kolo rozdává ten, komu zbylo **nejvíc karet**.

## Hra přes Wi-Fi
1. Všechny telefony na stejné Wi-Fi.
2. Jeden dá **Založit stůl na Wi-Fi**, nastaví počet míst a balíčků.
3. Ostatní (až 9) dají **Připojit se ke stolu** – stůl se objeví v seznamu sám.
   Kdyby ne, opiš IP adresu, kterou ukazuje hostitel.
4. Hostitel dá **Začít hrát**.

## Pravidla
- Přikládá se karta stejné **barvy** nebo **hodnoty**; stejné hodnoty lze dát **víc najednou**.
- Každý má před sebou **otevřené karty** – hraje je jen on, ostatní je vidí.
  Vyhrává, kdo se zbaví **ruky i otevřených karet**.
- **Sedma** – další bere 2 za každou sedmu, sedmy se sčítají **bez stropu** (přebiješ sedmou).
- **Eso** – další stojí, pokud nedá taky eso.
- **Svršek** – hraje se na cokoli (ne na sedmu/eso v akci) a mění barvu.

## Projekt
- `game/` – projekt Godot 4.3 (`rules.gd` pravidla a AI, `main.gd` stůl a síť,
  `net.gd` Wi-Fi a hledání stolů, `card.gd` karta s tažením/švihem).
- APK staví GitHub Actions (`.github/workflows/android.yml`) a vydává ho jako
  release `latest`. Testy: `godot --headless --path game --script res://tests/test_rules.gd`.
- Lokální testy sítě: `godot --headless --path game -- --autohost --autoplay --games=5`
  a v druhém okně `-- --autojoin=discover --autoplay --games=5`.

## Licence grafiky
Obrázky karet (`game/cards/`) pocházejí z fotografie „Bohemian pattern.png“
od uživatele **Countakeshi**, Wikimedia Commons
(https://commons.wikimedia.org/wiki/File:Bohemian_pattern.png),
licence **CC BY-SA 4.0** (https://creativecommons.org/licenses/by-sa/4.0/).
Upraveno: rozřezáno na karty, upraven jas a kontrast; ikony barev vyříznuty
z týchž karet. Tyto upravené obrázky jsou šířeny pod stejnou licencí CC BY-SA 4.0.
Písmo DejaVu – licence v `game/fonts/DejaVu-LICENSE.txt`.
