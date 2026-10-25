#!/usr/bin/env php
<?php

include '/srv/ttrss-utils.php';

$config = resolve_db_config();
$db_type = $config['DB_TYPE'];

$pdo = dbconnect($config);
try {
    $pdo->query('SELECT 1 FROM plugin_mobilize_feeds');
    // reached this point => table found, assume db is complete
}
catch (PDOException $e) {
    echo 'Database table for mobilize plugin not found, applying schema... ' . PHP_EOL;
    $schema = file_get_contents('/srv/ttrss-plugin-mobilize.' . $db_type);
    $schema = preg_replace('/--(.*?);/', '', $schema);
    $schema = preg_replace('/[\r\n]/', ' ', $schema);
    $schema = trim($schema, ' ;');
    foreach (explode(';', $schema) as $stm) {
        if (trim($stm) !== '') {
            $pdo->exec($stm);
        }
    }
    unset($pdo);
}
