# Prší – hospodská klasika (Godot 4)

Česká karetní hra **Prší** pro Android s fotkami skutečných jednohlavých
mariášek. Hraje se proti počítači (Pepa, Franta) nebo s kamarádem **přes Wi-Fi**.

**Stáhnout APK:** https://github.com/Jedn0ta/prsivoe/releases/download/latest/prsi.apk

## Ovládání
- **Táhni kartu** prstem na odhazovací balíček, nebo ji **švihni nahoru**.
- **Ťukni** na kartu (zvedne se) a ťukni znovu → zahraje se.
- **Ťukni na balík** = líznout si / vzít trest za sedmu / stát po esu.
- Svršek → vybereš barvu.

## Hra přes Wi-Fi
1. Oba telefony na stejné Wi-Fi.
2. Jeden dá **Založit stůl na Wi-Fi**, může přisadit i Pepu (počítač).
3. Druhý dá **Připojit se ke stolu** – stůl se objeví v seznamu sám.
   Kdyby ne, opiš IP adresu, kterou ukazuje hostitel.
4. Hostitel dá **Rozdat karty**.

## Pravidla
- Přikládá se karta stejné **barvy** nebo **hodnoty**.
- **Sedma** – další bere 2, sedmy se sčítají (přebiješ sedmou).
- **Eso** – další stojí, pokud nedá taky eso.
- **Svršek** – hraje se na cokoli (ne na sedmu/eso v akci) a mění barvu.
- Kdo se první zbaví všech karet, vyhrál.

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
