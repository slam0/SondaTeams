# Sonda Teams (iOS 6)

Mała aplikacja testowa. Sprawdza, czy telefon z iOS 6 potrafi połączyć się przez HTTPS z serwerami Microsoftu
(logowanie `login.microsoftonline.com` i Graph `graph.microsoft.com`), z których korzysta Microsoft Teams.
Niczego nie logujesz i nie wysyłasz żadnych swoich danych. Wszystkie zapytania są puste albo z fałszywym identyfikatorem.

## Co robi test

1. Strona kontrolna z kursami walut (tak samo łączy się Currency).
2. GitHub (kontrola, certyfikat DigiCert).
3. Microsoft: publiczna konfiguracja logowania (GET).
4. Microsoft: logowanie metodą kodu urządzenia (POST z fałszywym identyfikatorem, oczekiwany błąd AADSTS).
5. Microsoft Graph bez tokenu (oczekiwane HTTP 401).
6. Stary adres Skype (tylko dla porównania).

Przy każdym zapytaniu raport pokazuje kod odpowiedzi, czas, błąd (jeśli był) oraz łańcuch certyfikatów
razem z informacją, czy iOS 6 uznaje go za zaufany. Na końcu jest podsumowanie z wnioskiem.

Uwaga: dla celów diagnostycznych test kontynuuje połączenie nawet wtedy, gdy certyfikat jest niezaufany (żeby było widać, czy sam TLS działa).
Wysyłane są wtedy tylko puste zapytania. Nie używaj tej aplikacji do niczego innego.

## Jak zbudować (GitHub Actions)

1. Załóż nowe repozytorium, np. `TeamsProbe`, i wgraj wszystkie pliki z tego folderu (łącznie z ukrytym `.github`).
2. Zakładka **Actions** → **Zbuduj Sondę Teams** → **Run workflow** (nie „Re-run all jobs”).
3. Po kilku minutach w zakładce **Releases** (wydanie „najnowsza”) pojawi się plik `.deb`.
4. Zainstaluj `.deb` na telefonie (Filza albo Cydia) i otwórz **Sonda Teams**.

## Jak użyć

1. Połącz telefon z Wi-Fi.
2. Naciśnij **Uruchom test** i poczekaj (do 2 minut, każde zapytanie ma 20 s limitu).
3. Naciśnij **Kopiuj raport** i wklej całość do rozmowy.

## Pliki

- `TPProbe.m`: silnik testu (NSURLConnection wyszukiwane po nazwie w czasie działania, SecTrust do łańcucha certyfikatów)
- `TPController.m`: ekran z przyciskami i raportem
- `TPCrash.m`: zapisuje ostatni krok i wyjątek, żeby po awarii pokazać je przy następnym uruchomieniu
- `tp_libc.c`: własne wersje memcpy i podobnych (potrzebne przy zastępczych plikach SDK, patrz komentarz w pliku)
