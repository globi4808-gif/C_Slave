# C_Slave

Mini aplikacja na Windows 10/11: Twój kursor zamienia się w animowany pejcz, a po pulpicie biega ludzik Claude, którego możesz gonić batem.

**Jeden plik, bez instalacji** – pobierz `C_Slave.cmd` i kliknij go dwa razy. Korzysta tylko z tego, co jest w Windowsie (PowerShell + .NET Framework).

## Sterowanie
- **Mysz** – pejcz zamiast kursora (system. kursor jest ukryty)
- **PPM** – uderzenie batem z dźwiękiem; kierunek uderzenia = kierunek ruchu myszy
- **Esc** – wyjście

## Co się dzieje
- ludzik ucieka przed pejczem, trafiony mówi piskliwym głosikiem
- po kilku batach siada do laptopa i pisze, po kolejnych pisze jak szalony
- po minucie spokoju siada na kanapie, włącza telewizor i czyta gazetę, po kolejnej minucie zasypia i chrapie
- bat rozbija (tylko jako nakładka) ikony pulpitu

## Uwagi
- Pierwsze uruchomienie tworzy skrót **C_Slave** z ikoną na pulpicie (`C_Slave.cmd ikona` odtwarza go).
- Windows może pokazać ostrzeżenie SmartScreen / Smart App Control, bo plik nie jest podpisany. Smart App Control (włączony) może całkowicie zablokować program.
- Gdyby kursor został niewidoczny po awarii: `C_Slave.cmd restore` albo wylogowanie.
- Błędy: `%TEMP%\C_Slave_error.txt`.
