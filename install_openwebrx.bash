#!/bin/bash

set -e

SCRIPT_PATH=`realpath "$0"`
SCRIPT_DIR=`dirname "$SCRIPT_PATH"`
BUILD_DIR="$SCRIPT_DIR/build"

export MAKEOPTS="-j `nproc --all`"

function install_prerequisites()
{
	sudo apt-get -y install git build-essential cmake python3 python3-setuptools 
	sudo apt-get -y install rtl-sdr netcat libsndfile-dev librtlsdr-dev automake autoconf libtool pkg-config fftw3-dev
}

function install_cdr() 
{
	echo "Install csdr"

	cd "$BUILD_DIR"

	[[ ! -d csdr ]] && git clone --depth=1 -b master https://github.com/jketterl/csdr.git
	cd csdr
	autoreconf -i
	./configure
	make $MAKEOPTS
	sudo make install
	cd ..
	sudo ldconfig
}

function install_js8py()
{
	echo "Install js8py library from source"
	cd "$BUILD_DIR"
	[[ ! -d js8py ]] && git clone --depth=1 -b master https://github.com/jketterl/js8py.git
	cd js8py
	sudo python3 setup.py install
	cd ..
}

function install_owrx_connector()
{
	echo "Install owrx_connector from source"

	cd "$BUILD_DIR"

	[[  ! -d owrx_connector ]] && git clone --depth=1 -b master https://github.com/jketterl/owrx_connector.git

	cd owrx_connector
	mkdir -p build
	cd build
	cmake -DCMAKE_BUILD_TYPE=release ..
	make $MAKEOPTS
	sudo make install
	cd ../..
	sudo ldconfig
}

function install_digital_voice()
{
	echo "Install codecserver (for digital voice)"

	sudo apt-get -y install sox libprotobuf-dev protobuf-compiler

	cd "$BUILD_DIR"
	[[ ! -d codecserver ]] && git clone --depth=1 -b master https://github.com/jketterl/codecserver.git
	cd codecserver
	mkdir -p build
	cd build
	cmake -DCMAKE_BUILD_TYPE=release ..
	make $MAKEOPTS
	sudo make install
	cd ../..
	sudo ldconfig
}

function setup_codecserver_users()
{
	echo "Create codecserver user and set permissions for serial devices"
	sudo bash -c "id -u codecserver >/dev/null 2>&1 || adduser --system --group --no-create-home --home /nonexistent --quiet codecserver"
	sudo bash -c "id -u codecserver >/dev/null 2>&1 || usermod -aG dialout codecserver"
}


function install_digiham()
{
	echo "Install digiham from source"
	cd "$BUILD_DIR"
	[[ ! -d digiham ]] && git clone --depth=1 -b master https://github.com/jketterl/digiham.git
	cd digiham
	mkdir -p build
	cd build
	cmake -DCMAKE_BUILD_TYPE=release ..
	make $MAKEOPTS
	sudo make install
	cd ../..
}

function install_codec2()
{
	echo "Install codec2 from source"

	cd "$BUILD_DIR"

	[[ ! -d codec2 ]] &&  git clone --depth=1 https://github.com/drowe67/codec2.git

	cd codec2
	mkdir -p build
	cd build
	cmake -DCMAKE_BUILD_TYPE=release ..
	make $MAKEOPTS
	sudo make install
	# manually install freedv_rx since it's not part of the default install package
	sudo install -m 0755 src/freedv_rx /usr/local/bin
	cd ../..
	sudo ldconfig
}

function install_m17_cxx_daemod()
{
	echo "m17-cxx-demod"
	sudo apt-get -y install libboost-program-options-dev
	cd "$BUILD_DIR"
	[[ ! -d m17-cxx-demod ]] && git clone --depth=1 https://github.com/mobilinkd/m17-cxx-demod.git
	cd m17-cxx-demod
	mkdir -p build
	cd build
	cmake -DCMAKE_BUILD_TYPE=release ..
	make $MAKEOPTS
	sudo make install
	cd ../..
}


function install_drm()
{
	echo "Install optional dependencies for DRM"

	sudo apt-get -y install qt5-default libpulse0 libfaad2 libopus0 libpulse-dev libfaad-dev libopus-dev libfftw3-dev wget

	cd "$BUILD_DIR"
	[[ ! -f $BUILD_DIR/dream-2.1.1-svn808.tar.gz ]] && wget https://downloads.sourceforge.net/project/drm/dream/2.1.1/dream-2.1.1-svn808.tar.gz

	[[ ! -d "$BUILD_DIR/dream" ]] && tar xvfz dream-2.1.1-svn808.tar.gz
	cd dream
	qmake CONFIG+=console
	make $MAKEOPTS
	sudo make install
	cd ..
}

function install_direwolf()
{
	echo "Install optional packages for Packet / APRS"
	sudo apt-get -y install direwolf
}

function install_sox()
{
	echo "Install sox"
	sudo apt-get -y install sox
}


function setup_openwebrx()
{
	echo "Prepare data storage"
	sudo mkdir -p /var/lib/openwebrx

	echo "Craete openwebrx user"
	sudo bash -c "id -u openwebrx || useradd -m openwebrx -G plugdev -m"

	echo "Change /var/lib/openwebrx owner to openwebrx:openwebrx"
	sudo chown openwebrx:openwebrx /var/lib/openwebrx

	echo "Create empty users.json"
	sudo bash -c "echo [] > /var/lib/openwebrx/users.json"

	echo "Change owner/group for users.json to openwebrx:openwebrx"
	sudo chown openwebrx:openwebrx /var/lib/openwebrx/users.json

	echo "users.json 0600"
	sudo chmod 0600 /var/lib/openwebrx/users.json
}


function install_openwebrx()
{
	echo "Clone openwebrx"
	cd "$BUILD_DIR"

	[[ ! -d openwebrx ]] && git clone --depth=1 -b master https://github.com/jketterl/openwebrx.git
}

function post_setup_openwebrx()
{
	echo "Create admin user for  openwebrx"
	cd openwebrx
	sudo ./openwebrx.py admin adduser admin
	#./openwebrx.py

	echo "Create openwebrx service file"
	sudo bash -c "echo '[Unit]
Description=OpenWebRX WebSDR receiver

[Service]
Type=simple
User=openwebrx
Group=openwebrx
ExecStart=$BUILD_DIR/openwebrx/openwebrx.py
Restart=always

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/openwebrx.service"

	sudo systemctl daemon-reload
}

# ------------------------------------------------------------------------
install_prerequisites
install_cdr
install_js8py
install_owrx_connector
install_digital_voice
setup_codecserver_users
install_digiham
install_codec2
install_m17_cxx_daemod
install_drm
install_direwolf
install_sox
setup_openwebrx
install_openwebrx
post_setup_openwebrx

