# Prší 3D (Android)

Česká karetní hra **Prší** jako Android aplikace — hra ve 3D s jednohlavými
mariášovými kartami (Srdce, Kule, Listy, Žaludy), hráč proti počítači.
Jádro hry je webová stránka (`app/src/main/assets/index.html`) zabalená do
nativního WebView.

## Jak získat APK (bez Android Studia)

1. Nahraj tyto soubory do repozitáře (jsou tu všechny).
2. Jdi na záložku **Actions** v repu → workflow **Build APK** se spustí sám
   po pushi (nebo ho spusť ručně tlačítkem *Run workflow*).
3. Po doběhnutí (pár minut) otevři běh → sekce **Artifacts** → stáhni
   **prsi-debug-apk**. Uvnitř je `app-debug.apk`.
4. Přenes APK do telefonu, povol *Instalace z neznámých zdrojů* a nainstaluj.

> Jde o **debug** APK (podepsané debug klíčem) — pro vlastní hraní a
> rozesílání kamarádům stačí. Pro Google Play by bylo potřeba release
> podpis.

## Pravidla hry

- Přikládá se karta stejné **barvy** nebo **hodnoty**.
- **Sedma** — další hráč bere 2 (sedmy se sčítají).
- **Eso** — další hráč stojí (přeskočí tah).
- **Svršek** — žolík: hraje se na cokoli a určuje novou barvu.
- Nemáš-li tah, líznеš si z balíčku.
- Vyhrává ten, kdo se první zbaví všech karet.

## Lokální build (volitelné)

```bash
gradle wrapper --gradle-version 8.7
./gradlew assembleDebug
# APK: app/build/outputs/apk/debug/app-debug.apk
```

Vyžaduje JDK 17 a Android SDK (platform 34).

## Licence grafiky karet
Obrázky karet (`app/src/main/assets/cards/`) pocházejí z fotografie
„Bohemian pattern.png“ od uživatele **Countakeshi**, Wikimedia Commons
(https://commons.wikimedia.org/wiki/File:Bohemian_pattern.png),
licence **CC BY-SA 4.0** (https://creativecommons.org/licenses/by-sa/4.0/).
Upraveno: rozřezáno na jednotlivé karty, upraven jas a kontrast.
Upravené obrázky karet jsou šířeny pod stejnou licencí CC BY-SA 4.0.
