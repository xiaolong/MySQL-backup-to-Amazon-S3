#!/bin/sh

# Updates etc at: https://github.com/woxxy/MySQL-backup-to-Amazon-S3
# Under a MIT license

# change these variables to what you need
MYSQLROOT=rpacep
MYSQLPASS=25fasiuz
S3BUCKET=epochbackup

# the following line prefixes the backups with the defined directory. it must be blank or end with a /
S3PATH=mysql_backup/

# when running via cron, the PATHs MIGHT be different. If you have a custom/manual MYSQL install, you should set this manually like MYSQLDUMPPATH=/usr/local/mysql/bin/
MYSQLDUMPPATH=
#tmp path.
TMP_PATH=/home/rpacep/research/mysqlBackup/

DATESTAMP=$(date +".%m.%d.%Y")
DAY=$(date +"%d")
DAYOFWEEK=$(date +"%A")

PERIOD=${1-day}
if [ ${PERIOD} = "auto" ]; then
	if [ ${DAY} = "01" ]; then
        	PERIOD=month
	elif [ ${DAYOFWEEK} = "Sunday" ]; then
        	PERIOD=week
	else
       		PERIOD=day
	fi	
fi

echo "Selected period: $PERIOD."
echo "Starting backing up databases..."

# dump databases
${MYSQLDUMPPATH}mysqldump --single-transaction --user=${MYSQLROOT} --password=${MYSQLPASS} chinagames > ${TMP_PATH}chinagames_dump.sql
${MYSQLDUMPPATH}mysqldump --single-transaction --user=${MYSQLROOT} --password=${MYSQLPASS} tracker > ${TMP_PATH}tracker_dump.sql

echo "Done backing up databases."
echo "Starting compression..."

tar czf ${TMP_PATH}chinagames_dump${DATESTAMP}.tar.gz ${TMP_PATH}chinagames_dump.sql
tar czf ${TMP_PATH}tracker_dump${DATESTAMP}.tar.gz ${TMP_PATH}tracker_dump.sql

echo "Done compressing the backup files."

# we want at least two backups, two months, two weeks, and two days
echo "Removing old backup (2 ${PERIOD}s ago)..."
s3cmd del --recursive s3://${S3BUCKET}/${S3PATH}previous_${PERIOD}/
echo "Old backup removed."

echo "Moving the backup from past $PERIOD to another folder..."
s3cmd mv --recursive s3://${S3BUCKET}/${S3PATH}${PERIOD}/ s3://${S3BUCKET}/${S3PATH}previous_${PERIOD}/
echo "Past backup moved."

# upload all databases
echo "Uploading the new backup..."
s3cmd put -f ${TMP_PATH}chinagames_dump${DATESTAMP}.tar.gz s3://${S3BUCKET}/${S3PATH}${PERIOD}/
s3cmd put -f ${TMP_PATH}tracker_dump${DATESTAMP}.tar.gz s3://${S3BUCKET}/${S3PATH}${PERIOD}/

echo "New backup uploaded."

echo "Removing the cache files..."
rm ${TMP_PATH}chinagames_dump${DATESTAMP}.tar.gz
rm ${TMP_PATH}tracker_dump${DATESTAMP}.tar.gz

echo "All done."
