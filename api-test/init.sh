#!/bin/sh
export API_KEY="X-api-key: test"
export URL=http://localhost:1234
echo $URL

echo "Rooms!"
for i in A B C D E F G
do
	echo "{ \"id\": \"TM$i\", \"name\": \"Team $i\", \"pin_enc\": \"`echo "PIN$i" | sha256 -x`\" }" \
	| curl --header "$API_KEY" --json @- $URL/api/room
done 
echo
echo "questions!"

echo "[" > ship.json
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13
do
  echo "{ \"index\": $i, \"text\": \"What question number is this? Hint (one more than previous question!)?\" }," >> ship.json
done
echo "{ \"index\": 14, \"text\": \"What question number is this? Hint (one more than previous question!)?\" }" >> ship.json
echo "]" >> ship.json
curl --header "$API_KEY" --json @- $URL/api/questions < ship.json
rm ship.json
echo 
echo "answers!"
echo "[" > ship.json
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13
do
  echo "{ \"index\": $i, \"text\": \"The answer to the question is, of course, $i! Keep counting!\" }," >> ship.json
done
echo "{ \"index\": 14, \"text\": \"The answer to the question is, of course, 14! Keep counting!\"} " >> ship.json
echo "]" >> ship.json
curl --header "$API_KEY" --json @- $URL/api/answers < ship.json
rm ship.json
