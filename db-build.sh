#!/usr/bin/zsh
#
# psql -h localhost -U myuser -d mydb -p 5400
# create table admin(name VARCHAR(200), token VARCHAR(200));
#
# podman run -d --replace --name postgres-db -e POSTGRES_DB=mydb -e POSTGRES_USER=myuser -e POSTGRES_PASSWORD=mypassword -p 5400:5432 postgres

export PGUSER=myuser
export PGPASSWORD=mypassword
export PGDATABASE=mydb
export PGPORT=5400

gleam run -m squirrel
