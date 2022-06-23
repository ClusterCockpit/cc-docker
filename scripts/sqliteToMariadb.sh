#!/bin/bash

echo "Will run prerequisites 'apt install python3-pip' and 'pip install sqlite3-to-mysql'"

sudo apt install python3-pip

pip install sqlite3-to-mysql

echo "'sqlite3mysql' requires running DB container, will fail otherwise."

# -f FILE -d DBNAME -u USER -h HOST -P PORT
~/.local/bin/sqlite3mysql -f job.db -d ClusterCockpit -u root --mysql-password root -h localhost -P 3306
