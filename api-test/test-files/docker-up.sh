docker build . -t quizterm:1
docker run --name do_integration_test -d -p 4321:1234 quizterm:1

sleep 2
