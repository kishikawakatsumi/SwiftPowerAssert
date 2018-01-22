#!/usr/bin/env sh
set -ex
export NSUnbufferedIO=YES

TDIR=`mktemp -d`
trap "{ cd - ; rm -rf $TDIR; exit 255; }" SIGINT

cd $TDIR
git clone https://github.com/kishikawakatsumi/SwiftPowerAssert.git tool
(cd tool && swift build -c release)
(cd tool/Fixtures/Atlas && ../../.build/release/swift-power-assert test)
(cd tool/Fixtures/Atlas && ../../.build/release/swift-power-assert test -Xswift test)
(cd tool/Fixtures/Atlas && ../../.build/release/swift-power-assert test -Xswift test -c release -Xswiftc -enable-testing)
(cd tool/Fixtures/Atlas && ../../.build/release/swift-power-assert --verbose test)
(cd tool/Fixtures/Atlas && ../../.build/release/swift-power-assert --verbose test -Xswift test)
(cd tool/Fixtures/Atlas && ../../.build/release/swift-power-assert --verbose test -Xswift test -c release -Xswiftc -enable-testing)
cd -

rm -rf $TDIR
