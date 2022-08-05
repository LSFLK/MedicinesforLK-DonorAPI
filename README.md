## Medicines for LK - Donor API

The medicines LK app is comprised of a [React Frontend](https://github.com/LSFLK/MedicinesforLK), [Ballerina Donor API](https://github.com/LSFLK/MedicinesforLK-DonorAPI) and [Ballerina Admin API](https://github.com/LSFLK/MedicinesforLK-AdminAPI). 

### Development

- [Set up Ballerina](https://ballerina.io/learn/install-ballerina/set-up-ballerina/)
- Run a MySQL server and execute the script `mysql-scripts/creation-ddl.sql` [from the Admin API](https://github.com/LSFLK/MedicinesforLK-AdminAPI/blob/main/mysql-scripts/creation-ddl.sql) on it to bring up the DDL for the db. You need to have a `medicinesforlk` db in your MySQL server to set up the DDL in.
- Modify `config.bal` with the values for the MySQL server you set up. 
- `bal run` (runs the API on port 9090)
- Test the API http://localhost:9090/donor/aidpackages

### Run using Docker Compose

- Note that you will have to run `docker-compose` within the Admin API first to have the network and MySQL database available.
- `docker-compose up -d`
- Test the API http://localhost:9091/donor/aidpackages
