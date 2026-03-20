docker build . -t quizterm:1
docker run --name do_integration_test -d -p 4321:1234 quizterm:1

sleep 2

echo '{ "answers": [ {"question" : 1, "answer": "cat"}, {"question" : 2, "answer": "dog"} ] }' | curl --json @- http://localhost:4321/api/answers


echo ""
echo ""

docker stop do_integration_test
docker rm do_integration_test
