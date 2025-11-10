## QuizTerm

Simple multi-client app for answering quiz questions together, rather unfinished & unpolished version,
but it works...

#### Testing the code by compile / run

It isn't always easy to find a pre-built Erlang for every system at a version that is required for new
versions of gleam, but you can easily snatch them for linux from a docker image (see Dockerfile),
alternatively you can use distrobox / toolbox to create an env using the docker image, and have everything
set up "out of the box".

To setup a distrobox container for development, use:

``distrobox create -i ghcr.io/gleam-lang/gleam:v1.12.0-erlang-alpine -n gleamdev``

and to enter the distrobox container:

``distrobox enter gleamdev``

Nativate to the folder with the gleam.toml file and type

``gleam run``

The server should then be reachable on http://localhost:1234

#### Testing the code using Docker

The provided Docker-file contains all the steps to compile, package and create the image, so project can be
build and run without having gleam / erlang installed, with standard docker commands.

In the folder that contains Dockerfile, build the docker image by writing:

``docker build -t quiz/quizterm .``

and run it by writing:

``docker run -p 1234:1234 quiz/quizterm``

The server should then be reachable on http://localhost:1234
