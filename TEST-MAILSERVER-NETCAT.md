# Test mailservera z netcat (ze świata)

## Sprawdzenie wszystkich portów

### 1. Port 25 (SMTP - wysyłka mail-to-mail)
```bash
nc -vz mail.rapidmaker.pl 25
# lub z timeout:
timeout 5 nc -vz mail.rapidmaker.pl 25
```

### 2. Port 465 (SMTPS - SMTP over SSL)
```bash
nc -vz mail.rapidmaker.pl 465
```

### 3. Port 587 (SMTP Submission - używany przez klientów email)
```bash
nc -vz mail.rapidmaker.pl 587
```

### 4. Port 993 (IMAPS - odbiór poczty)
```bash
nc -vz mail.rapidmaker.pl 993
```

## Test interaktywny (sprawdzenie odpowiedzi serwera)

### SMTP (port 25) - z pozdrowieniem
```bash
nc mail.rapidmaker.pl 25
# Po połączeniu wpisz:
EHLO test.example.com
QUIT
```
Powinno zwrócić: `220 mail.rapidmaker.pl ESMTP Postfix`

### SMTP Submission (port 587) - z STARTTLS
```bash
nc mail.rapidmaker.pl 587
# Po połączeniu wpisz:
EHLO test.example.com
QUIT
```
Powinno zwrócić banner Postfix + lista możliwości (m.in. STARTTLS)

### IMAP (port 993) - z OpenSSL (bo SSL)
```bash
openssl s_client -connect mail.rapidmaker.pl:993 -crlf
# Po połączeniu wpisz:
a1 LOGOUT
```
Powinno zwrócić: `* OK [CAPABILITY ...] Dovecot ready.`

### SMTPS (port 465) - z OpenSSL (bo SSL)
```bash
openssl s_client -connect mail.rapidmaker.pl:465 -crlf
# Po połączeniu wpisz:
EHLO test.example.com
QUIT
```

## Szybki test wszystkich portów (one-liner)
```bash
for port in 25 465 587 993; do
  echo -n "Port $port: "
  timeout 3 nc -zv mail.rapidmaker.pl $port 2>&1 | grep -q "succeeded\|open" && echo "✓ OPEN" || echo "✗ CLOSED/FILTERED"
done
```

## Oczekiwane wyniki
- **Port 25**: OPEN (przyjmowanie poczty z innych serwerów)
- **Port 465**: OPEN (SMTP przez SSL dla klientów)
- **Port 587**: OPEN (SMTP submission - głównie dla klientów)
- **Port 993**: OPEN (IMAP przez SSL - odbiór poczty)

## Jeśli port jest FILTERED
To znaczy że:
- ISP blokuje port (typowe dla portów email w sieciach domowych)
- Firewall na serwerze blokuje (ale już wyłączyliśmy)
- Hetzner Cloud Firewall blokuje
