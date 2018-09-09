#Cleanup
rm raw_out compare changes updates dl_links 2> /dev/null

#Check if db exist
if [ -e manga_db ]
then
    mv manga_db manga_db_old
else
    echo "DB not found!"
fi

#Fetch
echo Fetching updates:
cat mangas | while read url; do
	name=$(echo $url | cut -d / -f5)
	info=`curl -s $url | tr '<' '\n' | grep "chapter-link" | head -1 | cut -d '"' -f4`
	latest=$(echo $info | cut -d / -f4)
	dl=http://gmanga.me$info
	echo $name"="$latest $dl >> raw_out
done
cat raw_out | sort | cut -d ' ' -f1 > manga_db

#Compare
echo Comparing:
cat manga_db | while read manga; do
	name=$(echo $manga | cut -d '=' -f1 | head -1)
	new=`cat manga_db | grep $name`
	old=`cat manga_db_old | grep $name`
	diff <(echo "$old") <(echo "$new") | grep ^"<\|>" >> compare
done
awk '!seen[$0]++' compare > changes

#Info
if [ -s changes ]
then
	echo "Here's the new chapters!"
	cat changes | grep ">" | cut -d ">" -f2 | tee updates
else
    echo "No changes found!"
fi

#Downloads
if [ -s updates ]
then
    echo "Download Links!"
	for manga in `cat updates | cut -d ' ' -f2`; do cat raw_out | grep $manga ; done 2>&1 | tee dl_links
else
    echo "No new chapters!"
fi

#Telegram
cat dl_links | while read line; do
	manga=$(echo $line | cut -d = -f1)
	chapter=$(echo $line | cut -d = -f2 | cut -d ' ' -f1)
	link=$(echo $line | cut -d = -f2 | cut -d ' ' -f2)
	./telegram -t $BOTTOKEN -c @NineAnimeTracker -M "New chapter available!
	*Manga*: $manga
	*Chapter*: $chapter
	*Read*: [Here]($link)"
done

#Push
git config --global user.email "builds@travis-ci.com" && git config --global user.name "Travis CI"
git add manga_db; git commit -m "Sync: $(date +%d.%m.%Y-%R)"
git push -q https://$GIT_OAUTH_TOKEN@github.com/ninetrackers/manga.git HEAD:gmanga
