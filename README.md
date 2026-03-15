### Welcome to QUIZTerm

QUIZTerm is a simple online "quiz answering" game. It provides a way for contestants to provide answers to questions,
and reveal the answers for everyone at the same time.

Cards showing who are playing, their answer status (have they answered or not?), and when revealed, what their answer
was, will show up on everyones screen.

Not quite finished yet, it is at a point where it is "usable" enough.

There are two endpoints to use:
| / |endpoint for "regular" players.
| /control | endpoint for person controlling the quiz. Same interface as for regular players, but with possiblity to control when to reveal answers and when to move on to next question. This gives the possiblity for the person asking the question to also provide answers, but the controls will work even if there is no player joined from this page.

![Screenshot of the game](game1.png)

### Building and running

Docker, or a compatible container manager, like podman, is required to build and run
quizterm. 

To compile project and build docker image, write:
```
docker build . -t quizterm:1
```
quizterm can be whatever name you want to give the container, 1 can be 
changed to whatever you want the version of the container to be.

Start server on port 4321:
```
docker run -p 4321:1234 quizterm:1
```

Port 1234 is the port used internally in the docker container, while 4321
is the port exposed outside the container. The latter can be set to whatever
port you want to use.

Open web browser and access http://localhost:4321
