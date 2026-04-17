### Welcome to QUIZTerm

This documentation is for building and running quizterm. You do not need to worry about this
document to be a user. It is a still in "initial draft", but should contain the needed
bits to start the webapp.

#### Getting env variables ready

An api-key, and a base16-encoded version of it is needed to communicate with the 
endpoints. You can use the sha256 command from the "hashalot" bundle or similar.
```
sha256 -x
Enter passphrase: 
```
The passphrase test will output
```
9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08
```

This is the value provided in "quizterm.env.example". Feel free to use this for "local
testing", copy the file to "quizterm.env". For non-local testing, pick a better API key...

The provided "init script" that sets up some "dummy examples" needs the non-hashed
version of the api-key, see the section "Running init script" after "Building and running"

#### Building and running

Docker, or a compatible container manager, like podman, is required to build and run
quizterm. The alternative is to install Gleam and Erlang/BEAM and run it dockerless.
Unless you plan to do Gleam development, using Docker will save a lot of hassle.

To build and start, in the project root folder, write 
```
docker compose build # can be skipped if image does not need rebuilding
docker compose up
```
You can now access quizterm on http://localhost:1234 (however you may want to run
the init script described in next section first). If you need a different port, modify 
docker-compose.yml, the number 1234 before the colon Note that it will always say
"listening on port 1234", this is the port used inside the docker image.

Stop quizterm with 

```
docker compose down
```

#### Running the init script

A provided init script sets up some bits for testing, it creates several "team rooms",
and generates questions and answers.

"Team X" will have pin code "PINX", so PINA for Team A, etc.

If you used the "default" values in quizterm.env, the api-key "test" will work with the
init script. If not, edit the api-test/init.sh file and set correct api-key (non-hashed).

```
sh api-test/init.sh
```

