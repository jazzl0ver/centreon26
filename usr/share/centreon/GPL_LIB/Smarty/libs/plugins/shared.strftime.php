<?php
/**
 * Smarty shared plugin
 * @package Smarty
 * @subpackage plugins
 */

/**
 * Function: smarty_strftime<br />
 * Purpose:  strftime-compatible formatting without using the deprecated PHP function.
 * @param string
 * @param integer|null
 * @return string
 */
function smarty_strftime($format, $timestamp = null)
{
    if ($timestamp === null) {
        $timestamp = time();
    } elseif (!is_numeric($timestamp)) {
        $timestamp = strtotime($timestamp);
        if ($timestamp === false) {
            $timestamp = time();
        }
    }

    $timestamp = (int)$timestamp;

    $_week_number = function($timestamp, $monday_first) {
        $year_start = mktime(0, 0, 0, 1, 1, date('Y', $timestamp));
        $year_start_weekday = (int)date('w', $year_start);
        $first_weekday = $monday_first ? 1 : 0;
        $offset = (7 + $first_weekday - $year_start_weekday) % 7;
        $day_of_year = (int)date('z', $timestamp);

        if ($day_of_year < $offset) {
            return '00';
        }

        return sprintf('%02d', floor(($day_of_year - $offset) / 7) + 1);
    };

    $iso_year = date('o', $timestamp);
    $year = date('Y', $timestamp);

    return strtr($format, array(
        '%%' => '%',
        '%a' => date('D', $timestamp),
        '%A' => date('l', $timestamp),
        '%d' => date('d', $timestamp),
        '%e' => sprintf('%2d', date('j', $timestamp)),
        '%j' => sprintf('%03d', date('z', $timestamp) + 1),
        '%u' => date('N', $timestamp),
        '%w' => date('w', $timestamp),
        '%U' => $_week_number($timestamp, false),
        '%V' => date('W', $timestamp),
        '%W' => $_week_number($timestamp, true),
        '%b' => date('M', $timestamp),
        '%B' => date('F', $timestamp),
        '%h' => date('M', $timestamp),
        '%m' => date('m', $timestamp),
        '%C' => sprintf('%02d', floor($year / 100)),
        '%g' => substr($iso_year, -2),
        '%G' => $iso_year,
        '%y' => date('y', $timestamp),
        '%Y' => $year,
        '%H' => date('H', $timestamp),
        '%k' => sprintf('%2d', date('G', $timestamp)),
        '%I' => date('h', $timestamp),
        '%l' => sprintf('%2d', date('g', $timestamp)),
        '%M' => date('i', $timestamp),
        '%p' => date('A', $timestamp),
        '%P' => date('a', $timestamp),
        '%r' => date('h:i:s A', $timestamp),
        '%R' => date('H:i', $timestamp),
        '%S' => date('s', $timestamp),
        '%T' => date('H:i:s', $timestamp),
        '%X' => date('H:i:s', $timestamp),
        '%z' => date('O', $timestamp),
        '%Z' => date('T', $timestamp),
        '%c' => date('D M j H:i:s Y', $timestamp),
        '%D' => date('m/d/y', $timestamp),
        '%F' => date('Y-m-d', $timestamp),
        '%s' => $timestamp,
        '%x' => date('m/d/y', $timestamp),
        '%n' => "\n",
        '%t' => "\t",
    ));
}

/* vim: set expandtab: */

?>
