# Instrukcja konfiguracji email - Sieciowiec VPS

## ✅ POPRAWNA KONFIGURACJA

### Konto 1: jakub.pondo@sieciowiec.xyz

**Thunderbird / Outlook / K9 Mail:**

1. **Email:** `jakub.pondo@sieciowiec.xyz`
2. **Hasło:** `ATUak~w%$7Ct4iUiz&AE`

**ODBIERANIE (IMAP):**
- **Server:** `mail.rapidmaker.pl` ⚠️ **NIE mail.sieciowiec.xyz!**
- **Port:** `993`
- **Bezpieczeństwo:** `SSL/TLS`
- **Autoryzacja:** `Normalne hasło`

**WYSYŁANIE (SMTP):**
- **Server:** `mail.rapidmaker.pl` ⚠️ **NIE mail.sieciowiec.xyz!**
- **Port:** `587`
- **Bezpieczeństwo:** `STARTTLS`
- **Autoryzacja:** `Normalne hasło`
- **Username:** `jakub.pondo@sieciowiec.xyz` (pełny email)

---

### Konto 2: rapidmaker@rapidmaker.pl

**Thunderbird / Outlook / K9 Mail:**

1. **Email:** `rapidmaker@rapidmaker.pl`
2. **Hasło:** `4OLPsusZDam8H27xHLzh9Sy2qQYwCGWt0AcLBgNjMqZHFBDHlDZF`

**ODBIERANIE (IMAP):**
- **Server:** `mail.rapidmaker.pl`
- **Port:** `993`
- **Bezpieczeństwo:** `SSL/TLS`
- **Autoryzacja:** `Normalne hasło`

**WYSYŁANIE (SMTP):**
- **Server:** `mail.rapidmaker.pl`
- **Port:** `587`
- **Bezpieczeństwo:** `STARTTLS`
- **Autoryzacja:** `Normalne hasło`
- **Username:** `rapidmaker@rapidmaker.pl` (pełny email)

---

## ⚠️ CZĘSTE BŁĘDY:

### ❌ NIE UŻYWAJ:
- `mail.sieciowiec.xyz` - certyfikat nie pasuje!
- `sieciowiec.xyz` - to blog, nie mail server
- Port `143` (niezaszyfrowany IMAP)
- Port `25` (blokowany przez dostawców)

### ✅ UŻYWAJ:
- **ZAWSZE** `mail.rapidmaker.pl` dla obu kont
- **ZAWSZE** SSL/TLS dla IMAP (port 993)
- **ZAWSZE** STARTTLS dla SMTP (port 587)

---

## 🔧 THUNDERBIRD - Krok po kroku:

1. **Menu** → **Account Settings** → **Account Actions** → **Add Mail Account**
2. **Wpisz:**
   - Your name: `Twoje Imię`
   - Email: `jakub.pondo@sieciowiec.xyz`
   - Password: `ATUak~w%$7Ct4iUiz&AE`
3. **Kliknij "Continue"**
4. ⚠️ **WAŻNE:** Kliknij **"Configure manually"** (NIE "Done")
5. **Zmień:**
   - Incoming: **IMAP**
   - Server hostname: `mail.rapidmaker.pl` (zmień jeśli auto-wykrył inaczej!)
   - Port: `993`
   - SSL: `SSL/TLS`
   - Authentication: `Normal password`
6. **Outgoing (SMTP):**
   - Server hostname: `mail.rapidmaker.pl`
   - Port: `587`
   - SSL: `STARTTLS`
   - Authentication: `Normal password`
7. **Kliknij "Re-test"** → powinno pokazać ✅
8. **Kliknij "Done"**

---

## 🧪 TEST POŁĄCZENIA (z serwera):

Jesteś na serwerze? Uruchom:

```bash
cd /srv/sieciowiec.xyz
python3 test-mail.py
```

Powinno pokazać:
```
🎉 ALL TESTS PASSED!
```

---

## 📊 STATYSTYKI:

- **IMAP:** jakub.pondo@sieciowiec.xyz - **1253 wiadomości**
- **IMAP:** rapidmaker@rapidmaker.pl - **380 wiadomości**
- **Mailserver:** v15.1.0 (docker-mailserver)
- **Dovecot:** v2.3.19.1
- **Postfix:** v3.7.11

---

## ❓ TROUBLESHOOTING:

### "Certificate error" / "Certyfikat niepoprawny"
→ **Sprawdź czy używasz `mail.rapidmaker.pl`, nie `mail.sieciowiec.xyz`**

### "Connection timeout"
→ Sprawdź porty: 993 (IMAP) i 587 (SMTP), nie 143 i 25!

### "Authentication failed" / "Hasło nieprawidłowe"
→ Skopiuj hasło z tej instrukcji (bez spacji na końcu!)

### "Can't connect"
→ Thunderbird cache - usuń konto i dodaj ponownie

---

## 📞 KONTAKT:

W razie problemów - sprawdź logi:
```bash
docker logs mailserver --tail 50
```

Albo uruchom test:
```bash
python3 /srv/sieciowiec.xyz/test-mail.py
```
