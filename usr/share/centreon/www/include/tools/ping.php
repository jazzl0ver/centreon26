<?php
/*
 * Copyright 2005-2015 Centreon
 * Centreon is developped by : Julien Mathis and Romain Le Merlus under
 * GPL Licence 2.0.
 * 
 * This program is free software; you can redistribute it and/or modify it under 
 * the terms of the GNU General Public License as published by the Free Software 
 * Foundation ; either version 2 of the License.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
 * PARTICULAR PURPOSE. See the GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along with 
 * this program; if not, see <http://www.gnu.org/licenses>.
 * 
 * Linking this program statically or dynamically with other modules is making a 
 * combined work based on this program. Thus, the terms and conditions of the GNU 
 * General Public License cover the whole combination.
 * 
 * As a special exception, the copyright holders of this program give Centreon 
 * permission to link this program with independent modules to produce an executable, 
 * regardless of the license terms of these independent modules, and to copy and 
 * distribute the resulting executable under terms of Centreon choice, provided that 
 * Centreon also meet, for each linked independent module, the terms  and conditions 
 * of the license of that module. An independent module is a module which is not 
 * derived from this program. If you modify this program, you may extend this 
 * exception to your version of the program, but you are not obliged to do so. If you
 * do not wish to do so, delete this exception statement from your version.
 * 
 * For more information : contact@centreon.com
 * 
 * SVN : $URL$
 * SVN : $Id$
 * 
 */
	
	include("/etc/centreon/centreon.conf.php");
	require_once ("../../$classdir/centreonSession.class.php");
	require_once ("../../$classdir/centreon.class.php");

	CentreonSession::start();
	
	if (!isset($_SESSION["centreon"])) {
		// Quick dirty protection
	 	header("Location: ../../index.php");
		exit;
	} else {
	 	$centreon = $_SESSION["centreon"];
	}
	 
    $host = $_GET["host"] ?? $_POST["host"] ?? null;
    if (!is_string($host) || strlen($host) > 253 ||
        (!filter_var($host, FILTER_VALIDATE_IP) &&
         !preg_match('/\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)*\.?\z/i', $host))) {
        print "Bad Request !";
        exit;
    }

    $pingBinary = null;
    foreach (array('/usr/bin/ping', '/bin/ping') as $candidate) {
        if (is_executable($candidate)) {
            $pingBinary = $candidate;
            break;
        }
    }
    if ($pingBinary === null || !is_callable('exec')) {
        print "Ping is unavailable: the ping executable and PHP exec support are required.";
        exit;
    }

    // Bound the probe duration and pass the destination as a single shell argument.
    $output = array();
    exec($pingBinary . ' -n -c 4 -w 10 -- ' . escapeshellarg($host) . ' 2>&1', $output, $status);
    foreach ($output as $line) {
        print htmlspecialchars($line, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8') . "<br />";
    }
    if (!$output && $status !== 0) {
        print "Unable to execute ping.";
    }

?>
