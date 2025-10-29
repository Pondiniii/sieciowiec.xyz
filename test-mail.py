#!/usr/bin/env python3
"""
Mail server test script - IMAP/SMTP connection tester
Automatyczne testowanie połączeń email dla debugging
"""

import imaplib
import smtplib
import ssl
from email.mime.text import MIMEText
import sys

# Konfiguracja
ACCOUNTS = [
    {
        'email': 'jakub.pondo@sieciowiec.xyz',
        'password': 'ATUak~w%$7Ct4iUiz&AE',
        'name': 'Sieciowiec'
    },
    {
        'email': 'rapidmaker@rapidmaker.pl',
        'password': '4OLPsusZDam8H27xHLzh9Sy2qQYwCGWt0AcLBgNjMqZHFBDHlDZF',
        'name': 'RapidMaker'
    }
]

# Use mail server hostname (has valid SSL cert)
IMAP_SERVER = 'mail.rapidmaker.pl'
IMAP_PORT = 993
SMTP_SERVER = 'mail.rapidmaker.pl'
SMTP_PORT = 587

def test_imap(email, password, name):
    """Test IMAP connection"""
    print(f"\n{'='*60}")
    print(f"Testing IMAP for {name} ({email})")
    print(f"{'='*60}")

    try:
        print(f"Connecting to {IMAP_SERVER}:{IMAP_PORT}...")
        context = ssl.create_default_context()

        # Połącz przez SSL
        imap = imaplib.IMAP4_SSL(IMAP_SERVER, IMAP_PORT, ssl_context=context)
        print(f"✅ SSL connection established")

        # Login
        print(f"Logging in as {email}...")
        imap.login(email, password)
        print(f"✅ Login successful!")

        # Sprawdź foldery
        print(f"Listing mailboxes...")
        status, folders = imap.list()
        if status == 'OK':
            print(f"✅ Found {len(folders)} mailboxes:")
            for folder in folders[:5]:  # Pokaż pierwsze 5
                print(f"   - {folder.decode()}")

        # Sprawdź INBOX
        print(f"Selecting INBOX...")
        status, messages = imap.select('INBOX')
        if status == 'OK':
            num_messages = int(messages[0])
            print(f"✅ INBOX has {num_messages} messages")

        # Logout
        imap.logout()
        print(f"✅ IMAP test PASSED for {name}")
        return True

    except imaplib.IMAP4.error as e:
        print(f"❌ IMAP authentication error: {e}")
        return False
    except ssl.SSLError as e:
        print(f"❌ SSL error: {e}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {type(e).__name__}: {e}")
        return False

def test_smtp(email, password, name):
    """Test SMTP connection"""
    print(f"\n{'='*60}")
    print(f"Testing SMTP for {name} ({email})")
    print(f"{'='*60}")

    try:
        print(f"Connecting to {SMTP_SERVER}:{SMTP_PORT}...")

        # Połącz przez STARTTLS
        smtp = smtplib.SMTP(SMTP_SERVER, SMTP_PORT, timeout=10)
        print(f"✅ Connection established")

        # Start TLS
        print(f"Starting TLS...")
        context = ssl.create_default_context()
        smtp.starttls(context=context)
        print(f"✅ TLS enabled")

        # Login
        print(f"Logging in as {email}...")
        smtp.login(email, password)
        print(f"✅ Login successful!")

        # Test send (do samego siebie)
        print(f"Testing send capability (dry-run)...")
        msg = MIMEText("Test message from mail-test script")
        msg['Subject'] = 'Test from mail-test.py'
        msg['From'] = email
        msg['To'] = email

        # Nie wysyłamy naprawdę, tylko sprawdzamy czy możemy
        print(f"✅ Message prepared (not sent)")

        # Logout
        smtp.quit()
        print(f"✅ SMTP test PASSED for {name}")
        return True

    except smtplib.SMTPAuthenticationError as e:
        print(f"❌ SMTP authentication error: {e}")
        return False
    except smtplib.SMTPException as e:
        print(f"❌ SMTP error: {e}")
        return False
    except ssl.SSLError as e:
        print(f"❌ SSL error: {e}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {type(e).__name__}: {e}")
        return False

def main():
    print("""
    ╔════════════════════════════════════════════════════════════╗
    ║   Mail Server Connection Tester                            ║
    ║   Sieciowiec VPS - mail.rapidmaker.pl                      ║
    ╚════════════════════════════════════════════════════════════╝
    """)

    results = {
        'imap': [],
        'smtp': []
    }

    # Test wszystkich kont
    for account in ACCOUNTS:
        # Test IMAP
        imap_ok = test_imap(
            account['email'],
            account['password'],
            account['name']
        )
        results['imap'].append((account['name'], imap_ok))

        # Test SMTP
        smtp_ok = test_smtp(
            account['email'],
            account['password'],
            account['name']
        )
        results['smtp'].append((account['name'], smtp_ok))

    # Podsumowanie
    print(f"\n{'='*60}")
    print("SUMMARY")
    print(f"{'='*60}")

    print("\nIMAP Results:")
    for name, ok in results['imap']:
        status = "✅ PASS" if ok else "❌ FAIL"
        print(f"  {name:20} {status}")

    print("\nSMTP Results:")
    for name, ok in results['smtp']:
        status = "✅ PASS" if ok else "❌ FAIL"
        print(f"  {name:20} {status}")

    # Exit code
    all_passed = all(ok for _, ok in results['imap'] + results['smtp'])

    if all_passed:
        print(f"\n{'='*60}")
        print("🎉 ALL TESTS PASSED!")
        print(f"{'='*60}\n")
        sys.exit(0)
    else:
        print(f"\n{'='*60}")
        print("❌ SOME TESTS FAILED - Check logs above")
        print(f"{'='*60}\n")
        sys.exit(1)

if __name__ == '__main__':
    main()
