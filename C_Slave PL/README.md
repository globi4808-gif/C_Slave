# C_Slave PL 🪢

Mini aplikacja na **Windows 10/11**. Twój kursor zamienia się w animowany pejcz, a po pulpicie biega ludzik Claude, którego możesz gonić batem.

**Jeden plik, zero instalacji** – korzysta tylko z tego, co już jest w Windowsie (PowerShell + .NET Framework).

<p align="center"><img src="icon.png" width="128" alt="C_Slave"></p>

## Szybki start (copy-paste)

1. Otwórz plik [`C_Slave.cmd`](C_Slave.cmd) na GitHubie i kliknij **Download raw file** (ikona pobierania nad kodem) – albo skopiuj całą zawartość do Notatnika i zapisz jako `C_Slave.cmd` (typ: *Wszystkie pliki*, żeby nie dopisało `.txt`).
2. Kliknij plik **dwa razy**.
3. Poczekaj kilka sekund (pierwsze uruchomienie kompiluje kod i nagrywa głosy), a kursor zamieni się w pejcz.
4. Przy pierwszym uruchomieniu na pulpicie pojawia się skrót **C_Slave PL** z ikoną – od tej pory uruchamiasz z niego.

> Jeśli Windows pokaże ostrzeżenie SmartScreen: **Więcej informacji → Uruchom mimo to**. Plik nie jest podpisany cyfrowo, więc Windows jest ostrożny.

## Sterowanie

| Akcja | Efekt |
|---|---|
| Ruch myszy | pejcz podąża za kursorem |
| **Prawy przycisk myszy (PPM)** | uderzenie batem z dźwiękiem trzasku |
| Machnięcie myszą + PPM | uderzenie w kierunku ruchu myszy |
| **Esc** | wyjście z aplikacji, kursor wraca |

Lewy przycisk i reszta pulpitu działają normalnie. PPM jest przechwytywany przez aplikację (nie otwiera menu kontekstowego).

## Co się dzieje

- Ludzik chodzi w losowych kierunkach i ucieka przed pejczem. Trafiony mówi piskliwym głosikiem („Błąd 429: za dużo batów!”).
- **Po 4 trafieniach** siada do laptopa i pisze, **po 7** pisze jak szalony (pot, dym, szybkie klawisze). Po 12 s bez bicia odpoczywa.
- **Po minucie spokoju** idzie na kanapę, włącza telewizor (bez dźwięku) i czyta gazetę. **Po kolejnej minucie** kładzie się na poduszce, przykrywa kocykiem w kratę i zasypia, chrapiąc spokojnie (Zzz). Każde trzaśnięcie batem go budzi.
- Bat rozbija **ikony pulpitu** – tylko jako efekt nakładki, prawdziwe ikony nie są ruszane i wracają po kilku sekundach.

## Rozwiązywanie problemów

| Problem | Co zrobić |
|---|---|
| Nic się nie dzieje po kliknięciu | Poczekaj 5–10 s. Jeśli nadal nic – zajrzyj do `%TEMP%\C_Slave_PL_error.txt` (Win+R → wklej ścieżkę). Przy błędzie startu pojawi się też okienko z komunikatem. |
| Windows blokuje plik | *Właściwości* pliku → zaznacz **Odblokuj** → OK. Albo wklej treść do Notatnika i zapisz od nowa. **Smart App Control** (Windows 11, włączony) może zablokować program całkowicie – wymaga wyłączenia w *Zabezpieczenia Windows → Kontrola aplikacji i przeglądarki*. |
| Kursor został niewidoczny (np. po zabiciu procesu) | W wierszu poleceń: `C_Slave.cmd restore` albo wyloguj się i zaloguj ponownie. |
| Brak głosu | Głos to systemowy syntezator Windows (podbity wysoko). Polski głos dodasz w *Ustawienia → Czas i język → Mowa*. Bez niego mówi po polsku z obcym akcentem. |
| Skrót na pulpicie zniknął | `C_Slave.cmd ikona` odtwarza skrót i ikonę. |

## Zmiana ustawień

Otwórz `C_Slave.cmd` w Notatniku. Najważniejsze stałe (C#, wewnątrz pliku):

- `CouchAfter` / `ReadFor` – czas do kanapy i do drzemki (sekundy, domyślnie 60)
- `VoicePitch` – wysokość głosu (domyślnie `1.8f`)
- `streak >= 4` / `streak >= 7` – progi pracy i szału
- `T - lastHitT > 12f` – po ilu sekundach ludzik przestaje pracować

## Odinstalowanie

Naciśnij **Esc**, usuń skrót z pulpitu oraz plik `C_Slave.cmd`. Opcjonalnie usuń folder `%LOCALAPPDATA%\C_Slave_PL` i pliki `C_Slave_PL_*` z `%TEMP%`. Aplikacja niczego nie instaluje ani nie zmienia w rejestrze.

## Jak to działa (skrót)

Plik `.cmd` uruchamia PowerShell, który kompiluje wbudowany kod C# i otwiera przezroczystą, „klikalną na wylot” nakładkę na cały ekran. Systemowe kursory są na czas działania zastąpione pustymi (przywracane przy wyjściu).

---
🇬🇧 English version: [`../C_Slave EN`](../C_Slave%20EN)
