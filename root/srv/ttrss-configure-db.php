#!/usr/bin/env php
<?php

include '/srv/ttrss-utils.php';

$confpath = env('TTRSS_PATH', '/var/www/ttrss');
$conffile = $confpath . '/config.php';

echo 'Configuring database for: ' . $conffile . PHP_EOL;

$config = resolve_db_config();

if (!dbcheck($config)) {
    echo 'Database login failed, trying to create ...' . PHP_EOL;

    $super_users = array_unique(array(
        env('DB_ENV_USER', env('POSTGRES_USER', 'postgres')),
        'docker'
    ));

    $created = false;
    foreach ($super_users as $su) {
        $super = $config;
        $super['DB_NAME'] = ($config['DB_TYPE'] === 'pgsql') ? 'postgres' : '';
        $super['DB_USER'] = $su;
        $super['DB_PASS'] = env('DB_ENV_PASS', env('POSTGRES_PASSWORD', $su));

        try {
            $pdo = dbconnect($super);
            if ($config['DB_TYPE'] === 'pgsql') {
                try {
                    $pdo->exec('CREATE ROLE ' . ($config['DB_USER']) . ' WITH LOGIN PASSWORD ' . $pdo->quote($config['DB_PASS']));
                } catch (PDOException $e) {
                    // Role may already exist
                }
                try {
                    $pdo->exec('CREATE DATABASE ' . ($config['DB_NAME']) . ' WITH OWNER ' . ($config['DB_USER']));
                } catch (PDOException $e) {
                    // Database may already exist
                }
                try {
                    $pdo_db = $super;
                    $pdo_db['DB_NAME'] = $config['DB_NAME'];
                    $pdo_ext = dbconnect($pdo_db);
                    $pdo_ext->exec('CREATE EXTENSION IF NOT EXISTS pg_trgm');
                    unset($pdo_ext);
                } catch (PDOException $e) {
                    // Ignore extension failure here
                }
            } else {
                $pdo->exec("CREATE USER IF NOT EXISTS '" . $config['DB_USER'] . "'@'%' IDENTIFIED BY " . $pdo->quote($config['DB_PASS']));
                $pdo->exec('CREATE DATABASE IF NOT EXISTS `' . $config['DB_NAME'] . '`');
                $pdo->exec('GRANT ALL PRIVILEGES ON `' . $config['DB_NAME'] . "`.* TO '" . $config['DB_USER'] . "'@'%'");
            }
            unset($pdo);
            if (dbcheck($config)) {
                $created = true;
                break;
            }
        } catch (PDOException $e) {
            // Try next superuser candidate
        }
    }

    if ($created || dbcheck($config)) {
        echo 'Database login created and confirmed' . PHP_EOL;
    } else {
        error('Database login failed, trying to create login failed as well');
    }
}

$contents = file_get_contents($conffile);
foreach ($config as $name => $value) {
    $contents .= "putenv('TTRSS_" . $name . "=" . $value . "');\n";
}
file_put_contents($conffile, $contents);

$pdo = dbconnect($config);
if ($config['DB_TYPE'] === 'pgsql') {
    try {
        $pdo->exec('CREATE EXTENSION IF NOT EXISTS pg_trgm');
    } catch (PDOException $e) {
        // Ignore if extension already exists and user lacks superuser privilege
    }
}

try {
    $pdo->query('SELECT 1 FROM ttrss_feeds');
    echo 'Connection to database successful' . PHP_EOL;

    $theme_reset = env('TTRSS_THEME_RESET', '0');
    if ($theme_reset === '1' || strtolower($theme_reset) === 'true') {
        echo 'Resetting theme to default ...' . PHP_EOL;
        try {
            $pdo->query("UPDATE ttrss_user_prefs2 SET value = '' WHERE pref_name = 'USER_CSS_THEME'");
        } catch (PDOException $e) {
            $pdo->query("UPDATE ttrss_user_prefs SET value = '' WHERE pref_name = 'USER_CSS_THEME'");
        }
    }
}
catch (PDOException $e) {
    $legacy_schema_file = $confpath . '/schema/ttrss_schema_' . $config['DB_TYPE'] . '.sql';
    $modern_schema_file = $confpath . '/sql/pgsql/schema.sql';

    if (!file_exists($modern_schema_file) && file_exists($legacy_schema_file)) {
        echo 'Database table not found, applying legacy schema... ' . PHP_EOL;
        $schema = file_get_contents($legacy_schema_file);
        $schema = preg_replace('/--(.*?);/', '', $schema);
        $schema = preg_replace('/[\r\n]/', ' ', $schema);
        $schema = trim($schema, ' ;');
        foreach (explode(';', $schema) as $stm) {
            if (trim($stm) !== '') {
                $pdo->exec($stm);
            }
        }
    } else {
        echo 'Database table not found, schema will be initialized by update.php...' . PHP_EOL;
    }
    unset($pdo);
}
