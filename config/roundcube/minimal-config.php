<?php
// Roundcube minimal config for docker-mailserver
$config = array();

// Database
$config['db_dsnw'] = 'sqlite:////var/lib/roundcube/db.sqlite?mode=0644';

// IMAP
$config['default_host'] = 'mailserver';
$config['default_port'] = 993;
$config['imap_conn_options'] = array('ssl' => array('verify_peer' => false));

// SMTP
$config['smtp_host'] = 'mailserver';
$config['smtp_port'] = 587;
$config['smtp_conn_options'] = array('tls' => array('verify_peer' => false));

// Session
$config['session_lifetime'] = 60;
$config['session_storage'] = 'db';

// UI
$config['language'] = 'en_US';
$config['timezone'] = 'UTC';
$config['force_https'] = true;
$config['enable_installer'] = false;

// Plugins
$config['plugins'] = array('archive', 'zipdownload');

?>
