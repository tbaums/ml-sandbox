git_commit=$(git log -1 --pretty=%h)
timestamp=$(date +%Y%m%d%H%M)  
tag=$git_commit-$timestamp
image=tbaums/medical-image-tutorial:$tag
# Comment out `pbcopy` below if not on MacOS.
echo $image | pbcopy
docker build . -t $image
docker push $image
docker system prune -f