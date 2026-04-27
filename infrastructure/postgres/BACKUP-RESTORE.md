# Backup and Restore

## Backup

CNPG continuously streams WAL to S3. Full base backups run every 24h.
Manual backup: kubectl cnpg backup postgres-ha -n postgres

## Restore

1. Create a new Cluster manifest referencing the backup
2. Set bootstrap.recovery.backup.name to the backup you want
3. Apply — CNPG restores automatically
4. Verify: kubectl exec into new primary, check data integrity

## Test restore monthly

Spin up a separate namespace, restore there, verify, then destroy.
