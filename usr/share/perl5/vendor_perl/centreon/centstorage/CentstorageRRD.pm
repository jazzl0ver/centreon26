################################################################################
# Copyright 2005-2013 Centreon
# Centreon is developped by : Julien Mathis and Romain Le Merlus under
# GPL Licence 2.0.
# 
# This program is free software; you can redistribute it and/or modify it under 
# the terms of the GNU General Public License as published by the Free Software 
# Foundation ; either version 2 of the License.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along with 
# this program; if not, see <http://www.gnu.org/licenses>.
# 
# Linking this program statically or dynamically with other modules is making a 
# combined work based on this program. Thus, the terms and conditions of the GNU 
# General Public License cover the whole combination.
# 
# As a special exception, the copyright holders of this program give Centreon 
# permission to link this program with independent modules to produce an executable, 
# regardless of the license terms of these independent modules, and to copy and 
# distribute the resulting executable under terms of Centreon choice, provided that 
# Centreon also meet, for each linked independent module, the terms  and conditions 
# of the license of that module. An independent module is a module which is not 
# derived from this program. If you modify this program, you may extend this 
# exception to your version of the program, but you are not obliged to do so. If you
# do not wish to do so, delete this exception statement from your version.
# 
#
####################################################################################

use RRDs;
use strict;
use warnings;

package centreon::centstorage::CentstorageRRD;

my @rrd_dst = ("GAUGE","COUNTER","DERIVE","ABSOLUTE");

sub new {
    my $class = shift;
    my $self  = {};
    $self->{logger} = shift;
    $self->{metric_path} = undef;
    $self->{status_path} = undef;
    $self->{len_rrd} = undef;
    $self->{status_info} = {};
    $self->{metric_info} = {};
    # By metric_id
    $self->{rrdcache_metric_data} = {};
    $self->{rrdcache_status_data} = {};
    # Flush every n seconds: -1 = disable
    $self->{last_flush} = time();
    $self->{flush} = -1;
    $self->{cache_mode} = 0;
    bless $self, $class;
    return $self;
}

sub create_rrd_database {
    my $self = shift;
    my ($RRDdatabase_path, $metric_id, $begin, $interval, $metric_name, $my_len_storage_rrd, $data_source_type) = @_;

    $interval = $self->get_rrd_step($interval, 60, "RRD step for " . $metric_id);
    $my_len_storage_rrd = int($self->get_positive_number($my_len_storage_rrd, 1, "RRD row count for " . $metric_id));
    $my_len_storage_rrd = 1 if ($my_len_storage_rrd < 1);
    my $my_len_storage_rrd_12 = int($my_len_storage_rrd / 12);
    $my_len_storage_rrd_12 = 1 if ($my_len_storage_rrd_12 < 1);

    my $lsource_type;
    if (defined($data_source_type) && defined($rrd_dst[$data_source_type])) {
        $lsource_type = $rrd_dst[$data_source_type];
    } else {
        $lsource_type = $rrd_dst[0];
    }
    RRDs::create($RRDdatabase_path . "/" . $metric_id . ".rrd", "-b", $begin, "-s", $interval, "DS:" . substr($metric_name, 0, 19) . ":" . $lsource_type . ":".$interval.":U:U", "RRA:AVERAGE:0.5:1:".$my_len_storage_rrd, "RRA:AVERAGE:0.5:12:".$my_len_storage_rrd_12);
    my $ERR = RRDs::error;
    if ($ERR) {
        $self->{logger}->writeLogError("ERROR while creating " . $RRDdatabase_path.$metric_id . ".rrd : $ERR");
    } else {
        chmod 0664, "${RRDdatabase_path}/${metric_id}.rrd";
    }
}

sub tune_rrd_database {
    my $self = shift;
    my ($RRDdatabase_path, $metric_id ,$metric_name, $interval_hb) = @_;

    $interval_hb = $self->get_rrd_step($interval_hb, 600, "RRD heartbeat for " . $metric_id);
    RRDs::tune($RRDdatabase_path . "/" . $metric_id . ".rrd", "-h", substr($metric_name, 0, 19).":".$interval_hb);
    my $ERR = RRDs::error;
    if ($ERR) {
        $self->{logger}->writeLogError("ERROR while tunning operation on " . $RRDdatabase_path.$metric_id . ".rrd : $ERR");
    }
}

sub get_last_update {
    my $self = shift;
    my ($rrd_path_database, $id_db) = @_;
    my $last_time = -1;
    
    if (-e $rrd_path_database . '/' . $id_db . '.rrd') {
        $last_time = RRDs::last($rrd_path_database . '/' . $id_db . '.rrd');
        my $ERR = RRDs::error;
        if ($ERR) {
            $self->{'logger'}->writeLogError("ERROR while checking last time '" . $rrd_path_database . "/" . $id_db . ".rrd' $ERR");
            return -2;
        }
    }
    return $last_time;
}

sub get_positive_number {
    my $self = shift;
    my ($value, $default, $description) = @_;
    my $original = defined($value) ? $value : 'undef';

    $value = '' if (!defined($value));
    $value =~ s/^\s+//;
    $value =~ s/\s+$//;
    if ($value !~ /^[0-9]+(?:\.[0-9]+)?$/ || $value <= 0) {
        $self->{logger}->writeLogError("Invalid " . $description . " '" . $original . "', using " . $default) if (defined($self->{logger}));
        return $default;
    }

    return $value;
}

sub get_rrd_step {
    my $self = shift;
    my ($value, $default, $description) = @_;

    $value = $self->get_positive_number($value, $default, $description);
    if ($value < 1) {
        $self->{logger}->writeLogError("Invalid " . $description . " '" . $value . "', using " . $default) if (defined($self->{logger}));
        $value = $default;
    }

    return int($value);
}

sub get_rrd_row_count {
    my $self = shift;
    my ($retention, $interval, $description) = @_;

    $retention = $self->get_positive_number($retention, 86400, $description);
    my $rows = int($retention / $interval);
    $rows = 1 if ($rows < 1);

    return $rows;
}

sub use_default_retention {
    my $self = shift;
    my ($retention) = @_;

    return 1 if (!defined($retention));
    $retention =~ s/^\s+//;
    $retention =~ s/\s+$//;

    return $retention eq '' || $retention eq '-1';
}

sub metric_path {
    my $self = shift;

    if (@_) {
        $self->{metric_path} = shift;
    }
    return $self->{metric_path};
}

sub status_path {
    my $self = shift;

    if (@_) {
        $self->{status_path} = shift;
    }
    return $self->{status_path};
}

sub len_rrd {
    my $self = shift;

    if (@_) {
        $self->{len_rrd} = $self->get_positive_number(shift(), 180, "RRD retention") * 60 * 60 * 24;
    }
    return $self->{len_rrd};
}

sub flush {
    my $self = shift;

    if (@_) {
        $self->{flush} = shift;
    }
    return $self->{flush};
}

sub cache_mode {
    my $self = shift;

    if (@_) {
        $self->{cache_mode} = shift;
    }
    return $self->{cache_mode};
}

sub delete_rrd_metric {
    my $self = shift;
    my ($id) = @_;

    if (-e $self->{metric_path} . "/" . $id . ".rrd") {
        if (!unlink($self->{metric_path} . "/" . $id . ".rrd")) {
            $self->{logger}->writeLogError("Cannot delete rrd file " . $self->{metric_path} . "/" . $id . ".rrd");
            return -1;
        }
    }
    return 0;
}

sub delete_cache_metric {
    my $self = shift;
    my ($metric_id) = @_;

    if (defined($self->{metric_info}->{$metric_id})) {
        delete $self->{metric_info}->{$metric_id};
    }
    if (defined($self->{rrdcache_metric_data}->{$metric_id})) {
        delete $self->{rrdcache_metric_data}->{$metric_id};
    }
}

sub delete_cache_status {
    my $self = shift;
    my ($id) = @_;
    
    if (defined($self->{status_info}->{$id})) {
        delete $self->{status_info}->{$id};
    }
    if (defined($self->{rrdcache_status_data}->{$id})) {
        delete $self->{rrdcache_status_data}->{$id};
    }
}

sub add_metric {
    my $self = shift;
    my ($metric_id, $metric_name, $interval, $data_source_type, $timestamp, $value, $local_rrd_retention) = @_;

    $interval = $self->get_rrd_step($interval, 60, "RRD step for metric " . $metric_id);
    if (!defined($self->{metric_info}->{$metric_id})) {
        my $retention;
        if ($self->use_default_retention($local_rrd_retention)) {
            $retention = $self->{len_rrd};
        } else {
            $retention = $local_rrd_retention;
        }
        my $my_len_storage_rrd;
        $my_len_storage_rrd = $self->get_rrd_row_count($retention, $interval, "RRD retention for metric " . $metric_id);
        my $ltimestamp = $self->get_last_update($self->{metric_path}, $metric_id);
        return if ($ltimestamp == -2);
        $self->{metric_info}->{$metric_id} = {metric_name => 'value',
                            interval => $interval,
                            data_source_type => $data_source_type,
                            last_timestamp => $ltimestamp,
                            len_rrd => $my_len_storage_rrd};
        if ($self->{metric_info}->{$metric_id}->{last_timestamp} == -1) {
            my $interval_hb = $interval * 10;            

            $self->create_rrd_database($self->{metric_path}, $metric_id, $timestamp - 200, $interval,
                           'value', $my_len_storage_rrd, $data_source_type);
            $self->tune_rrd_database($self->{metric_path}, $metric_id, 'value', $interval_hb);
            $self->{metric_info}->{$metric_id}->{last_timestamp} = $timestamp - 200;
        }
    }

    return -1 if ($timestamp <= $self->{metric_info}->{$metric_id}->{last_timestamp} || $timestamp > (time() + 7200));
    $self->{rrdcache_metric_data}->{$metric_id} = [] if (!defined($self->{rrdcache_metric_data}->{$metric_id}));
    push @{$self->{rrdcache_metric_data}->{$metric_id}}, $timestamp . ":" . $value;
    $self->{metric_info}->{$metric_id}->{last_timestamp} = $timestamp;
}

sub add_status {
    my $self = shift;
    my ($index_id, $interval, $timestamp, $service_state, $local_rrd_retention) = @_;
    my $value;

    if ($service_state eq 'OK') {
        $value = 100;
    } elsif ($service_state eq 'WARNING') {
        $value = 75;
    } elsif ($service_state eq 'CRITICAL') {
        $value = 0;
    } else {
        # Don't do for 'UNKNOWN'
        return ;
    }
    $interval = $self->get_rrd_step($interval, 60, "RRD step for status " . $index_id);
    if (!defined($self->{status_info}->{$index_id})) {
        my $retention;
        if ($self->use_default_retention($local_rrd_retention)) {
            $retention = $self->{len_rrd};
        } else {
            $retention = $local_rrd_retention;
        }
        my $my_len_storage_rrd;
        $my_len_storage_rrd = $self->get_rrd_row_count($retention, $interval, "RRD retention for status " . $index_id);
        my $ltimestamp = $self->get_last_update($self->{status_path}, $index_id);
        return if ($ltimestamp == -2);
        $self->{status_info}->{$index_id} = {interval => $interval, 
                             last_timestamp => $ltimestamp,
                             values => [],
                             len_rrd => $my_len_storage_rrd};
        if ($self->{status_info}->{$index_id}->{last_timestamp} == -1) {
            my $interval_hb = $interval * 10;

            $self->create_rrd_database($self->{status_path}, $index_id, $timestamp - 200, $interval,
                           "value", $my_len_storage_rrd, 0);
            $self->tune_rrd_database($self->{status_path}, $index_id, "value", $interval_hb);
            $self->{status_info}->{$index_id}->{last_timestamp} = $timestamp - 200;
        }
    }

    return -1 if ($timestamp <= $self->{status_info}->{$index_id}->{last_timestamp} || $timestamp > (time() + 7200));
    $self->{rrdcache_status_data}->{$index_id} = [] if (!defined($self->{rrdcache_status_data}->{$index_id}));
    push @{$self->{rrdcache_status_data}->{$index_id}}, $timestamp . ":" . $value;
    $self->{status_info}->{$index_id}->{last_timestamp} = $timestamp;
}

sub flush_metric {
    my $self = shift;
    my ($metric_id) = @_;

    if (defined($self->{rrdcache_metric_data}->{$metric_id})) {
        RRDs::update($self->{metric_path} . "/" . $metric_id . ".rrd", @{$self->{rrdcache_metric_data}->{$metric_id}});
        my $ERR = RRDs::error;
        if ($ERR) {
            # Try to see if the file had been deleted
            if (! -e $self->{metric_path} . "/" . $metric_id . ".rrd") {
                my $my_len_storage_rrd = $self->{metric_info}->{$metric_id}->{len_rrd};
                my $interval_hb = $self->{metric_info}->{$metric_id}->{interval} * 10;

                $self->create_rrd_database($self->{metric_path}, $metric_id,
                               $self->{metric_info}->{$metric_id}->{last_timestamp} - 200, 
                               $self->{metric_info}->{$metric_id}->{interval},
                               'value', $my_len_storage_rrd,
                               $self->{metric_info}->{$metric_id}->{data_source_type});
                $self->tune_rrd_database($self->{metric_path}, $metric_id, 'value', $interval_hb);
            } else {
                $self->{logger}->writeLogError("ERROR while updating '" . $self->{metric_path} . "/" . $metric_id . ".rrd' $ERR");
            }
        }
        delete $self->{rrdcache_metric_data}->{$metric_id};
    }
}

sub flush_status {
    my $self = shift;
    my ($index_id) = @_;

    if (defined($self->{rrdcache_status_data}->{$index_id})) {
        RRDs::update($self->{status_path} . "/" . $index_id . ".rrd", @{$self->{rrdcache_status_data}->{$index_id}});
        my $ERR = RRDs::error;
        if ($ERR) {
            # Try to see if the file had been deleted
            if (! -e $self->{status_path} . "/" . $index_id . ".rrd") {
                my $my_len_storage_rrd = $self->{status_info}->{$index_id}->{len_rrd};
                my $interval_hb = $self->{status_info}->{$index_id}->{interval} * 10;

                $self->create_rrd_database($self->{status_path}, $index_id,
                               $self->{status_info}->{$index_id}->{last_timestamp} - 200, 
                               $self->{status_info}->{$index_id}->{interval},
                               "value", $my_len_storage_rrd,
                               0);
                $self->tune_rrd_database($self->{"status_path"}, $index_id, "value", $interval_hb);
            } else {
                $self->{logger}->writeLogError("ERROR while updating '" . $self->{status_path} . "/" . $index_id . ".rrd' $ERR");
            }
        }
        delete $self->{rrdcache_status_data}->{$index_id};
    }
}

sub flush_all {
    my $self = shift;
    my ($force) = @_;

    if ($self->{cache_mode} == 1 && (!defined($force) || $force == 0)) {
        return if (time() < ($self->{last_flush} + $self->{flush}));
        $self->{last_flush} = time();
        $self->{logger}->writeLogInfo("Flush Beginning");
    }
    ###
    # Metrics
    ###
    foreach my $metric_id (keys %{$self->{rrdcache_metric_data}}) {
        RRDs::update($self->{metric_path} . "/" . $metric_id . ".rrd", @{$self->{rrdcache_metric_data}->{$metric_id}});
        my $ERR = RRDs::error;
        if ($ERR) {
            # Try to see if the file had been deleted
            if (! -e $self->{metric_path} . "/" . $metric_id . ".rrd") {
                my $my_len_storage_rrd = $self->{metric_info}->{$metric_id}->{len_rrd};
                my $interval_hb = $self->{metric_info}->{$metric_id}->{interval} * 10;

                $self->create_rrd_database($self->{metric_path}, $metric_id,
                               $self->{metric_info}->{$metric_id}->{last_timestamp} - 200, 
                               $self->{metric_info}->{$metric_id}->{interval},
                               'value', $my_len_storage_rrd,
                               $self->{metric_info}->{$metric_id}->{data_source_type});
                $self->tune_rrd_database($self->{metric_path}, $metric_id, 'value', $interval_hb);
            } else {
                $self->{logger}->writeLogError("ERROR while updating '" . $self->{metric_path} . "/" . $metric_id . ".rrd' $ERR");
            }
        }
    }
    $self->{rrdcache_metric_data} = {};

    ###
    # Status
    ###
    foreach my $service_id (keys %{$self->{rrdcache_status_data}}) {
        RRDs::update($self->{status_path} . "/" . $service_id . ".rrd", @{$self->{rrdcache_status_data}->{$service_id}});
        my $ERR = RRDs::error;
        if ($ERR) {
            # Try to see if the file had been deleted
            if (! -e $self->{status_path} . "/" . $service_id . ".rrd") {
                my $my_len_storage_rrd = $self->{status_info}->{$service_id}->{len_rrd};
                my $interval_hb = $self->{status_info}->{$service_id}->{interval} * 10;

                $self->create_rrd_database($self->{status_path}, $service_id,
                               $self->{status_info}->{$service_id}->{last_timestamp} - 200, 
                               $self->{status_info}->{$service_id}->{interval},
                               "status", $my_len_storage_rrd,
                               0);
                $self->tune_rrd_database($self->{status_path}, $service_id, "status", $interval_hb);
            } else {
                $self->{logger}->writeLogError("ERROR while updating '" . $self->{status_path} . "/" . $service_id . ".rrd' $ERR");
            }
        }
    }
    $self->{rrdcache_status_data} = {};
    
    $self->{logger}->writeLogInfo("Flush Ending") if ($self->{cache_mode} == 1);
}

1;
