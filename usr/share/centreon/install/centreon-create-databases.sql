CREATE DATABASE IF NOT EXISTS centreon CHARACTER SET utf8;
CREATE DATABASE IF NOT EXISTS centreon_storage CHARACTER SET utf8;
CREATE DATABASE IF NOT EXISTS centreon_status CHARACTER SET utf8;
SET GLOBAL validate_password.policy = LOW;
CREATE USER 'centreon'@'localhost' IDENTIFIED BY '@CENTREON_DB_PASS@';
GRANT ALL PRIVILEGES ON centreon.* TO 'centreon'@'localhost';
GRANT ALL PRIVILEGES ON centreon_storage.* TO 'centreon'@'localhost';
GRANT ALL PRIVILEGES ON centreon_status.* TO 'centreon'@'localhost';
