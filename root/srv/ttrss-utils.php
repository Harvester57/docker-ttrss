<?php

function env($name, $default = null)
{
    $v = getenv($name);
    if ($v === false || $v === '') {
        $v = $default;
    }

    if ($v === null) {
        error('The env ' . $name . ' does not exist');
    }

    return $v;
}

function error($text)
{
    echo 'Error: ' . $text . PHP_EOL;
    exit(1);
}

function resolve_db_config()
{
    $ename = 'DB';
    $db_type = env('DB_TYPE', env('TTRSS_DB_TYPE', 'pgsql'));
    $eport = ($db_type == 'mysql') ? 3306 : 5432;

    $host = env('DB_HOST', env('TTRSS_DB_HOST', env($ename . '_PORT_' . $eport . '_TCP_ADDR', 'db')));
    $raw_port = env($ename . '_PORT_' . $eport . '_TCP_PORT', env('TTRSS_DB_PORT', env('DB_PORT', (string)$eport)));

    if (strpos($raw_port, 'tcp://') === 0) {
        $parts = parse_url($raw_port);
        $port = isset($parts['port']) ? (string)$parts['port'] : (string)$eport;
        if (($host === 'db' || !$host) && !empty($parts['host'])) {
            $host = $parts['host'];
        }
    } else {
        $port = $raw_port;
    }

    $config = array();
    $config['DB_TYPE'] = $db_type;
    $config['DB_HOST'] = $host;
    $config['DB_PORT'] = $port;
    $config['DB_NAME'] = env($ename . '_NAME', env('TTRSS_DB_NAME', 'ttrss'));
    $config['DB_USER'] = env($ename . '_USER', env('TTRSS_DB_USER', $config['DB_NAME']));
    $config['DB_PASS'] = env($ename . '_PASS', env('TTRSS_DB_PASS', $config['DB_USER']));

    return $config;
}

function dbconnect($config)
{
    $map = array('host' => 'HOST', 'port' => 'PORT', 'dbname' => 'NAME', 'user' => 'USER', 'password' => 'PASS');
    $dsn = $config['DB_TYPE'] . ':';
    foreach ($map as $d => $h) {
        if (isset($config['DB_' . $h]) && $config['DB_' . $h] !== null && $config['DB_' . $h] !== '') {
            $dsn .= $d . '=' . $config['DB_' . $h] . ';';
        }
    }
    if ($config['DB_TYPE'] == 'pgsql') {
        $pdo = new \PDO($dsn);
    } else {
        $pdo = new \PDO($dsn, $config['DB_USER'], $config['DB_PASS']);
    }
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    return $pdo;
}

function dbcheck($config)
{
    try {
        dbconnect($config);
        return true;
    }
    catch (PDOException $e) {
        return false;
    }
}

?>
