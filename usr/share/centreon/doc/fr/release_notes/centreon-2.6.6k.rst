===============
Centreon 2.6.6k
===============

Released May 21, 2026

******
Notice
******
This maintenance release keeps Centreon 2.6.6 as the historical base version and adds compatibility fixes for PHP 8 runtimes.


*********
CHANGELOG
*********

Bug fixes
=========

- Fixed PHP 8 fatal errors caused by legacy serialized Centreon session objects missing runtime services such as broker and GMT.
- Fixed PHP 8 warnings and type errors in monitoring, reporting, graph, configuration generation, ACL, widgets, and Smarty template paths.
- Fixed graph XML and image generation edge cases with missing RRD metadata and virtual metrics.
- Added tooling to adapt data-only MySQL dumps to the current Centreon, storage, and status schemas.
