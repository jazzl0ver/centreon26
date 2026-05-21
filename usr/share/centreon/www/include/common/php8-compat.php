<?php
/*
 * Compatibility helpers for legacy Centreon code running on PHP 8+.
 */

if (!defined('DB_FETCHMODE_ORDERED')) {
    define('DB_FETCHMODE_ORDERED', 1);
}
if (!defined('DB_FETCHMODE_ASSOC')) {
    define('DB_FETCHMODE_ASSOC', 2);
}
if (!defined('DB_FETCHMODE_OBJECT')) {
    define('DB_FETCHMODE_OBJECT', 3);
}

if (!function_exists('centreon_php8_compat_pattern')) {
    function centreon_php8_compat_pattern($pattern, $caseInsensitive = false)
    {
        $pattern = str_replace('~', '\\~', $pattern);
        $pattern = preg_replace('/\\\\([A-Za-z])/', '$1', $pattern);

        return '~' . $pattern . '~' . ($caseInsensitive ? 'i' : '');
    }
}

if (!function_exists('split')) {
    function split($pattern, $string, $limit = -1)
    {
        $result = @preg_split(centreon_php8_compat_pattern($pattern), $string, $limit);
        if ($result !== false) {
            return $result;
        }

        return explode($pattern, $string, $limit > 0 ? $limit : PHP_INT_MAX);
    }
}

if (!function_exists('each')) {
    function each(&$array)
    {
        $key = key($array);
        if ($key === null) {
            return false;
        }

        $value = current($array);
        next($array);

        return array(1 => $value, 'value' => $value, 0 => $key, 'key' => $key);
    }
}

if (!function_exists('ereg')) {
    function ereg($pattern, $string, &$regs = null)
    {
        $matches = array();
        $result = @preg_match(centreon_php8_compat_pattern($pattern), $string, $matches);
        if ($result === false) {
            return false;
        }
        if ($result && func_num_args() >= 3) {
            $regs = $matches;
        }

        return $result;
    }
}

if (!function_exists('eregi')) {
    function eregi($pattern, $string, &$regs = null)
    {
        $matches = array();
        $result = @preg_match(centreon_php8_compat_pattern($pattern, true), $string, $matches);
        if ($result === false) {
            return false;
        }
        if ($result && func_num_args() >= 3) {
            $regs = $matches;
        }

        return $result;
    }
}

if (!function_exists('ereg_replace')) {
    function ereg_replace($pattern, $replacement, $string)
    {
        $result = @preg_replace(centreon_php8_compat_pattern($pattern), $replacement, $string);

        return $result === null ? $string : $result;
    }
}

if (!function_exists('eregi_replace')) {
    function eregi_replace($pattern, $replacement, $string)
    {
        $result = @preg_replace(centreon_php8_compat_pattern($pattern, true), $replacement, $string);

        return $result === null ? $string : $result;
    }
}

if (!function_exists('create_function')) {
    function create_function($args, $code)
    {
        return eval('return function(' . $args . ') {' . $code . '};');
    }
}

if (function_exists('mysqli_report')) {
    mysqli_report(MYSQLI_REPORT_OFF);
}

if (!isset($GLOBALS['_centreon_php8_mysql_link'])) {
    $GLOBALS['_centreon_php8_mysql_link'] = null;
}
if (!isset($GLOBALS['_centreon_php8_mysql_error'])) {
    $GLOBALS['_centreon_php8_mysql_error'] = '';
}

if (!function_exists('centreon_php8_mysql_parse_server')) {
    function centreon_php8_mysql_parse_server($server)
    {
        $host = $server ?: 'localhost';
        $port = ini_get('mysqli.default_port') ?: 3306;
        $socket = null;

        if (strpos($host, ':/') !== false) {
            list($host, $socket) = explode(':', $host, 2);
        } elseif (strpos($host, ':') !== false) {
            list($host, $port) = explode(':', $host, 2);
        }

        return array($host, (int) $port, $socket);
    }
}

if (!function_exists('centreon_php8_mysql_set_error')) {
    function centreon_php8_mysql_set_error($link = null)
    {
        if ($link instanceof mysqli) {
            $GLOBALS['_centreon_php8_mysql_error'] = mysqli_error($link);
        } elseif (mysqli_connect_errno()) {
            $GLOBALS['_centreon_php8_mysql_error'] = mysqli_connect_error();
        }
    }
}

if (!function_exists('centreon_php8_mysql_link')) {
    function centreon_php8_mysql_link($link = null)
    {
        if ($link instanceof mysqli) {
            return $link;
        }

        return $GLOBALS['_centreon_php8_mysql_link'];
    }
}

if (!function_exists('mysql_connect')) {
    function mysql_connect($server = 'localhost', $username = null, $password = null, $newLink = false, $clientFlags = 0)
    {
        list($host, $port, $socket) = centreon_php8_mysql_parse_server($server);
        $link = mysqli_connect($host, $username, $password, null, $port, $socket);
        if (!$link) {
            centreon_php8_mysql_set_error();
            return false;
        }

        mysqli_set_charset($link, 'utf8');
        $GLOBALS['_centreon_php8_mysql_link'] = $link;
        $GLOBALS['_centreon_php8_mysql_error'] = '';

        return $link;
    }
}

if (!function_exists('mysql_pconnect')) {
    function mysql_pconnect($server = 'localhost', $username = null, $password = null, $clientFlags = 0)
    {
        return mysql_connect($server, $username, $password, false, $clientFlags);
    }
}

if (!function_exists('mysql_query')) {
    function mysql_query($query, $linkIdentifier = null)
    {
        $link = centreon_php8_mysql_link($linkIdentifier);
        if (!$link) {
            $GLOBALS['_centreon_php8_mysql_error'] = 'No MySQL connection';
            return false;
        }

        $result = mysqli_query($link, $query);
        if ($result === false) {
            centreon_php8_mysql_set_error($link);
        } else {
            $GLOBALS['_centreon_php8_mysql_error'] = '';
        }

        return $result;
    }
}

if (!function_exists('mysql_error')) {
    function mysql_error($linkIdentifier = null)
    {
        $link = centreon_php8_mysql_link($linkIdentifier);
        if ($link) {
            $error = mysqli_error($link);
            if ($error !== '') {
                return $error;
            }
        }

        return $GLOBALS['_centreon_php8_mysql_error'];
    }
}

if (!function_exists('mysql_select_db')) {
    function mysql_select_db($databaseName, $linkIdentifier = null)
    {
        $link = centreon_php8_mysql_link($linkIdentifier);
        if (!$link) {
            $GLOBALS['_centreon_php8_mysql_error'] = 'No MySQL connection';
            return false;
        }

        $result = mysqli_select_db($link, $databaseName);
        if (!$result) {
            centreon_php8_mysql_set_error($link);
        }

        return $result;
    }
}

if (!function_exists('mysql_fetch_assoc')) {
    function mysql_fetch_assoc($result)
    {
        return $result instanceof mysqli_result ? mysqli_fetch_assoc($result) : false;
    }
}

if (!function_exists('mysql_free_result')) {
    function mysql_free_result($result)
    {
        if ($result instanceof mysqli_result) {
            mysqli_free_result($result);
            return true;
        }

        return false;
    }
}

if (!function_exists('mysql_close')) {
    function mysql_close($linkIdentifier = null)
    {
        $link = centreon_php8_mysql_link($linkIdentifier);
        if (!$link) {
            return false;
        }

        $result = mysqli_close($link);
        if ($result && $GLOBALS['_centreon_php8_mysql_link'] === $link) {
            $GLOBALS['_centreon_php8_mysql_link'] = null;
        }

        return $result;
    }
}

if (!function_exists('mysql_real_escape_string')) {
    function mysql_real_escape_string($unescapedString, $linkIdentifier = null)
    {
        $link = centreon_php8_mysql_link($linkIdentifier);
        if ($link) {
            return mysqli_real_escape_string($link, $unescapedString);
        }

        return addslashes($unescapedString);
    }
}

if (!function_exists('mysql_num_rows')) {
    function mysql_num_rows($result)
    {
        return $result instanceof mysqli_result ? mysqli_num_rows($result) : false;
    }
}

if (!function_exists('mysql_insert_id')) {
    function mysql_insert_id($linkIdentifier = null)
    {
        $link = centreon_php8_mysql_link($linkIdentifier);

        return $link ? mysqli_insert_id($link) : false;
    }
}

if (!function_exists('mysql_affected_rows')) {
    function mysql_affected_rows($linkIdentifier = null)
    {
        $link = centreon_php8_mysql_link($linkIdentifier);

        return $link ? mysqli_affected_rows($link) : false;
    }
}

if (!class_exists('PEAR', false)) {
    $pearFile = stream_resolve_include_path('PEAR.php');
    if ($pearFile !== false) {
        require_once $pearFile;
    }
}

if (!class_exists('PEAR', false)) {
    class PEAR
    {
        public static function isError($data, $code = null)
        {
            return $data instanceof PEAR_Error;
        }
    }
}

if (!class_exists('PEAR_Error', false)) {
    class PEAR_Error
    {
        protected $message;

        public function __construct($message = '')
        {
            $this->message = $message;
        }

        public function getMessage()
        {
            return $this->message;
        }

        public function getDebugInfo()
        {
            return $this->message;
        }
    }
}
