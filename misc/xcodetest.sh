#!/usr/bin/env sh
set -ex
export NSUnbufferedIO=YES

TDIR=`mktemp -d`
trap "{ cd - ; rm -rf $TDIR; exit 255; }" SIGINT

cd $TDIR
git clone https://github.com/kishikawakatsumi/SwiftPowerAssert.git tool
(cd tool && swift build -c release)
(cd tool/Fixtures/Atlas && swift package generate-xcodeproj)
(cd tool/Fixtures/Atlas && ../../.build/release/swift-power-assert xctest -Xxcodebuild test -scheme Atlas-Package)
(cd tool/Fixtures/Atlas && ../../.build/release/swift-power-assert xctest -Xxcodebuild test -scheme Atlas-Package -enableCodeCoverage YES)
(cd tool/Fixtures/Atlas && ../../.build/release/swift-power-assert --verbose xctest -Xxcodebuild test -scheme Atlas-Package)
(cd tool/Fixtures/Atlas && ../../.build/release/swift-power-assert --verbose xctest -Xxcodebuild test -scheme Atlas-Package -enableCodeCoverage YES)
cd -

rm -rf $TDIR
