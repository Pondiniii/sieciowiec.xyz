<?php
// Override SSL/TLS connection options for mailserver
// Roundcube tries to verify certificates, but mailserver is accessed by hostname "mailserver"
// which doesn't match the certificate (cert is for mail.rapidmaker.pl / mail.sieciowiec.xyz)

$config['imap_conn_options'] = array(
    'ssl' => array(
        'verify_peer' => false,
        'verify_peer_name' => false,
        'allow_self_signed' => true,
    ),
);

$config['smtp_conn_options'] = array(
    'tls' => array(
        'verify_peer' => false,
        'verify_peer_name' => false,
        'allow_self_signed' => true,
    ),
);
?>
