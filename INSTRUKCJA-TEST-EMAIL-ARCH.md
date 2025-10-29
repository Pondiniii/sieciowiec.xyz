# Instrukcja testowania email z Arch Linux

## 1. Instalacja wymaganych pakietów

```bash
sudo pacman -S python python-pip
pip install --user secure-smtplib
```

Lub możesz użyć standardowej biblioteki Pythona (bez dodatkowych pakietów).

## 2. Utwórz skrypt testowy

Stwórz plik `test-email.py`:

```python
#!/usr/bin/env python3
import imaplib
import smtplib
import ssl
import sys
from email.mime.text import MIMEText

# Konfiguracja kont email
ACCOUNTS = [
    {
        'email': 'jakub.pondo@sieciowiec.xyz',
        'password': 'ATUak~w%$7Ct4iUiz&AE',
        'name': 'Sieciowiec'
    },
    {
        'email': 'rapidmaker@rapidmaker.pl',
        'password': '4OLPsusZDam8H27xHLzh9Sy2qQYwCGWt0AcLBgNjMqZHFBDHlDZF',
        'name': 'Rapidmaker'
    }
]

IMAP_SERVER = 'mail.rapidmaker.pl'
IMAP_PORT = 993
SMTP_SERVER = 'mail.rapidmaker.pl'
SMTP_PORT = 587

def test_imap(email, password, account_name):
    """Test połączenia IMAP"""
    try:
        print(f"\n[{account_name}] Testowanie IMAP ({email})...")
        context = ssl.create_default_context()
        imap = imaplib.IMAP4_SSL(IMAP_SERVER, IMAP_PORT, ssl_context=context)
        imap.login(email, password)
        status, messages = imap.select('INBOX')
        num_messages = int(messages[0])
        print(f"  ✓ IMAP OK - Połączono, liczba wiadomości: {num_messages}")
        imap.logout()
        return True
    except Exception as e:
        print(f"  ✗ IMAP BŁĄD: {e}")
        return False

def test_smtp(email, password, account_name):
    """Test połączenia SMTP"""
    try:
        print(f"[{account_name}] Testowanie SMTP ({email})...")
        context = ssl.create_default_context()
        smtp = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
        smtp.ehlo()
        smtp.starttls(context=context)
        smtp.ehlo()
        smtp.login(email, password)
        print(f"  ✓ SMTP OK - Połączono i zalogowano")
        smtp.quit()
        return True
    except Exception as e:
        print(f"  ✗ SMTP BŁĄD: {e}")
        return False

def main():
    print("=" * 60)
    print("TEST POŁĄCZEŃ EMAIL - mail.rapidmaker.pl")
    print("=" * 60)

    results = {'imap': 0, 'smtp': 0, 'total': len(ACCOUNTS) * 2}

    for account in ACCOUNTS:
        if test_imap(account['email'], account['password'], account['name']):
            results['imap'] += 1
        if test_smtp(account['email'], account['password'], account['name']):
            results['smtp'] += 1

    print("\n" + "=" * 60)
    print("PODSUMOWANIE:")
    print(f"  IMAP: {results['imap']}/{len(ACCOUNTS)} kont OK")
    print(f"  SMTP: {results['smtp']}/{len(ACCOUNTS)} kont OK")
    print(f"  RAZEM: {results['imap'] + results['smtp']}/{results['total']} testów przeszło")
    print("=" * 60)

    if results['imap'] + results['smtp'] == results['total']:
        print("\n✓ Wszystkie testy przeszły pomyślnie!")
        sys.exit(0)
    else:
        print("\n✗ Niektóre testy nie powiodły się.")
        sys.exit(1)

if __name__ == '__main__':
    main()
```

## 3. Uruchom skrypt

```bash
chmod +x test-email.py
python test-email.py
```

## 4. Interpretacja wyników

### Jeśli wszystko działa:
```
✓ IMAP OK - Połączono, liczba wiadomości: 5
✓ SMTP OK - Połączono i zalogowano
```
**Znaczy to:** Serwer działa, ISP nie blokuje portów, problem może być w konfiguracji Thunderbirda.

### Jeśli IMAP timeout/connection refused:
```
✗ IMAP BŁĄD: [Errno 110] Connection timed out
```
**Znaczy to:** Twój ISP prawdopodobnie blokuje port 993, albo firewall na serwerze blokuje połączenia.

### Jeśli SMTP timeout/connection refused:
```
✗ SMTP BŁĄD: [Errno 110] Connection timed out
```
**Znaczy to:** Twój ISP prawdopodobnie blokuje port 587.

### Jeśli błąd autentykacji:
```
✗ IMAP BŁĄD: [AUTHENTICATIONFAILED] Authentication failed
```
**Znaczy to:** Złe hasło lub problem z konfiguracją kont na serwerze.

## 5. Dodatkowe testy

### Test połączenia z portem (bez autentykacji):
```bash
# Test czy port 993 jest dostępny
nc -zv mail.rapidmaker.pl 993

# Test czy port 587 jest dostępny
nc -zv mail.rapidmaker.pl 587

# Jeśli nc nie jest zainstalowane:
sudo pacman -S gnu-netcat
```

### Test SSL/TLS:
```bash
# Test certyfikatu IMAP
openssl s_client -connect mail.rapidmaker.pl:993 -showcerts

# Test certyfikatu SMTP z STARTTLS
openssl s_client -connect mail.rapidmaker.pl:587 -starttls smtp
```

## Co dalej?

- Jeśli testy przejdą: Problem jest w konfiguracji Thunderbirda
- Jeśli testy nie przejdą: Sprawdź firewall lub skontaktuj się z ISP
- Możesz też spróbować przez VPN aby sprawdzić czy to ISP blokuje porty
