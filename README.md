# StuffTracker

**Stuff Tracker** is a project that helps small groups to keep track of "stuff" in a central location, instead of using spreadsheets.

Instalation instructions for Debian:

1. apt-get install git sqlite3 libdancer2-perl libdbi-perl libdbd-sqlite3-perl 
2. git clone --recursive https://github.com/zidmar/StuffTracker.git
3. cd StuffTracker
4. sqlite3 sqlite.db < sql/stuff_tracker-sqlite.sql
5. plackup -r -R lib bin/app.psgi
6. Connect with web browser to http://localhost:5000
