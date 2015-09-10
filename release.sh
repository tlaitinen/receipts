#!/bin/bash
DATE=`date +%Y-%m-%d`
BASE=receipts-bin

cd frontend
sencha app build production
cd ..
pushd ~/$BASE
git branch $DATE
git checkout $DATE
popd

mkdir -p ~/$BASE/backend ~/$BASE/frontend
cp ~/.local/bin/backend ~/$BASE/backend
cp ~/.local/bin/minuterun ~/$BASE/backend
cp -r frontend/build/production/Receipts/* ~/$BASE/frontend
pushd ~/$BASE
git add *
git commit -m "$BASE version $DATE"
git push origin $DATE
git checkout master
popd
