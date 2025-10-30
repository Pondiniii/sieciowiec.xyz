<?php

// Roundcube configuration for sieciowiec.xyz + rapidmaker.pl
// Database
$config['db_dsnw'] = 'sqlite:////var/lib/roundcube/database.db?mode=0644';

// Email IMAP/SMTP settings
$config['default_host'] = 'mailserver'; // Docker service name
$config['default_port'] = 993;           // IMAP port
$config['imap_conn_options'] = array(
    'ssl' => array('verify_peer' => false),
);

$config['smtp_host'] = 'mailserver';
$config['smtp_port'] = 587;
$config['smtp_conn_options'] = array(
    'ssl' => array('verify_peer' => false),
);

// Use IMAP LOGIN command instead of PLAIN
$config['imap_auth_type'] = 'LOGIN';
$config['smtp_auth_type'] = 'LOGIN';

// Session
$config['session_lifetime'] = 60;         // Minutes
$config['session_storage'] = 'db';        // Store in database

// UI
$config['language'] = 'en_US';
$config['timezone'] = 'Europe/Warsaw';
$config['spellcheck_engine'] = 'spell';

// Features
$config['enable_installer'] = false;      // IMPORTANT: Security!
$config['force_https'] = true;            // Force HTTPS
$config['support_url'] = '';              // Hide support link

// Plugins
$config['plugins'] = array(
    'archive',
    'markasjunk',
    'managesieve',
    'zipdownload',
    'vcard_attachments',
    'carddav',
    'password',
);

// Password plugin for Dovecot
$config['password_driver'] = 'dovecot';
$config['password_dovecot_method'] = 'SCRAM-SHA-256';
$config['password_dovecot_host'] = 'mailserver';
$config['password_dovecot_port'] = 24242;

// CardDAV
$config['carddav_url'] = 'http://mailserver:8008/caldav/';

// Allowed hosts (both domains)
$config['mail_domain'] = array(
    'sieciowiec.xyz' => array(
        'imap_host' => 'mailserver',
        'imap_port' => 993,
        'smtp_host' => 'mailserver',
        'smtp_port' => 587,
    ),
    'rapidmaker.pl' => array(
        'imap_host' => 'mailserver',
        'imap_port' => 993,
        'smtp_host' => 'mailserver',
        'smtp_port' => 587,
    ),
);

// Logging
$config['log_driver'] = 'syslog';
$config['syslog_facility'] = LOG_MAIL;

// Security headers
$config['x_frame_options'] = 'SAMEORIGIN';

// IMPORTANT: Set a secure DKIM_KEYS path (for DKIM if needed)
// Leave empty for now
$config['dkim_public_key'] = '';

?>
