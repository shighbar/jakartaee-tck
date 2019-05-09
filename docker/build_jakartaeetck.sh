#!/bin/bash -xe

# Copyright (c) 2018 Oracle and/or its affiliates. All rights reserved.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License v. 2.0, which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# This Source Code may also be made available under the following Secondary
# Licenses when the conditions for such availability set forth in the
# Eclipse Public License v. 2.0 are satisfied: GNU General Public License,
# version 2 with the GNU Classpath Exception, which is available at
# https://www.gnu.org/software/classpath/license.html.
#
# SPDX-License-Identifier: EPL-2.0 OR GPL-2.0 WITH Classpath-exception-2.0

if [ -z "$ANT_HOME" ]; then
  export ANT_HOME=/usr/share/ant/
fi

if [ -z "$JAVA_HOME" ]; then
  export JAVA_HOME=/opt/jdk1.8.0_171
fi

export PATH=$JAVA_HOME/bin:$ANT_HOME/bin:$PATH

cd $WORKSPACE
export BASEDIR=`pwd`

if [ -z "$GF_HOME" ]; then
  export GF_HOME=$BASEDIR
fi

if [ ! -z "$TCK_BUNDLE_BASE_URL" ]; then
   echo "Skipping build and using pre-build binary javaeetck bundle: $TCK_BUNDLE_BASE_URL/javaeetck.zip"
   mkdir -p ${WORKSPACE}/jakartaeetck-bundles
   wget  --progress=bar:force --no-cache ${TCK_BUNDLE_BASE_URL}/javaeetck.zip -O ${WORKSPACE}/jakartaeetck-bundles/javaeetck.zip
   if [ ! -z "$GF_VERSION_URL" ]; then
       wget --progress=bar:force --no-cache $GF_VERSION_URL -O glassfish.version
       cat glassfish.version
   fi
   exit 0
fi

which ant
ant -version

which java
java -version

export ANT_OPTS="-Xmx2G -Djava.endorsed.dirs=${GF_HOME}/glassfish5/glassfish/modules/endorsed \
                 -Djavax.xml.accessExternalStylesheet=all \
                 -Djavax.xml.accessExternalSchema=all \
                 -Djavax.xml.accessExternalDTD=file,http"

echo ########## Remove hard-coded paths from install/j2ee/bin/ts.jte ##########"
sed -e "s#^javaee.home=.*#javaee.home=$GF_HOME/glassfish5/glassfish#g" \
    -e "s#^javaee.home.ri=.*#javaee.home.ri=$GF_HOME/glassfish5/glassfish#g" \
    -e "s#^report.dir=.*#report.dir=$BASEDIR/JTReport#g" \
    -e "s#^work.dir=.*#work.dir=$BASEDIR/JTWork#g" $BASEDIR/install/j2ee/bin/ts.jte > $BASEDIR/install/j2ee/bin/ts.jte.new
mv $BASEDIR/install/j2ee/bin/ts.jte.new $BASEDIR/install/j2ee/bin/ts.jte
echo "Contents of modified TS.JTE file"
cat $BASEDIR/install/j2ee/bin/ts.jte

echo "########## Trunk.Install.V5 Config ##########"
cd $BASEDIR
if [ -z "$GF_BUNDLE_URL" ]; then
  echo "Using default url for GF bundle: $DEFAULT_GF_BUNDLE_URL"
  export GF_BUNDLE_URL=$DEFAULT_GF_BUNDLE_URL
fi
wget --progress=bar:force --no-cache $GF_BUNDLE_URL -O latest-glassfish.zip
unzip -o latest-glassfish.zip
ls -l $GF_HOME/glassfish5/glassfish/

if [ ! -z "$GF_VERSION_URL" ]; then
  wget --progress=bar:force --no-cache $GF_VERSION_URL -O glassfish.version
  cat glassfish.version
fi

echo "########## Trunk.Clean.Build.Libs ##########"
ant -f $BASEDIR/install/j2ee/bin/build.xml -Ddeliverabledir=j2ee -Dbasedir=$BASEDIR/install/j2ee/bin clean.all build.all.jars

echo "########## Trunk.Build ##########"
# Builds the CTS Deliverable
ant -f $BASEDIR/install/j2ee/bin/build.xml -Ddeliverabledir=j2ee -Dbasedir=$BASEDIR/install/j2ee/bin  modify.jstl.db.resources

# Full workspace build.
ant -f $BASEDIR/install/j2ee/bin/build.xml -Ddeliverabledir=j2ee -Dbasedir=$BASEDIR/install/j2ee/bin -Djava.endorsed.dirs=$GF_HOME/glassfish5/glassfish/modules/endorsed build.all


echo "########## Trunk.Sanitize.JTE ##########"
# Sanitize the ts.jte file based on the values in release/tools/jte.props.sanitize
ant -f $BASEDIR/release/tools/build-utils.xml -Ddeliverabledir=j2ee -Dbasedir=$BASEDIR/release/tools -Dts.jte.prop.file=$BASEDIR/release/tools/jte.props.sanitize


echo "########## Trunk.Clean.Builds ##########"
# Cleans all bundles under TS_HOME/release except tools.
ant -f $BASEDIR/release/tools/build-utils.xml -Ddeliverabledir=j2ee -Dbasedir=$BASEDIR/release/tools remove.bundles


echo "########## Trunk.CTS ##########"
mkdir -p $BASEDIR/internal/docs/javaee/
cp $BASEDIR/internal/docs/dtd/*.dtd $BASEDIR/internal/docs/javaee/
ant -f $BASEDIR/release/tools/build.xml -Ddeliverabledir=j2ee -Ddeliverable.version=8.0 -Dskip.createbom="true" -Dskip.build="true" -Dbasedir=$BASEDIR/release/tools j2ee

ant -f $BASEDIR/release/tools/build.xml -Ddeliverabledir=j2ee -Ddeliverable.version=8.0 -Dskip.createbom="true" -Dskip.build="true" -Dbasedir=$BASEDIR/release/tools smoke

mkdir -p ${WORKSPACE}/jakartaeetck-bundles
cd ${WORKSPACE}/jakartaeetck-bundles
cp ${WORKSPACE}/release/JAVAEE_BUILD/latest/javaeetck*.zip ${WORKSPACE}/jakartaeetck-bundles/javaeetck.zip
cp ${WORKSPACE}/release/JAVAEE-SMOKE_BUILD/latest/javaee-smoke*.zip ${WORKSPACE}/jakartaeetck-bundles/javaee-smoke.zip


#Generate Version file
GIT_HASH=`git rev-parse HEAD`
GIT_BRANCH=`git branch | awk '{print $2}'`
BUILD_DATE=`date`
rm -f ${WORKSPACE}/javaeetck.version
touch ${WORKSPACE}/javaeetck.version
echo "Git Revision: ${GIT_HASH}" >> ${WORKSPACE}/javaeetck.version
echo "Git Branch: ${GIT_BRANCH}" >> ${WORKSPACE}/javaeetck.version
echo "Build Date: ${BUILD_DATE}" >> ${WORKSPACE}/javaeetck.version
